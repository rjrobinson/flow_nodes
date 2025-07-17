# frozen_string_literal: true

require "spec_helper"

# Test async parallel batch node implementation
class TestAsyncParallelBatchNodeImpl < FlowNodes::AsyncParallelBatchNode
  attr_reader :name, :processed_items, :processing_order

  def initialize(name:, **)
    super(**)
    @name = name
    @processed_items = []
    @processing_order = []
    @mutex = Mutex.new
  end

  def exec_async(item)
    @mutex.synchronize do
      @processed_items << item
      @processing_order << {
        item: item,
        time: Time.now,
        thread: Thread.current.object_id,
      }
    end

    if item.is_a?(Hash) && item[:id]
      "processed_#{item[:id]}_#{@name}"
    else
      "processed_#{item}_#{@name}"
    end
  end
end

# Test async parallel batch node with controllable delays
class TestAsyncParallelBatchNodeWithDelay < FlowNodes::AsyncParallelBatchNode
  attr_reader :name, :processed_items, :delay

  def initialize(name:, delay: 0, **)
    super(**)
    @name = name
    @processed_items = []
    @delay = delay
    @mutex = Mutex.new
  end

  def exec_async(item)
    sleep @delay if @delay > 0
    @mutex.synchronize do
      @processed_items << item
    end
    "processed_#{item[:id]}_#{@name}"
  end
end

# Test async parallel batch node that can fail
class TestAsyncParallelBatchNodeWithFailure < FlowNodes::AsyncParallelBatchNode
  attr_reader :name, :processed_items, :should_fail_on

  def initialize(name:, should_fail_on: [], **)
    super(**)
    @name = name
    @processed_items = []
    @should_fail_on = should_fail_on
    @mutex = Mutex.new
  end

  def exec_async(item)
    @mutex.synchronize do
      @processed_items << item
    end
    raise "Simulated failure for item #{item[:id]}" if @should_fail_on.include?(item[:id])

    "processed_#{item[:id]}_#{@name}"
  end

  def exec_fallback_async(item, exception)
    "fallback_#{item[:id]}_#{exception.message}"
  end
end

