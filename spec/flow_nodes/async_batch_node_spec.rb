# frozen_string_literal: true

require "spec_helper"

# Test async batch node implementation
class TestAsyncBatchNodeImpl < FlowNodes::AsyncBatchNode
  attr_reader :name, :processed_items, :processing_order

  def initialize(name:, **options)
    super(**options)
    @name = name
    @processed_items = []
    @processing_order = []
    @mutex = Mutex.new
  end

  def exec_async(item)
    @mutex.synchronize do
      @processed_items << item
      @processing_order << { item: item, time: Time.now, thread: Thread.current.object_id }
    end

    if item.is_a?(Hash) && item[:id]
      "processed_#{item[:id]}_#{@name}"
    else
      "processed_#{item}_#{@name}"
    end
  end
end

# Test async batch node with controllable delays
class TestAsyncBatchNodeWithDelay < FlowNodes::AsyncBatchNode
  attr_reader :name, :processed_items, :delay

  def initialize(name:, delay: 0, **options)
    super(**options)
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

    if item.is_a?(Hash) && item[:id]
      "processed_#{item[:id]}_#{@name}"
    else
      "processed_#{item}_#{@name}"
    end
  end
end

# Test async batch node that can fail
class TestAsyncBatchNodeWithFailure < FlowNodes::AsyncBatchNode
  attr_reader :name, :processed_items, :should_fail_on

  def initialize(name:, should_fail_on: [], **options)
    super(**options)
    @name = name
    @processed_items = []
    @should_fail_on = should_fail_on
    @mutex = Mutex.new
  end

  def exec_async(item)
    @mutex.synchronize do
      @processed_items << item
    end

    if item.is_a?(Hash) && item[:id] && @should_fail_on.include?(item[:id])
      raise "Simulated failure for item #{item[:id]}"
    end

    if item.is_a?(Hash) && item[:id]
      "processed_#{item[:id]}_#{@name}"
    else
      "processed_#{item}_#{@name}"
    end
  end

  def exec_fallback_async(item, exception)
    if item.is_a?(Hash) && item[:id]
      "fallback_#{item[:id]}_#{exception.message}"
    else
      "fallback_#{item}_#{exception.message}"
    end
  end
end

