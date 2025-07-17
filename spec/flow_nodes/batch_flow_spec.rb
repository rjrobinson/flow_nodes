# frozen_string_literal: true

require "spec_helper"

# Helper class to track batch execution
class BatchExecutionTracker
  attr_reader :executed_items, :execution_order

  def initialize
    @executed_items = []
    @execution_order = []
  end

  def record(node, item_params)
    @executed_items << { node: node.name, params: item_params }
    @execution_order << { node: node.name, time: Time.now, params: item_params }
  end
end

# Test node for batch flows
class TestBatchNode < FlowNodes::Node
  attr_reader :name, :tracker, :action_to_return

  def initialize(name:, tracker: nil, action_to_return: nil, **options)
    super(**options)
    @name = name
    @tracker = tracker
    @action_to_return = action_to_return
  end

  def exec(params)
    @tracker&.record(self, params)
    @action_to_return
  end
end

# Test BatchFlow with custom prep method
class TestBatchFlowWithPrep < FlowNodes::BatchFlow
  attr_reader :prep_called_with

  def prep(state)
    @prep_called_with = state
    state[:batch_items] if state.is_a?(Hash)
  end
end

RSpec.describe FlowNodes::BatchFlow do
  let(:tracker) { BatchExecutionTracker.new }
  let(:node1) { TestBatchNode.new(name: "node1", tracker: tracker) }
  let(:node2) { TestBatchNode.new(name: "node2", tracker: tracker) }

  describe "#_run" do
    it "processes a batch of items sequentially" do
      flow = described_class.new(start: node1)
      node1 >> node2
      
      flow.set_params({ base_param: "value" })
      
      # Mock prep to return batch items
      allow(flow).to receive(:prep).and_return([
        { item_id: 1, data: "first" },
        { item_id: 2, data: "second" },
        { item_id: 3, data: "third" }
      ])
      
      flow.run("test_state")
      
      expected_items = [
        { node: "node1", params: { base_param: "value", item_id: 1, data: "first" } },
        { node: "node2", params: { base_param: "value", item_id: 1, data: "first" } },
        { node: "node1", params: { base_param: "value", item_id: 2, data: "second" } },
        { node: "node2", params: { base_param: "value", item_id: 2, data: "second" } },
        { node: "node1", params: { base_param: "value", item_id: 3, data: "third" } },
        { node: "node2", params: { base_param: "value", item_id: 3, data: "third" } }
      ]
      
      expect(tracker.executed_items).to eq(expected_items)
    end

    it "handles empty batch" do
      flow = described_class.new(start: node1)
      flow.set_params({ base_param: "value" })
      
      allow(flow).to receive(:prep).and_return([])
      
      flow.run("test_state")
      
      expect(tracker.executed_items).to be_empty
    end

    it "handles nil prep result" do
      flow = described_class.new(start: node1)
      flow.set_params({ base_param: "value" })
      
      allow(flow).to receive(:prep).and_return(nil)
      
      flow.run("test_state")
      
      expect(tracker.executed_items).to be_empty
    end

    it "merges flow params with item params, with item params taking precedence" do
      flow = described_class.new(start: node1)
      flow.set_params({ base_param: "base", shared_param: "from_flow" })
      
      allow(flow).to receive(:prep).and_return([
        { item_id: 1, shared_param: "from_item" }
      ])
      
      flow.run("test_state")
      
      expected_params = {
        base_param: "base",
        shared_param: "from_item",  # Item param takes precedence
        item_id: 1
      }
      
      expect(tracker.executed_items[0][:params]).to eq(expected_params)
    end

    it "processes items in order" do
      flow = described_class.new(start: node1)
      
      allow(flow).to receive(:prep).and_return([
        { order: 1 },
        { order: 2 },
        { order: 3 }
      ])
      
      flow.run("test_state")
      
      orders = tracker.execution_order.map { |item| item[:params][:order] }
      expect(orders).to eq([1, 2, 3])
    end

    it "calls prep and post hooks" do
      flow = described_class.new(start: node1)
      batch_items = [{ item: "test" }]
      
      expect(flow).to receive(:prep).with("test_state").and_return(batch_items)
      expect(flow).to receive(:post).with("test_state", batch_items, nil)
      
      flow.run("test_state")
    end

    it "works with custom prep method" do
      flow = TestBatchFlowWithPrep.new(start: node1)
      flow.set_params({ base: "param" })
      
      state = { batch_items: [{ id: 1 }, { id: 2 }] }
      flow.run(state)
      
      expect(flow.prep_called_with).to eq(state)
      expect(tracker.executed_items.size).to eq(2)
      expect(tracker.executed_items[0][:params]).to eq({ base: "param", id: 1 })
      expect(tracker.executed_items[1][:params]).to eq({ base: "param", id: 2 })
    end
  end

  describe "conditional flows in batches" do
    it "handles different actions for different items" do
      # Create a custom node that returns different actions based on item_id
      class ConditionalBatchNode < FlowNodes::Node
        attr_reader :name, :tracker

        def initialize(name:, tracker: nil, **options)
          super(**options)
          @name = name
          @tracker = tracker
        end

        def exec(params)
          @tracker&.record(self, params)
          params[:item_id] == 1 ? "success" : "failure"
        end
      end
      
      start_node = ConditionalBatchNode.new(name: "start", tracker: tracker)
      success_node = TestBatchNode.new(name: "success", tracker: tracker)
      failure_node = TestBatchNode.new(name: "failure", tracker: tracker)
      
      flow = described_class.new(start: start_node)
      
      start_node.nxt(success_node, "success")
      start_node.nxt(failure_node, "failure")
      
      allow(flow).to receive(:prep).and_return([
        { item_id: 1 },
        { item_id: 2 }
      ])
      
      flow.run("test_state")
      
      expect(tracker.executed_items.map { |item| item[:node] }).to eq(%w[start success start failure])
    end
  end

  describe "error handling" do
    it "continues processing remaining items when one fails" do
      # Create a custom node that fails on second item
      class FailingBatchNode < FlowNodes::Node
        attr_reader :name, :tracker
        
        def initialize(name:, tracker: nil, **options)
          super(**options)
          @name = name
          @tracker = tracker
        end
        
        def exec(params)
          if params[:item_id] == 2
            raise "Simulated failure"
          end
          @tracker&.record(self, params)
          nil
        end
      end
      
      failing_node = FailingBatchNode.new(name: "failing", tracker: tracker)
      
      flow = described_class.new(start: failing_node)
      
      allow(flow).to receive(:prep).and_return([
        { item_id: 1 },
        { item_id: 2 },
        { item_id: 3 }
      ])
      
      expect { flow.run("test_state") }.to raise_error("Simulated failure")
      
      # Should have processed first item and failed on second
      expect(tracker.executed_items.size).to eq(1)
      expect(tracker.executed_items[0][:params][:item_id]).to eq(1)
    end
  end

  describe "inheritance from Flow" do
    it "inherits basic flow functionality" do
      flow = described_class.new(start: node1)
      expect(flow).to be_a(FlowNodes::Flow)
      expect(flow.start_node).to eq(node1)
    end

    it "supports setting start node after initialization" do
      flow = described_class.new
      flow.start(node1)
      expect(flow.start_node).to eq(node1)
    end
  end

  describe "parameter isolation" do
    it "doesn't affect original flow params" do
      flow = described_class.new(start: node1)
      original_params = { base: "value" }
      flow.set_params(original_params)
      
      allow(flow).to receive(:prep).and_return([
        { item_param: "item_value" }
      ])
      
      flow.run("test_state")
      
      expect(flow.params).to eq(original_params)
    end

    it "maintains parameter isolation between items" do
      flow = described_class.new(start: node1)
      flow.set_params({ base: "value" })
      
      allow(flow).to receive(:prep).and_return([
        { item_id: 1, data: "first" },
        { item_id: 2, data: "second" }
      ])
      
      flow.run("test_state")
      
      # Each item should have its own merged params
      expect(tracker.executed_items[0][:params]).to eq({ base: "value", item_id: 1, data: "first" })
      expect(tracker.executed_items[1][:params]).to eq({ base: "value", item_id: 2, data: "second" })
    end
  end
end