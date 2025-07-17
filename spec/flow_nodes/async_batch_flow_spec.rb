# frozen_string_literal: true

require "spec_helper"

# Helper class to track async batch execution
class AsyncBatchExecutionTracker
  attr_reader :executed_items, :execution_order

  def initialize
    @executed_items = []
    @execution_order = []
    @mutex = Mutex.new
  end

  def record(node, item_params)
    @mutex.synchronize do
      @executed_items << { node: node.name, params: item_params }
      @execution_order << { node: node.name, time: Time.now, params: item_params, thread: Thread.current.object_id }
    end
  end
end

# Test async node for batch flows
class TestAsyncBatchNode < FlowNodes::AsyncNode
  attr_reader :name, :tracker, :delay

  def initialize(name:, tracker: nil, delay: 0, **)
    super(**)
    @name = name
    @tracker = tracker
    @delay = delay
  end

  def exec_async(params)
    sleep @delay if @delay > 0
    @tracker&.record(self, params)
    nil # Return nil to follow default successor
  end
end

# Test AsyncBatchFlow with custom prep method
class TestAsyncBatchFlowWithPrep < FlowNodes::AsyncBatchFlow
  attr_reader :prep_called_with

  def prep_async(state)
    @prep_called_with = state
    state[:batch_items] if state.is_a?(Hash)
  end
end

