# frozen_string_literal: true

require "spec_helper"

# Test node for batch processing
class TestBatchNodeImpl < FlowNodes::BatchNode
  attr_reader :name, :processed_items

  def initialize(name:, **)
    super(**)
    @name = name
    @processed_items = []
  end

  def exec(item)
    @processed_items << item

    if item.is_a?(Hash) && item[:id]
      "processed_#{item[:id]}_#{@name}"
    else
      "processed_#{item}_#{@name}"
    end
  end
end

# Test node that can fail
class TestBatchNodeWithFailure < FlowNodes::BatchNode
  attr_reader :name, :processed_items, :should_fail_on

  def initialize(name:, should_fail_on: [], **)
    super(**)
    @name = name
    @processed_items = []
    @should_fail_on = should_fail_on
  end

  def exec(item)
    @processed_items << item

    if item.is_a?(Hash) && item[:id] && @should_fail_on.include?(item[:id])
      raise "Simulated failure for item #{item[:id]}"
    end

    if item.is_a?(Hash) && item[:id]
      "processed_#{item[:id]}_#{@name}"
    else
      "processed_#{item}_#{@name}"
    end
  end

  def exec_fallback(item, exception)
    if item.is_a?(Hash) && item[:id]
      "fallback_#{item[:id]}_#{exception.message}"
    else
      "fallback_#{item}_#{exception.message}"
    end
  end
end