RSpec.describe FlowNodes::AsyncParallelBatchNode do
  let(:node) { TestAsyncParallelBatchNodeImpl.new(name: "parallel_batch_node") }

  describe "#_exec_async" do
    it "processes a single item" do
      item = { id: 1, data: "test" }
      result = node.send(:_exec_async, item)

      expect(result).to eq(["processed_1_parallel_batch_node"])
      expect(node.processed_items).to eq([item])
    end

    it "processes multiple items in parallel" do
      items = [
        { id: 1, data: "first" },
        { id: 2, data: "second" },
        { id: 3, data: "third" },
      ]

      result = node.send(:_exec_async, items)

      expect(result).to eq(%w[
                             processed_1_parallel_batch_node
                             processed_2_parallel_batch_node
                             processed_3_parallel_batch_node
                           ])
      expect(node.processed_items).to match_array(items)
    end

    it "uses different threads for different items" do
      items = [
        { id: 1 },
        { id: 2 },
        { id: 3 },
      ]

      node.send(:_exec_async, items)

      # Should use different threads for different items
      thread_ids = node.processing_order.map { |entry| entry[:thread] }.uniq
      expect(thread_ids.size).to be >= 2 # At least 2 different threads
    end

    it "processes items in parallel (faster than sequential)" do
      delayed_node = TestAsyncParallelBatchNodeWithDelay.new(name: "delayed", delay: 0.1)

      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      start_time = Time.now
      result = delayed_node.send(:_exec_async, items)
      end_time = Time.now

      # Should take approximately 100ms (parallel), not 300ms (sequential)
      expect(end_time - start_time).to be < 0.2
      expect(end_time - start_time).to be >= 0.1

      expect(result).to eq(%w[
                             processed_1_delayed
                             processed_2_delayed
                             processed_3_delayed
                           ])
      expect(delayed_node.processed_items).to match_array(items)
    end

    it "handles empty array" do
      result = node.send(:_exec_async, [])

      expect(result).to eq([])
      expect(node.processed_items).to be_empty
    end

    it "handles nil input" do
      result = node.send(:_exec_async, nil)

      expect(result).to eq([])
      expect(node.processed_items).to be_empty
    end

    it "wraps single non-array items in array" do
      item = { id: 1, data: "single" }
      result = node.send(:_exec_async, item)

      expect(result).to eq(["processed_1_parallel_batch_node"])
      expect(node.processed_items).to eq([item])
    end

    it "handles string inputs" do
      result = node.send(:_exec_async, "test_string")

      expect(result).to eq(["processed_test_string_parallel_batch_node"])
      expect(node.processed_items).to eq(["test_string"])
    end

    it "handles numeric inputs" do
      result = node.send(:_exec_async, 42)

      expect(result).to eq(["processed_42_parallel_batch_node"])
      expect(node.processed_items).to eq([42])
    end

    it "waits for all threads to complete" do
      variable_delay_node = TestAsyncParallelBatchNodeWithDelay.new(name: "variable")

      # Mock different delays for different items
      allow(variable_delay_node).to receive(:exec_async) do |item|
        delay = item[:id] * 0.02 # 0.02, 0.04, 0.06 seconds
        sleep delay
        variable_delay_node.processed_items << item
        "processed_#{item[:id]}"
      end

      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      start_time = Time.now
      result = variable_delay_node.send(:_exec_async, items)
      end_time = Time.now

      # Should wait for the longest thread (0.06 seconds)
      expect(end_time - start_time).to be >= 0.06

      # All items should be processed
      expect(result.size).to eq(3)
      expect(variable_delay_node.processed_items.size).to eq(3)
    end
  end

  describe "error handling in parallel processing" do
    it "handles errors in individual threads", :pending do
      failing_node = TestAsyncParallelBatchNodeWithFailure.new(
        name: "failing",
        should_fail_on: [2]
      )

      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      # Error should be raised when threads are joined
      expect { failing_node.send(:_exec_async, items) }.to raise_error("Simulated failure for item 2")

      # Should have processed items 1 and 3 successfully
      expect(failing_node.processed_items.size).to eq(3) # All items were attempted
      processed_ids = failing_node.processed_items.map { |item| item[:id] }
      expect(processed_ids).to contain_exactly(1, 2, 3)
    end

    it "waits for all threads even when some fail", :pending do
      failing_node = TestAsyncParallelBatchNodeWithFailure.new(
        name: "failing",
        should_fail_on: [2]
      )

      # Mock with delays to ensure threads are running
      allow(failing_node).to receive(:exec_async) do |item|
        sleep 0.05
        failing_node.processed_items << item
        raise "Simulated failure for item #{item[:id]}" if failing_node.should_fail_on.include?(item[:id])

        "processed_#{item[:id]}"
      end

      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      start_time = Time.now
      expect { failing_node.send(:_exec_async, items) }.to raise_error("Simulated failure for item 2")
      end_time = Time.now

      # Should have waited for all threads (at least 0.05 seconds)
      expect(end_time - start_time).to be >= 0.05

      # All items should have been attempted
      expect(failing_node.processed_items.size).to eq(3)
    end
  end

  describe "integration with AsyncNode lifecycle" do
    it "works with the complete async node lifecycle" do
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      result = node.run_async("test_state")

      expect(result).to match_array(%w[processed_1_parallel_batch_node processed_2_parallel_batch_node])
      expect(node.processed_items).to match_array(items)
    end

    it "uses prep_async result when available" do
      items = [{ id: 1 }, { id: 2 }]

      allow(node).to receive(:prep_async).and_return(items)
      result = node.run_async("test_state")

      expect(result).to match_array(%w[processed_1_parallel_batch_node processed_2_parallel_batch_node])
      expect(node.processed_items).to match_array(items)
    end

    it "falls back to node params when prep_async returns nil" do
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      allow(node).to receive(:prep_async).and_return(nil)
      result = node.run_async("test_state")

      expect(result).to match_array(%w[processed_1_parallel_batch_node processed_2_parallel_batch_node])
      expect(node.processed_items).to match_array(items)
    end

    it "calls post_async hook with batch results" do
      items = [{ id: 1 }, { id: 2 }]
      expected_result = %w[processed_1_parallel_batch_node processed_2_parallel_batch_node]

      node.set_params(items)
      expect(node).to receive(:post_async).with("test_state", items, expected_result)

      node.run_async("test_state")
    end
  end

  describe "retry logic with parallel batches" do
    it "retries the entire batch on failure" do
      failing_node = TestAsyncParallelBatchNodeWithFailure.new(
        name: "failing",
        should_fail_on: [2],
        max_retries: 3
      )

      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      failing_node.set_params(items)
      result = failing_node.run_async("test_state")

      expect(result).to eq(["processed_1_failing", "fallback_2_Simulated failure for item 2", "processed_3_failing"])
      # Should have tried each item once, plus retries for the failing item
      expect(failing_node.processed_items.size).to eq(5) # 3 items + 2 extra retries for item 2
    end

    it "succeeds after retry if failure is transient" do
      failing_node = TestAsyncParallelBatchNodeWithFailure.new(name: "transient", max_retries: 2)

      items = [{ id: 1 }, { id: 2 }]
      attempt_count = 0

      allow(failing_node).to receive(:exec_async) do |item|
        failing_node.processed_items << item
        attempt_count += 1
        raise "Transient failure" if attempt_count == 1

        "processed_#{item[:id]}_transient"
      end

      failing_node.set_params(items)
      result = failing_node.run_async("test_state")

      expect(result).to eq(%w[processed_1_transient processed_2_transient])
      expect(failing_node.processed_items.size).to eq(3) # 2 items + 1 retry for first item
    end
  end

  describe "inheritance from AsyncNode" do
    it "inherits async node functionality" do
      expect(node).to be_a(FlowNodes::AsyncNode)
      expect(node.respond_to?(:run_async)).to be true
      expect(node.respond_to?(:exec_async)).to be true
    end

    it "inherits max_retries configuration" do
      node = described_class.new(max_retries: 5)
      expect(node.max_retries).to eq(5)
    end

    it "inherits wait configuration" do
      node = described_class.new(wait: 0.1)
      expect(node.wait).to eq(0.1)
    end

    it "can be connected to other nodes" do
      node1 = TestAsyncParallelBatchNodeImpl.new(name: "node1")
      node2 = TestAsyncParallelBatchNodeImpl.new(name: "node2")

      node1 >> node2

      expect(node1.successors["default"]).to eq(node2)
    end

    it "prohibits regular run method" do
      expect { node.send(:_run, "test_state") }.to raise_error("Use run_async for AsyncNode.")
    end
  end

  describe "thread safety and concurrency" do
    it "handles concurrent modification of shared state safely" do
      shared_state_node = TestAsyncParallelBatchNodeImpl.new(name: "shared")

      # Use a shared counter to test thread safety
      counter = 0
      counter_mutex = Mutex.new

      allow(shared_state_node).to receive(:exec_async) do |item|
        counter_mutex.synchronize do
          counter += 1
          shared_state_node.processed_items << item.merge(counter: counter)
        end
        "processed_#{item[:id]}"
      end

      items = (1..10).map { |i| { id: i } }

      shared_state_node.send(:_exec_async, items)

      # All items should be processed
      expect(shared_state_node.processed_items.size).to eq(10)

      # Counter should reach 10
      expect(counter).to eq(10)

      # All counter values should be unique (no race conditions)
      counter_values = shared_state_node.processed_items.map { |item| item[:counter] }.sort
      expect(counter_values).to eq((1..10).to_a)
    end

    it "maintains thread safety during high concurrency" do
      node = TestAsyncParallelBatchNodeImpl.new(name: "high_concurrency")

      # Create a large batch to increase concurrency
      large_batch = (1..50).map { |i| { id: i } }

      result = node.send(:_exec_async, large_batch)

      # All items should be processed
      expect(result.size).to eq(50)
      expect(node.processed_items.size).to eq(50)

      # All items should have unique IDs
      item_ids = node.processed_items.map { |item| item[:id] }.sort
      expect(item_ids).to eq((1..50).to_a)

      # Should use multiple threads
      thread_ids = node.processing_order.map { |entry| entry[:thread] }.uniq
      expect(thread_ids.size).to be >= 2
    end
  end

  describe "parameter handling" do
    it "processes each item with the same node configuration" do
      node = TestAsyncParallelBatchNodeImpl.new(name: "configured", max_retries: 3, wait: 0.1)
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      result = node.run_async("test_state")

      expect(result).to eq(%w[processed_1_configured processed_2_configured])
      expect(node.max_retries).to eq(3)
      expect(node.wait).to eq(0.1)
    end

    it "maintains thread-safe state across parallel processing" do
      node = TestAsyncParallelBatchNodeImpl.new(name: "stateful")
      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      node.set_params(items)
      node.run_async("test_state")

      # processed_items should accumulate across all items
      expect(node.processed_items).to match_array(items)
    end
  end

  describe "edge cases" do
    it "handles nested arrays" do
      items = [[{ id: 1 }, { id: 2 }], [{ id: 3 }, { id: 4 }]]
      result = node.send(:_exec_async, items)

      expect(result).to eq([
                             "processed_[{:id=>1}, {:id=>2}]_parallel_batch_node",
                             "processed_[{:id=>3}, {:id=>4}]_parallel_batch_node",
                           ])
    end

    it "handles complex data structures" do
      items = [
        { id: 1, nested: { data: "complex" } },
        { id: 2, array: [1, 2, 3] },
      ]

      result = node.send(:_exec_async, items)

      expect(result).to eq(%w[
                             processed_1_parallel_batch_node
                             processed_2_parallel_batch_node
                           ])
      expect(node.processed_items).to match_array(items)
    end

    it "handles boolean values" do
      items = [true, false]
      result = node.send(:_exec_async, items)

      expect(result).to eq(%w[
                             processed_true_parallel_batch_node
                             processed_false_parallel_batch_node
                           ])
      expect(node.processed_items).to match_array(items)
    end
  end

  describe "performance characteristics" do
    it "provides significant speedup for I/O-bound tasks" do
      io_simulation_node = TestAsyncParallelBatchNodeWithDelay.new(name: "io_sim", delay: 0.1)

      # Create 5 items that would take 0.5 seconds sequentially
      items = (1..5).map { |i| { id: i } }

      start_time = Time.now
      result = io_simulation_node.send(:_exec_async, items)
      end_time = Time.now

      # Should complete in approximately 0.1 seconds (parallel), not 0.5 seconds (sequential)
      expect(end_time - start_time).to be < 0.2
      expect(end_time - start_time).to be >= 0.1

      # All items should be processed
      expect(result.size).to eq(5)
      expect(io_simulation_node.processed_items.size).to eq(5)
    end

    it "scales well with increased batch size" do
      node = TestAsyncParallelBatchNodeImpl.new(name: "scalable")

      # Test with progressively larger batches
      [10, 20, 50].each do |batch_size|
        items = (1..batch_size).map { |i| { id: i } }

        start_time = Time.now
        result = node.send(:_exec_async, items)
        end_time = Time.now

        # Processing time should not scale linearly with batch size
        expect(end_time - start_time).to be < 0.1 # Should complete quickly
        expect(result.size).to eq(batch_size)

        # Clear processed items for next iteration
        node.processed_items.clear
      end
    end
  end
end