RSpec.describe FlowNodes::AsyncBatchNode do
  let(:node) { TestAsyncBatchNodeImpl.new(name: "async_batch_node") }

  describe "#_exec_async" do
    it "processes a single item" do
      item = { id: 1, data: "test" }
      result = node.send(:_exec_async, item)

      expect(result).to eq(["processed_1_async_batch_node"])
      expect(node.processed_items).to eq([item])
    end

    it "processes multiple items in an array" do
      items = [
        { id: 1, data: "first" },
        { id: 2, data: "second" },
        { id: 3, data: "third" },
      ]

      result = node.send(:_exec_async, items)

      expect(result).to eq(%w[
                             processed_1_async_batch_node
                             processed_2_async_batch_node
                             processed_3_async_batch_node
                           ])
      expect(node.processed_items).to eq(items)
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

      expect(result).to eq(["processed_1_async_batch_node"])
      expect(node.processed_items).to eq([item])
    end

    it "handles string inputs" do
      result = node.send(:_exec_async, "test_string")

      expect(result).to eq(["processed_test_string_async_batch_node"])
      expect(node.processed_items).to eq(["test_string"])
    end

    it "handles numeric inputs" do
      result = node.send(:_exec_async, 42)

      expect(result).to eq(["processed_42_async_batch_node"])
      expect(node.processed_items).to eq([42])
    end
  end

  describe "sequential processing" do
    it "processes items sequentially, not in parallel" do
      delayed_node = TestAsyncBatchNodeWithDelay.new(name: "delayed", delay: 0.05)

      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      start_time = Time.now
      result = delayed_node.send(:_exec_async, items)
      end_time = Time.now

      # Should take at least 150ms (3 items × 50ms each)
      expect(end_time - start_time).to be >= 0.15

      expect(result).to eq(%w[
                             processed_1_delayed
                             processed_2_delayed
                             processed_3_delayed
                           ])
      expect(delayed_node.processed_items).to eq(items)
    end

    it "maintains order of processing" do
      items = [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }]

      node.send(:_exec_async, items)

      processed_ids = node.processing_order.map { |entry| entry[:item][:id] }
      expect(processed_ids).to eq([1, 2, 3, 4])

      # Verify timestamps are in order
      timestamps = node.processing_order.map { |entry| entry[:time] }
      expect(timestamps).to eq(timestamps.sort)
    end
  end

  describe "integration with AsyncNode lifecycle" do
    it "works with the complete async node lifecycle" do
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      result = node.run_async("test_state")

      expect(result).to eq(%w[processed_1_async_batch_node processed_2_async_batch_node])
      expect(node.processed_items).to eq(items)
    end

    it "uses prep_async result when available" do
      items = [{ id: 1 }, { id: 2 }]

      allow(node).to receive(:prep_async).and_return(items)
      result = node.run_async("test_state")

      expect(result).to eq(%w[processed_1_async_batch_node processed_2_async_batch_node])
      expect(node.processed_items).to eq(items)
    end

    it "falls back to node params when prep_async returns nil" do
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      allow(node).to receive(:prep_async).and_return(nil)
      result = node.run_async("test_state")

      expect(result).to eq(%w[processed_1_async_batch_node processed_2_async_batch_node])
      expect(node.processed_items).to eq(items)
    end

    it "calls post_async hook with batch results" do
      items = [{ id: 1 }, { id: 2 }]
      expected_result = %w[processed_1_async_batch_node processed_2_async_batch_node]

      node.set_params(items)
      expect(node).to receive(:post_async).with("test_state", items, expected_result)

      node.run_async("test_state")
    end
  end

  describe "retry logic with async batches" do
    it "retries the entire batch on failure" do
      failing_node = TestAsyncBatchNodeWithFailure.new(
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
      failing_node = TestAsyncBatchNodeWithFailure.new(name: "transient", max_retries: 2)

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

    it "waits between retries" do
      failing_node = TestAsyncBatchNodeWithFailure.new(
        name: "wait_test",
        should_fail_on: [1],
        max_retries: 2,
        wait: 0.05
      )

      items = [{ id: 1 }]

      failing_node.set_params(items)
      start_time = Time.now
      failing_node.run_async("test_state")
      end_time = Time.now

      # Should wait 0.05 seconds between retries
      expect(end_time - start_time).to be >= 0.05
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
      node1 = TestAsyncBatchNodeImpl.new(name: "node1")
      node2 = TestAsyncBatchNodeImpl.new(name: "node2")

      node1 >> node2

      expect(node1.successors["default"]).to eq(node2)
    end

    it "prohibits regular run method" do
      expect { node.send(:_run, "test_state") }.to raise_error("Use run_async for AsyncNode.")
    end
  end

  describe "parameter handling" do
    it "processes each item with the same node configuration" do
      node = TestAsyncBatchNodeImpl.new(name: "configured", max_retries: 3, wait: 0.1)
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      result = node.run_async("test_state")

      expect(result).to eq(%w[processed_1_configured processed_2_configured])
      expect(node.max_retries).to eq(3)
      expect(node.wait).to eq(0.1)
    end

    it "maintains thread-safe state between item processing" do
      node = TestAsyncBatchNodeImpl.new(name: "stateful")
      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      node.set_params(items)
      node.run_async("test_state")

      # processed_items should accumulate across all items
      expect(node.processed_items).to eq(items)
    end
  end

  describe "edge cases" do
    it "handles nested arrays" do
      items = [[{ id: 1 }, { id: 2 }], [{ id: 3 }, { id: 4 }]]
      result = node.send(:_exec_async, items)

      expect(result).to eq([
                             "processed_[{:id=>1}, {:id=>2}]_async_batch_node",
                             "processed_[{:id=>3}, {:id=>4}]_async_batch_node",
                           ])
    end

    it "handles complex data structures" do
      items = [
        { id: 1, nested: { data: "complex" } },
        { id: 2, array: [1, 2, 3] },
      ]

      result = node.send(:_exec_async, items)

      expect(result).to eq(%w[
                             processed_1_async_batch_node
                             processed_2_async_batch_node
                           ])
      expect(node.processed_items).to eq(items)
    end

    it "handles boolean values" do
      items = [true, false]
      result = node.send(:_exec_async, items)

      expect(result).to eq(%w[
                             processed_true_async_batch_node
                             processed_false_async_batch_node
                           ])
      expect(node.processed_items).to eq(items)
    end
  end

  describe "thread safety" do
    it "maintains thread safety during batch processing" do
      TestAsyncBatchNodeImpl.new(name: "thread_safe")
      items = (1..100).map { |i| { id: i } }

      # Process the same batch multiple times in different threads
      threads = 5.times.map do |thread_id|
        Thread.new do
          node_instance = TestAsyncBatchNodeImpl.new(name: "thread_#{thread_id}")
          node_instance.send(:_exec_async, items)
          node_instance.processed_items
        end
      end

      results = threads.map(&:value)

      # Each thread should process all items
      expect(results.all? { |result| result.size == 100 }).to be true

      # Each thread should have processed the same items
      expect(results.all? { |result| result == items }).to be true
    end
  end
end
