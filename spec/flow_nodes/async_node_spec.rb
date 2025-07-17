# frozen_string_literal: true

require "spec_helper"

# Test async node with controllable behavior
class TestAsyncNodeWithRetries < FlowNodes::AsyncNode
  attr_reader :name, :attempt_count, :should_fail_until

  def initialize(name:, should_fail_until: 0, **)
    super(**)
    @name = name
    @attempt_count = 0
    @should_fail_until = should_fail_until
  end

  def exec_async(_params)
    @attempt_count += 1
    raise "Simulated failure on attempt #{@attempt_count}" if @attempt_count <= @should_fail_until

    "success_#{@attempt_count}"
  end

  def exec_fallback_async(_params, _exception)
    "fallback_after_#{@attempt_count}_attempts"
  end
end

RSpec.describe FlowNodes::AsyncNode do
  let(:node) { described_class.new }

  describe "#run_async" do
    it "warns when node has successors" do
      node.nxt(described_class.new, "next")
      expect { node.run_async(nil) }.to output(/Node won't run successors. Use AsyncFlow./).to_stderr
    end

    it "calls _run_async" do
      expect(node).to receive(:_run_async).with("test_state")
      node.run_async("test_state")
    end
  end

  describe "#_run" do
    it "raises an error when called directly" do
      expect { node.send(:_run, nil) }.to raise_error("Use run_async for AsyncNode.")
    end
  end

  describe "async lifecycle" do
    let(:test_node) { TestAsyncNodeWithRetries.new(name: "test") }

    it "calls prep_async, exec_async, and post_async in sequence" do
      expect(test_node).to receive(:prep_async).with("test_state").and_return({ prepared: true })
      expect(test_node).to receive(:exec_async).with({ prepared: true }).and_return("result")
      expect(test_node).to receive(:post_async).with("test_state", { prepared: true }, "result")

      result = test_node.run_async("test_state")
      expect(result).to eq("result")
    end

    it "uses node params when prep_async returns nil" do
      test_node.set_params({ node_param: "value" })

      allow(test_node).to receive(:prep_async).and_return(nil)
      expect(test_node).to receive(:exec_async).with({ node_param: "value" })

      test_node.run_async("test_state")
    end
  end

  describe "retry logic" do
    it "executes successfully on the first try" do
      test_node = TestAsyncNodeWithRetries.new(name: "success", should_fail_until: 0)

      result = test_node.run_async(nil)
      expect(result).to eq("success_1")
      expect(test_node.attempt_count).to eq(1)
    end

    it "retries on failure and eventually succeeds" do
      test_node = TestAsyncNodeWithRetries.new(name: "retry", should_fail_until: 2, max_retries: 3)

      result = test_node.run_async(nil)
      expect(result).to eq("success_3")
      expect(test_node.attempt_count).to eq(3)
    end

    it "exhausts all retries and calls exec_fallback_async" do
      test_node = TestAsyncNodeWithRetries.new(name: "fallback", should_fail_until: 5, max_retries: 3)

      result = test_node.run_async(nil)
      expect(result).to eq("fallback_after_3_attempts")
      expect(test_node.attempt_count).to eq(3)
    end

    it "waits between retries" do
      test_node = TestAsyncNodeWithRetries.new(name: "wait", should_fail_until: 2, max_retries: 3, wait: 0.05)

      start_time = Time.now
      test_node.run_async(nil)
      end_time = Time.now

      # Should wait 0.05 seconds twice (between attempts 1-2 and 2-3)
      expect(end_time - start_time).to be >= 0.1
      expect(test_node.attempt_count).to eq(3)
    end

    it "doesn't wait after the last retry" do
      test_node = TestAsyncNodeWithRetries.new(name: "no_wait", should_fail_until: 3, max_retries: 2, wait: 0.05)

      start_time = Time.now
      test_node.run_async(nil)
      end_time = Time.now

      # Should only wait once (between attempts 1-2), not after attempt 2
      expect(end_time - start_time).to be >= 0.05
      expect(end_time - start_time).to be < 0.1
      expect(test_node.attempt_count).to eq(2)
    end

    it "calls exec_fallback_async when all retries are exhausted" do
      test_node = TestAsyncNodeWithRetries.new(name: "fallback_test", should_fail_until: 5, max_retries: 2)

      result = test_node.run_async(nil)
      expect(result).to eq("fallback_after_2_attempts")
    end

    it "re-raises exception when exec_fallback_async is not overridden" do
      node = described_class.new(max_retries: 2)

      allow(node).to receive(:exec_async).and_raise("Test error")

      expect { node.run_async(nil) }.to raise_error("Test error")
    end
  end

  describe "parameter handling" do
    it "passes prepared params to exec_async" do
      test_node = TestAsyncNodeWithRetries.new(name: "params")

      allow(test_node).to receive(:prep_async).and_return({ from_prep: "value" })
      expect(test_node).to receive(:exec_async).with({ from_prep: "value" })

      test_node.run_async("test_state")
    end

    it "uses node params when prep_async returns nil" do
      test_node = TestAsyncNodeWithRetries.new(name: "params")
      test_node.set_params({ node_param: "value" })

      allow(test_node).to receive(:prep_async).and_return(nil)
      expect(test_node).to receive(:exec_async).with({ node_param: "value" })

      test_node.run_async("test_state")
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

    it "inherits current_retry tracking" do
      node = described_class.new
      expect(node.current_retry).to eq(0)
    end
  end

  describe "hook methods" do
    it "has default implementations that return nil" do
      expect(node.send(:prep_async, "state")).to be_nil
      expect(node.send(:exec_async, {})).to be_nil
      expect(node.send(:post_async, "state", {}, "result")).to be_nil
    end

    it "delegates exec_fallback_async to exec_fallback by default" do
      params = { test: "value" }
      exception = RuntimeError.new("test error")

      expect(node).to receive(:exec_fallback).with(params, exception).and_return("fallback_result")

      result = node.send(:exec_fallback_async, params, exception)
      expect(result).to eq("fallback_result")
    end
  end
end
