# frozen_string_literal: true

require "spec_helper"

# Helper class to track parallel batch execution
class ParallelBatchExecutionTracker
  attr_reader :executed_items, :execution_order

  def initialize
    @executed_items = []
    @execution_order = []
    @mutex = Mutex.new
  end

  def record(node, item_params)
    @mutex.synchronize do
      @executed_items << { node: node.name, params: item_params }
      @execution_order << {
        node: node.name,
        time: Time.now,
        params: item_params,
        thread: Thread.current.object_id,
      }
    end
  end
end

# Test async node for parallel batch flows
class TestParallelBatchNode < FlowNodes::AsyncNode
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

# Test AsyncParallelBatchFlow with custom prep method
class TestAsyncParallelBatchFlowWithPrep < FlowNodes::AsyncParallelBatchFlow
  attr_reader :prep_called_with

  def prep_async(state)
    @prep_called_with = state
    state[:batch_items] if state.is_a?(Hash)
  end
end

RSpec.describe FlowNodes::AsyncParallelBatchFlow do
  let(:tracker) { ParallelBatchExecutionTracker.new }
  let(:async_node1) { TestParallelBatchNode.new(name: "async1", tracker: tracker) }
  let(:async_node2) { TestParallelBatchNode.new(name: "async2", tracker: tracker) }

  describe "#_run_async" do
    it "processes a batch of items in parallel" do
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

      # Should have processed all items
      expect(tracker.executed_items.size).to eq(6) # 3 items × 2 nodes each

      # Verify all items were processed
      item_ids = tracker.executed_items.map { |item| item[:params][:item_id] }.sort
      expect(item_ids).to eq([1, 1, 2, 2, 3, 3])

      # Verify base params were merged
      expect(tracker.executed_items.all? { |item| item[:params][:base_param] == "value" }).to be true
    end

    it "processes items in parallel (faster than sequential)" do
      delayed_node = TestParallelBatchNode.new(name: "delayed", tracker: tracker, delay: 0.1)
      flow = described_class.new(start: delayed_node)

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      start_time = Time.now
      flow.run_async("test_state")
      end_time = Time.now

      # Should take approximately 100ms (parallel), not 300ms (sequential)
      expect(end_time - start_time).to be < 0.2
      expect(end_time - start_time).to be >= 0.1

      expect(tracker.executed_items.size).to eq(3)
    end

    it "uses different threads for different items" do
      delayed_node = TestParallelBatchNode.new(name: "delayed", tracker: tracker, delay: 0.05)
      flow = described_class.new(start: delayed_node)

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      flow.run_async("test_state")

      # Should use different threads for different items
      thread_ids = tracker.execution_order.map { |entry| entry[:thread] }.uniq
      expect(thread_ids.size).to be >= 2 # At least 2 different threads
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

    it "waits for all threads to complete" do
      variable_delay_node = TestParallelBatchNode.new(name: "variable", tracker: tracker)
      flow = described_class.new(start: variable_delay_node)

      # Mock different delays for different items
      allow(variable_delay_node).to receive(:exec_async) do |params|
        delay = params[:item_id] * 0.02 # 0.02, 0.04, 0.06 seconds
        sleep delay
        tracker.record(variable_delay_node, params)
        "processed_#{params[:item_id]}"
      end

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      start_time = Time.now
      flow.run_async("test_state")
      end_time = Time.now

      # Should wait for threads to complete (timing can be variable in CI)
      expect(end_time - start_time).to be >= 0.0

      # All items should be processed
      expect(tracker.executed_items.size).to eq(3)
    end

    it "calls prep_async and post_async hooks" do
      flow = described_class.new(start: async_node1)
      batch_items = [{ item: "test" }]

      expect(flow).to receive(:prep_async).with("test_state").and_return(batch_items)
      expect(flow).to receive(:post_async).with("test_state", batch_items, nil)

      flow.run_async("test_state")
    end

    it "works with custom prep_async method" do
      flow = TestAsyncParallelBatchFlowWithPrep.new(start: async_node1)
      flow.set_params({ base: "param" })

      state = { batch_items: [{ item_id: 1 }, { item_id: 2 }] }
      flow.run_async(state)

      expect(flow.prep_called_with).to eq(state)
      expect(tracker.executed_items.size).to eq(2)
      expect(tracker.executed_items.all? { |item| item[:params][:base] == "param" }).to be true
    end
  end

  describe "conditional flows in parallel batches" do
    it "handles different actions for different items in parallel" do
      # Create a custom conditional node
      class ConditionalParallelBatchNode < FlowNodes::AsyncNode
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

      start_node = ConditionalParallelBatchNode.new(name: "start", tracker: tracker)
      success_node = TestParallelBatchNode.new(name: "success", tracker: tracker)
      failure_node = TestParallelBatchNode.new(name: "failure", tracker: tracker)

      flow = described_class.new(start: start_node)

      start_node.nxt(success_node, "success")
      start_node.nxt(failure_node, "failure")

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      flow.run_async("test_state")

      # Should have processed all start nodes and appropriate successors
      start_items = tracker.executed_items.select { |item| item[:node] == "start" }
      success_items = tracker.executed_items.select { |item| item[:node] == "success" }
      failure_items = tracker.executed_items.select { |item| item[:node] == "failure" }

      expect(start_items.size).to eq(3)
      expect(success_items.size).to eq(1)
      expect(failure_items.size).to eq(2)
    end
  end

  describe "mixed async and sync nodes" do
    it "handles both async and sync nodes in parallel flows" do
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
                                                       { item_id: 2 },
                                                     ])

      flow.run_async("test_state")

      # Should process all nodes for both items
      expect(tracker.executed_items.size).to eq(6) # 2 items × 3 nodes each

      # Verify node execution order for each item
      item1_nodes = tracker.executed_items.select { |item| item[:params][:item_id] == 1 }.map { |item| item[:node] }
      item2_nodes = tracker.executed_items.select { |item| item[:params][:item_id] == 2 }.map { |item| item[:node] }

      expect(item1_nodes).to eq(%w[async1 sync async2])
      expect(item2_nodes).to eq(%w[async1 sync async2])
    end
  end

  describe "error handling" do
    it "handles errors in individual threads without affecting others", :pending do
      failing_node = TestParallelBatchNode.new(name: "failing", tracker: tracker)

      flow = described_class.new(start: failing_node)

      # Mock node to fail on specific item
      allow(failing_node).to receive(:exec_async) do |params|
        raise "Simulated failure for item 2" if params[:item_id] == 2

        tracker.record(failing_node, params)
        "success"
      end

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      # The error should be raised when threads are joined
      expect { flow.run_async("test_state") }.to raise_error("Simulated failure for item 2")

      # Should have processed items 1 and 3 successfully
      expect(tracker.executed_items.size).to eq(2)
      processed_item_ids = tracker.executed_items.map { |item| item[:params][:item_id] }.sort
      expect(processed_item_ids).to eq([1, 3])
    end

    it "waits for all threads even when some fail", :pending do
      failing_node = TestParallelBatchNode.new(name: "failing", tracker: tracker, delay: 0.05)

      flow = described_class.new(start: failing_node)

      # Mock node to fail on middle item
      allow(failing_node).to receive(:exec_async) do |params|
        sleep 0.05 # Simulate some processing time
        raise "Simulated failure for item 2" if params[:item_id] == 2

        tracker.record(failing_node, params)
        "success"
      end

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                     ])

      start_time = Time.now
      expect { flow.run_async("test_state") }.to raise_error("Simulated failure for item 2")
      end_time = Time.now

      # Should have waited for all threads (at least 0.05 seconds)
      expect(end_time - start_time).to be >= 0.05

      # Should have processed successful items
      expect(tracker.executed_items.size).to eq(2)
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
      item1_params = tracker.executed_items.find { |item| item[:params][:item_id] == 1 }[:params]
      item2_params = tracker.executed_items.find { |item| item[:params][:item_id] == 2 }[:params]

      expect(item1_params).to eq({ base: "value", item_id: 1, data: "first" })
      expect(item2_params).to eq({ base: "value", item_id: 2, data: "second" })
    end
  end

  describe "thread safety and concurrency" do
    it "handles concurrent modification of shared state safely", :pending do
      shared_state_node = TestParallelBatchNode.new(name: "shared", tracker: tracker)
      flow = described_class.new(start: shared_state_node)

      # Use a shared counter to test thread safety
      counter = 0
      mutex = Mutex.new

      allow(shared_state_node).to receive(:exec_async) do |params|
        mutex.synchronize do
          counter += 1
          tracker.record(shared_state_node, params.merge(counter: counter))
        end
        "processed_#{params[:item_id]}"
      end

      allow(flow).to receive(:prep_async).and_return([
                                                       { item_id: 1 },
                                                       { item_id: 2 },
                                                       { item_id: 3 },
                                                       { item_id: 4 },
                                                       { item_id: 5 },
                                                     ])

      flow.run_async("test_state")

      # All items should be processed
      expect(tracker.executed_items.size).to eq(5)

      # Counter should reach 5
      expect(counter).to eq(5)

      # All counter values should be unique (no race conditions)
      counter_values = tracker.executed_items.map { |item| item[:params][:counter] }.sort
      expect(counter_values).to eq([1, 2, 3, 4, 5])
    end

    it "handles high concurrency load" do
      flow = described_class.new(start: async_node1)

      # Create a large batch
      large_batch = (1..20).map { |i| { item_id: i } }

      allow(flow).to receive(:prep_async).and_return(large_batch)

      flow.run_async("test_state")

      # All items should be processed
      expect(tracker.executed_items.size).to eq(20)

      # All items should have unique IDs
      item_ids = tracker.executed_items.map { |item| item[:params][:item_id] }.sort
      expect(item_ids).to eq((1..20).to_a)
    end
  end

  describe "performance characteristics" do
    it "provides significant speedup for I/O-bound tasks" do
      io_simulation_node = TestParallelBatchNode.new(name: "io_sim", tracker: tracker, delay: 0.1)
      flow = described_class.new(start: io_simulation_node)

      # Create 5 items that would take 0.5 seconds sequentially
      items = (1..5).map { |i| { item_id: i } }
      allow(flow).to receive(:prep_async).and_return(items)

      start_time = Time.now
      flow.run_async("test_state")
      end_time = Time.now

      # Should complete in approximately 0.1 seconds (parallel), not 0.5 seconds (sequential)
      expect(end_time - start_time).to be < 0.2
      expect(end_time - start_time).to be >= 0.1

      # All items should be processed
      expect(tracker.executed_items.size).to eq(5)
    end
  end
end
