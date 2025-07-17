# frozen_string_literal: true

require "spec_helper"

# Helper class to track async execution
class AsyncExecutionTracker
  attr_reader :executed_nodes, :execution_order

  def initialize
    @executed_nodes = []
    @execution_order = []
    @mutex = Mutex.new
  end

  def record(node)
    @mutex.synchronize do
      @executed_nodes << node.dup
      @execution_order << { node: node.name, time: Time.now, thread: Thread.current.object_id }
    end
  end
end

# Test async node class
class TestAsyncNode < FlowNodes::AsyncNode
  attr_reader :name, :delay, :executed_params

  def initialize(name:, delay: 0, action_to_return: nil, tracker: nil, **options)
    super(**options)
    @name = name
    @delay = delay
    @action_to_return = action_to_return
    @tracker = tracker
    @executed_params = nil
  end

  def exec_async(p)
    @executed_params = p
    sleep @delay if @delay > 0
    @tracker&.record(self)
    @action_to_return
  end
end

# Test sync node for mixed flows
class TestSyncNode < FlowNodes::Node
  attr_reader :name, :executed_params

  def initialize(name:, action_to_return: nil, tracker: nil, **options)
    super(**options)
    @name = name
    @action_to_return = action_to_return
    @tracker = tracker
    @executed_params = nil
  end

  def exec(p)
    @executed_params = p
    @tracker&.record(self)
    @action_to_return
  end
end

RSpec.describe FlowNodes::AsyncFlow do
  let(:tracker) { AsyncExecutionTracker.new }
  let(:async_node1) { TestAsyncNode.new(name: "async1", tracker: tracker) }
  let(:async_node2) { TestAsyncNode.new(name: "async2", tracker: tracker) }
  let(:sync_node) { TestSyncNode.new(name: "sync", tracker: tracker) }

  describe "#run" do
    it "delegates to run_async" do
      flow = described_class.new(start: async_node1)
      expect(flow).to receive(:run_async).with("test_state")
      flow.run("test_state")
    end
  end

  describe "#run_async" do
    it "runs a simple async flow" do
      flow = described_class.new(start: async_node1)
      async_node1 >> async_node2
      
      flow.set_params({ user_id: 123 })
      result = flow.run_async(nil)
      
      expect(tracker.executed_nodes.map(&:name)).to eq(%w[async1 async2])
      expect(tracker.executed_nodes[0].params).to eq({ user_id: 123 })
      expect(tracker.executed_nodes[1].params).to eq({ user_id: 123 })
      expect(result).to be_nil
    end

    it "handles mixed async and sync nodes" do
      flow = described_class.new(start: async_node1)
      async_node1 >> sync_node >> async_node2
      
      flow.set_params({ action: "mixed" })
      flow.run_async(nil)
      
      expect(tracker.executed_nodes.map(&:name)).to eq(%w[async1 sync async2])
      expect(tracker.executed_nodes[0].params).to eq({ action: "mixed" })
      expect(tracker.executed_nodes[1].params).to eq({ action: "mixed" })
      expect(tracker.executed_nodes[2].params).to eq({ action: "mixed" })
    end

    it "follows conditional paths with async nodes" do
      start_node = TestAsyncNode.new(name: "start", action_to_return: "success", tracker: tracker)
      success_node = TestAsyncNode.new(name: "success", tracker: tracker)
      failure_node = TestAsyncNode.new(name: "failure", tracker: tracker)
      
      flow = described_class.new(start: start_node)
      start_node.nxt(success_node, "success")
      start_node.nxt(failure_node, "failure")
      
      flow.set_params({ task: "conditional" })
      flow.run_async(nil)
      
      expect(tracker.executed_nodes.map(&:name)).to eq(%w[start success])
      expect(tracker.executed_nodes[0].params).to eq({ task: "conditional" })
      expect(tracker.executed_nodes[1].params).to eq({ task: "conditional" })
    end

    it "processes nodes sequentially" do
      delayed_node1 = TestAsyncNode.new(name: "delayed1", delay: 0.05, tracker: tracker)
      delayed_node2 = TestAsyncNode.new(name: "delayed2", delay: 0.05, tracker: tracker)
      
      flow = described_class.new(start: delayed_node1)
      delayed_node1 >> delayed_node2
      
      start_time = Time.now
      flow.run_async(nil)
      end_time = Time.now
      
      expect(tracker.executed_nodes.map(&:name)).to eq(%w[delayed1 delayed2])
      expect(end_time - start_time).to be >= 0.1 # At least 100ms for both delays
      
      # Verify sequential execution
      expect(tracker.execution_order[0][:time]).to be < tracker.execution_order[1][:time]
    end
  end

  describe "#_run" do
    it "raises an error when called directly" do
      flow = described_class.new(start: async_node1)
      expect { flow.send(:_run, nil) }.to raise_error("Use run_async for AsyncFlow.")
    end
  end

  describe "async lifecycle hooks" do
    it "calls prep_async and post_async hooks" do
      flow = described_class.new(start: async_node1)
      
      expect(flow).to receive(:prep_async).with("test_state").and_return({ prepared: true })
      expect(flow).to receive(:post_async).with("test_state", { prepared: true }, nil)
      
      flow.run_async("test_state")
    end

    it "uses prep_async result as flow params when available" do
      flow = described_class.new(start: async_node1)
      
      allow(flow).to receive(:prep_async).and_return({ from_prep: "value" })
      flow.run_async("test_state")
      
      expect(tracker.executed_nodes[0].params).to eq({ from_prep: "value" })
    end

    it "falls back to @params when prep_async returns nil" do
      flow = described_class.new(start: async_node1)
      flow.set_params({ from_set_params: "value" })
      
      allow(flow).to receive(:prep_async).and_return(nil)
      flow.run_async("test_state")
      
      expect(tracker.executed_nodes[0].params).to eq({ from_set_params: "value" })
    end
  end

  describe "error handling" do
    it "raises error when no start node is defined" do
      flow = described_class.new
      expect { flow.run_async(nil) }.to raise_error("Flow has no start node")
    end

    it "terminates gracefully when no successor is found" do
      start_node = TestAsyncNode.new(name: "start", action_to_return: "undefined", tracker: tracker)
      flow = described_class.new(start: start_node)
      start_node.nxt(TestAsyncNode.new(name: "defined", tracker: tracker), "defined")
      
      expect { flow.run_async(nil) }.to output(/Flow ends: action 'undefined' not found/).to_stderr
      expect(tracker.executed_nodes.map(&:name)).to eq(%w[start])
    end
  end

  describe "parameter passing" do
    it "maintains parameter isolation between flow runs" do
      flow1 = described_class.new(start: async_node1)
      flow2 = described_class.new(start: async_node2)
      
      flow1.set_params({ flow: "1" })
      flow2.set_params({ flow: "2" })
      
      flow1.run_async(nil)
      flow2.run_async(nil)
      
      expect(async_node1.params).to be_empty  # Original nodes should be pristine
      expect(async_node2.params).to be_empty
    end
  end
end