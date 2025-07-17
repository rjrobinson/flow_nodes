# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowNodes::Node do
  describe "retry logic" do
    it "executes successfully on the first try" do
      node = described_class.new(max_retries: 3)
      allow(node).to receive(:exec).and_return("success")

      expect(node.send(:_exec, nil)).to eq("success")
      expect(node).to have_received(:exec).once
    end

    it "retries on failure and succeeds" do
      node = described_class.new(max_retries: 3, wait: 0)
      call_count = 0
      allow(node).to receive(:exec) do
        call_count += 1
        raise StandardError if call_count == 1

        "success"
      end

      expect(node.send(:_exec, nil)).to eq("success")
      expect(call_count).to eq(2)
    end

    it "exhausts all retries and calls exec_fallback" do
      node = described_class.new(max_retries: 3, wait: 0)
      allow(node).to receive(:exec).and_raise(StandardError)
      allow(node).to receive(:exec_fallback).and_return("fallback")

      expect(node.send(:_exec, nil)).to eq("fallback")
      expect(node).to have_received(:exec).exactly(3).times
      expect(node).to have_received(:exec_fallback).once
    end

    it "re-raises the last exception by default if fallback is not overridden" do
      node = described_class.new(max_retries: 2, wait: 0)
      allow(node).to receive(:exec).and_raise(RuntimeError, "Failed")

      expect { node.send(:_exec, nil) }.to raise_error(RuntimeError, "Failed")
    end

    it "waits between retries" do
      node = described_class.new(max_retries: 2, wait: 0.1)
      allow(node).to receive(:exec).and_raise(StandardError)

      expect(node).to receive(:sleep).with(0.1).once
      expect { node.send(:_exec, nil) }.to raise_error(StandardError)
    end
  end
end