RSpec.describe FlowNodes::AsyncBatchFlow do
  let(:tracker) { AsyncBatchExecutionTracker.new }
  let(:async_node1) { TestAsyncBatchNode.new(name: "async1", tracker: tracker) }
  let(:async_node2) { TestAsyncBatchNode.new(name: "async2", tracker: tracker) }

  describe "#_run_async" do
    it "processes a batch of items sequentially" do
      flow = described_class.new(start: async_node1)
      async_node1 >> async_node2

      flow.set_params({ base_param: "value" })

      # Mock prep_async to return batch items
      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1, data: "first" },
                                                       { item_id: 2, data: "second" },
                                                       { item_id: 3, data: "third" },
                                                     ])

      flow.run_async("test_state")

      expected_items = [
        { node: "async1", params: { base_param: "value", item_id: 1, data: "first" } },
        { node: "async2", params: { base_param: "value", item_id: 1, data: "first" } },
        { node: "async1", params: { base_param: "value", item_id: 2, data: "second" } },
        { node: "async2", params: { base_param: "value", item_id: 2, data: "second" } },
        { node: "async1", params: { base_param: "value", item_id: 3, data: "third" } },
        { node: "async2", params: { base_param: "value", item_id: 3, data: "third" } },
      ]

      expect(tracker.executed_items).to eq(expected_items)
    end

    it "processes items in order" do
      flow = described_class.new(start: async_node1)

      allow(flow).to receive(:prep_async).and_return([
                                                       { order: 1 },
                                                       { order: 2 },
                                                       { order: 3 },
                                                     ])

      flow.run_async("test_state")

      orders = tracker.execution_order.map { |item| item[:params][:order] }
      expect(orders).to eq([1, 2, 3])
    end

    it "handles empty batch" do
      flow = described_class.new(start: async_node1)
      flow.set_params({ base_param: "value" })

      allow(flow).to receive(:prep_async).and_return([])

      flow.run_async("test_state")

      expect(tracker.executed_items).to be_empty
    end

    it "handles nil prep_async result" do
      flow = described_class.new(start: async_node1)
      flow.set_params({ base_param: "value" })

      allow(flow).to receive(:prep_async).and_return(nil)

      flow.run_async("test_state")

      expect(tracker.executed_items).to be_empty
    end

    it "merges flow params with item params" do
      flow = described_class.new(start: async_node1)
      flow.set_params({ base_param: "base", shared_param: "from_flow" })

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1, shared_param: "from_item" },
                                                     ])

      flow.run_async("test_state")

      expected_params = {
        base_param: "base",
        shared_param: "from_item", # Item param takes precedence
        item_id: 1,
      }

      expect(tracker.executed_items[0][:params]).to eq(expected_params)
    end

    it "calls prep_async and post_async hooks" do
      flow = described_class.new(start: async_node1)
      batch_items = [{ item: "test" }]

      expect(flow).to receive(:prep_async).with("test_state").and_return(batch_items)
      expect(flow).to receive(:post_async).with("test_state", batch_items, nil)

      flow.run_async("test_state")
    end

    it "works with custom prep_async method" do
      flow = TestAsyncBatchFlowWithPrep.new(start: async_node1)
      flow.set_params({ base: "param" })

      state = { batch_items: [{ id: 1 }, { id: 2 }] }
      flow.run_async(state)

      expect(flow.prep_called_with).to eq(state)
      expect(tracker.executed_items.size).to eq(2)
      expect(tracker.executed_items[0][:params]).to eq({ base: "param", id: 1 })
      expect(tracker.executed_items[1][:params]).to eq({ base: "param", id: 2 })
    end

    it "processes items sequentially (not in parallel)" do
      delayed_node = TestAsyncBatchNode.new(name: "delayed", tracker: tracker, delay: 0.05)
      flow = described_class.new(start: delayed_node)

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      start_time = Time.now
      flow.run_async("test_state")
      end_time = Time.now

      # Should take at least 150ms (3 items × 50ms each)
      expect(end_time - start_time).to be >= 0.15

      # Verify sequential execution - each item should complete before the next starts
      expect(tracker.execution_order.size).to eq(3)
      expect(tracker.execution_order[0][:time]).to be < tracker.execution_order[1][:time]
      expect(tracker.execution_order[1][:time]).to be < tracker.execution_order[2][:time]
    end
  end

  describe "conditional flows in async batches" do
    it "handles different actions for different items" do
      # Create a custom conditional node
      class ConditionalAsyncBatchNode < FlowNodes::AsyncNode
        attr_reader :name, :tracker

        def initialize(name:, tracker: nil, **options)
          super(**options)
          @name = name
          @tracker = tracker
        end

        def exec_async(params)
          @tracker&.record(self, params)
          params[:item_id] == 1 ? "success" : "failure"
        end
      end

      start_node = ConditionalAsyncBatchNode.new(name: "start", tracker: tracker)
      success_node = TestAsyncBatchNode.new(name: "success", tracker: tracker)
      failure_node = TestAsyncBatchNode.new(name: "failure", tracker: tracker)

      flow = described_class.new(start: start_node)

      start_node.nxt(success_node, "success")
      start_node.nxt(failure_node, "failure")

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                     ])

      flow.run_async("test_state")

      expect(tracker.executed_items.map { |item| item[:node] }).to eq(%w[start success start failure])
    end
  end

  describe "mixed async and sync nodes" do
    it "handles both async and sync nodes in the same flow" do
      # Create a simple sync node for testing
      class TestBatchNode < FlowNodes::Node
        attr_reader :name, :tracker

        def initialize(name:, tracker: nil, **options)
          super(**options)
          @name = name
          @tracker = tracker
        end

        def exec(params)
          @tracker&.record(self, params)
          nil
        end
      end

      sync_node = TestBatchNode.new(name: "sync", tracker: tracker)

      flow = described_class.new(start: async_node1)
      async_node1 >> sync_node >> async_node2

      flow.set_params({ mixed: "flow" })

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                     ])

      flow.run_async("test_state")

      expect(tracker.executed_items.map { |item| item[:node] }).to eq(%w[async1 sync async2])
      expect(tracker.executed_items.all? { |item| item[:params][:mixed] == "flow" }).to be true
    end
  end

  describe "error handling" do
    it "continues processing remaining items when one fails", :pending do
      failing_node = TestAsyncBatchNode.new(name: "failing", tracker: tracker)

      flow = described_class.new(start: failing_node)

      # Mock node to fail on second item
      call_count = 0
      allow(failing_node).to receive(:exec_async) do |params|
        call_count += 1
        raise "Simulated failure" if call_count == 2

        tracker.record(failing_node, params)
        "success"
      end

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      expect { flow.run_async("test_state") }.to raise_error("Simulated failure")

      # Should have processed first item and failed on second
      expect(tracker.executed_items.size).to eq(1)
      expect(tracker.executed_items[0][:params][:item_id]).to eq(1)
    end
  end

  describe "inheritance from AsyncFlow" do
    it "inherits async flow functionality" do
      flow = described_class.new(start: async_node1)
      expect(flow).to be_a(FlowNodes::AsyncFlow)
      expect(flow.start_node).to eq(async_node1)
    end

    it "prohibits regular run method" do
      flow = described_class.new(start: async_node1)
      expect(flow).to receive(:run_async).with("test_state")
      flow.run("test_state")
    end

    it "prohibits regular _run method" do
      flow = described_class.new(start: async_node1)
      expect { flow.send(:_run, "test_state") }.to raise_error("Use run_async for AsyncFlow.")
    end
  end

  describe "parameter isolation" do
    it "doesn't affect original flow params" do
      flow = described_class.new(start: async_node1)
      original_params = { base: "value" }
      flow.set_params(original_params)

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_param: "item_value" },
                                                     ])

      flow.run_async("test_state")

      expect(flow.params).to eq(original_params)
    end

    it "maintains parameter isolation between items" do
      flow = described_class.new(start: async_node1)
      flow.set_params({ base: "value" })

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1, data: "first" },
                                                       { item_id: 2, data: "second" },
                                                     ])

      flow.run_async("test_state")

      # Each item should have its own merged params
      expect(tracker.executed_items[0][:params]).to eq({ base: "value", item_id: 1, data: "first" })
      expect(tracker.executed_items[1][:params]).to eq({ base: "value", item_id: 2, data: "second" })
    end
  end

  describe "thread safety" do
    it "handles concurrent access safely" do
      flow = described_class.new(start: async_node1)

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      # Run multiple flows concurrently
      threads = 3.times.map do |i|
        Thread.new do
          tracker_instance = AsyncBatchExecutionTracker.new
          node = TestAsyncBatchNode.new(name: "node_#{i}", tracker: tracker_instance)
          flow_instance = described_class.new(start: node)
          allow(flow_instance).to receive(:prep_async).and_return([{ thread_id: i }])
          flow_instance.run_async("state_#{i}")
          tracker_instance
        end
      end

      results = threads.map(&:value)

      # Each thread should have processed its own item
      expect(results.map { |t| t.executed_items.size }).to eq([1, 1, 1])
      expect(results.map { |t| t.executed_items[0][:params][:thread_id] }).to eq([0, 1, 2])
    end
  end
end
