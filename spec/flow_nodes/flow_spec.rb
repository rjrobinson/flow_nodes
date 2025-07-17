# frozen_string_literal: true

require "spec_helper"

# Helper class to track which nodes were executed
class ExecutionTracker
  attr_reader :executed_nodes

  def initialize
    @executed_nodes = []
  end

  def record(node)
    # Store a copy of the executed node's state for inspection
    @executed_nodes << node.dup
  end
end

# Helper class to test execution tracking
class TestNode < FlowNodes::Node
  attr_reader :executed_params, :name

  def initialize(name:, action_to_return: nil, tracker: nil, **)
    super(**)
    @name = name
    @action_to_return = action_to_return
    @tracker = tracker
    @executed_params = nil
  end

  def exec(p)
    # The flow sets params on the node before exec, but for our test's tracking
    # purposes, we record the execution with the current node state.
    @executed_params = p
    @tracker&.record(self)
    @action_to_return
  end
end

RSpec.describe FlowNodes::Flow do
  let(:tracker) { ExecutionTracker.new }
  let(:start_node) { TestNode.new(name: "start", tracker: tracker) }
  let(:middle_node) { TestNode.new(name: "middle", tracker: tracker) }
  let(:end_node) { TestNode.new(name: "end", tracker: tracker) }

  describe "#_orch" do
    it "runs a simple linear flow" do
      flow = described_class.new(start: start_node)
      start_node >> middle_node >> end_node

      flow.set_params({ initial: true })
      flow.run(nil)

      expect(tracker.executed_nodes.map(&:name)).to eq(%w[start middle end])
      expect(tracker.executed_nodes[0].params).to eq({ initial: true })
      expect(tracker.executed_nodes[1].params).to eq({ initial: true })
      expect(tracker.executed_nodes[2].params).to eq({ initial: true })
    end

    it "follows a conditional path" do
      start_node = TestNode.new(name: "start", action_to_return: "ok", tracker: tracker)
      flow = described_class.new(start: start_node)
      success_node = TestNode.new(name: "success", tracker: tracker)
      failure_node = TestNode.new(name: "failure", tracker: tracker)

      start_node.nxt(success_node, "ok")
      start_node.nxt(failure_node, "error")

      flow.run(nil)

      expect(tracker.executed_nodes.map(&:name)).to eq(%w[start success])
    end

    it "terminates gracefully when no successor is found" do
      start_node = TestNode.new(name: "start", action_to_return: "an_undefined_action", tracker: tracker)
      flow = described_class.new(start: start_node)
      start_node.nxt(TestNode.new(name: "defined", tracker: tracker), "a_defined_action")

      expect { flow.run(nil) }.to output(/Flow ends: action 'an_undefined_action' not found/).to_stderr
      expect(tracker.executed_nodes.map(&:name)).to eq(%w[start])
    end

    it "raises an error if no start node is defined" do
      flow = described_class.new
      expect { flow.run(nil) }.to raise_error("Flow has no start node")
    end

    it "prevents state bleed between nodes during a run" do
      flow = described_class.new(start: start_node)
      start_node >> middle_node

      flow.set_params({ initial: true })
      flow.run(nil)

      # The original node in the graph should remain pristine
      expect(start_node.params).to be_empty
      expect(start_node.executed_params).to be_nil
    end
  end
end