RSpec.describe FlowNodes::BatchNode do
  let(:node) { TestBatchNodeImpl.new(name: "batch_node") }

  describe "#_exec" do
    it "processes a single item" do
      item = { id: 1, data: "test" }
      result = node.send(:_exec, item)

      expect(result).to eq(["processed_1_batch_node"])
      expect(node.processed_items).to eq([item])
    end

    it "processes multiple items in an array" do
      items = [
        { id: 1, data: "first" },
        { id: 2, data: "second" },
        { id: 3, data: "third" },
      ]

      result = node.send(:_exec, items)

      expect(result).to eq(%w[
                             processed_1_batch_node
                             processed_2_batch_node
                             processed_3_batch_node
                           ])
      expect(node.processed_items).to eq(items)
    end

    it "handles empty array" do
      result = node.send(:_exec, [])

      expect(result).to eq([])
      expect(node.processed_items).to be_empty
    end

    it "handles nil input" do
      result = node.send(:_exec, nil)

      expect(result).to eq([])
      expect(node.processed_items).to be_empty
    end

    it "wraps single non-array items in array" do
      item = { id: 1, data: "single" }
      result = node.send(:_exec, item)

      expect(result).to eq(["processed_1_batch_node"])
      expect(node.processed_items).to eq([item])
    end

    it "handles string inputs" do
      result = node.send(:_exec, "test_string")

      expect(result).to eq(["processed_test_string_batch_node"])
      expect(node.processed_items).to eq(["test_string"])
    end

    it "handles numeric inputs" do
      result = node.send(:_exec, 42)

      expect(result).to eq(["processed_42_batch_node"])
      expect(node.processed_items).to eq([42])
    end
  end

  describe "integration with Node lifecycle" do
    it "works with the complete node lifecycle" do
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      result = node.run("test_state")

      expect(result).to eq(%w[processed_1_batch_node processed_2_batch_node])
      expect(node.processed_items).to eq(items)
    end

    it "uses prep result when available" do
      items = [{ id: 1 }, { id: 2 }]

      allow(node).to receive(:prep).and_return(items)
      result = node.run("test_state")

      expect(result).to eq(%w[processed_1_batch_node processed_2_batch_node])
      expect(node.processed_items).to eq(items)
    end

    it "falls back to node params when prep returns nil" do
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      allow(node).to receive(:prep).and_return(nil)
      result = node.run("test_state")

      expect(result).to eq(%w[processed_1_batch_node processed_2_batch_node])
      expect(node.processed_items).to eq(items)
    end

    it "calls post hook with batch results" do
      items = [{ id: 1 }, { id: 2 }]
      expected_result = %w[processed_1_batch_node processed_2_batch_node]

      node.set_params(items)
      expect(node).to receive(:post).with("test_state", items, expected_result)

      node.run("test_state")
    end
  end

  describe "retry logic with batches" do
    it "retries the entire batch on failure" do
      failing_node = TestBatchNodeWithFailure.new(
        name: "failing",
        should_fail_on: [2],
        max_retries: 3
      )

      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      failing_node.set_params(items)
      result = failing_node.run("test_state")

      expect(result).to eq(["processed_1_failing", "fallback_2_Simulated failure for item 2", "processed_3_failing"])
      # Should have tried each item once, plus retries for the failing item
      expect(failing_node.processed_items.size).to eq(5) # 3 items + 2 extra retries for item 2
    end

    it "succeeds after retry if failure is transient" do
      # Create a node that fails on first attempt only
      failing_node = TestBatchNodeWithFailure.new(name: "transient", max_retries: 2)

      items = [{ id: 1 }, { id: 2 }]
      attempt_count = 0

      allow(failing_node).to receive(:exec) do |item|
        failing_node.processed_items << item
        attempt_count += 1
        raise "Transient failure" if attempt_count == 1

        "processed_#{item[:id]}_transient"
      end

      failing_node.set_params(items)
      result = failing_node.run("test_state")

      expect(result).to eq(%w[processed_1_transient processed_2_transient])
      expect(failing_node.processed_items.size).to eq(3) # 2 items + 1 retry for first item
    end
  end

  describe "inheritance from Node" do
    it "inherits max_retries configuration" do
      node = described_class.new(max_retries: 5)
      expect(node.max_retries).to eq(5)
    end

    it "inherits wait configuration" do
      node = described_class.new(wait: 0.1)
      expect(node.wait).to eq(0.1)
    end

    it "can be connected to other nodes" do
      node1 = TestBatchNodeImpl.new(name: "node1")
      node2 = TestBatchNodeImpl.new(name: "node2")

      node1 >> node2

      expect(node1.successors["default"]).to eq(node2)
    end
  end

  describe "parameter handling" do
    it "processes each item with the same node configuration" do
      node = TestBatchNodeImpl.new(name: "configured", max_retries: 3, wait: 0.1)
      items = [{ id: 1 }, { id: 2 }]

      node.set_params(items)
      result = node.run("test_state")

      expect(result).to eq(%w[processed_1_configured processed_2_configured])
      expect(node.max_retries).to eq(3)
      expect(node.wait).to eq(0.1)
    end

    it "maintains state between item processing" do
      node = TestBatchNodeImpl.new(name: "stateful")
      items = [{ id: 1 }, { id: 2 }, { id: 3 }]

      node.set_params(items)
      node.run("test_state")

      # processed_items should accumulate across all items
      expect(node.processed_items).to eq(items)
    end
  end

  describe "edge cases" do
    it "handles nested arrays" do
      items = [[{ id: 1 }, { id: 2 }], [{ id: 3 }, { id: 4 }]]
      result = node.send(:_exec, items)

      expect(result).to eq([
                             "processed_[{:id=>1}, {:id=>2}]_batch_node",
                             "processed_[{:id=>3}, {:id=>4}]_batch_node",
                           ])
    end

    it "handles complex data structures" do
      items = [
        { id: 1, nested: { data: "complex" } },
        { id: 2, array: [1, 2, 3] },
      ]

      result = node.send(:_exec, items)

      expect(result).to eq(%w[
                             processed_1_batch_node
                             processed_2_batch_node
                           ])
      expect(node.processed_items).to eq(items)
    end

    it "handles boolean values" do
      items = [true, false]
      result = node.send(:_exec, items)

      expect(result).to eq(%w[
                             processed_true_batch_node
                             processed_false_batch_node
                           ])
      expect(node.processed_items).to eq(items)
    end
  end
end
