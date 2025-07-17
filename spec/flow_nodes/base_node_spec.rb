# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowNodes::BaseNode do
  let(:node) { described_class.new }

  describe "#initialize" do
    it "initializes with empty params and successors" do
      expect(node.params).to be_empty
      expect(node.successors).to be_empty
    end
  end

  describe "#set_params" do
    it "sets parameters for the node" do
      params = { key: "value" }
      node.set_params(params)
      expect(node.params).to eq(params)
    end

    it "deep-copies the parameters to prevent state bleed" do
      original_params = { nested: { key: "value" } }
      node.set_params(original_params)
      original_params[:nested][:key] = "new_value"
      expect(node.params[:nested][:key]).to eq("value")
    end
  end

  describe "#initialize_copy" do
    it "creates a deep copy of the node's params and a shallow copy of successors" do
      node.set_params({ config: { timeout: 60 } })
      successor = FlowNodes::BaseNode.new
      node.nxt(successor, "success")

      new_node = node.dup

      # Modify original node's params
      node.params[:config][:timeout] = 30

      # Expect new node's params to be unchanged
      expect(new_node.params[:config][:timeout]).to eq(60)

      # Expect successors hash to be a different object
      expect(new_node.successors).not_to be(node.successors)

      # But the successor node itself to be the same object (shallow copy)
      expect(new_node.successors["success"]).to be(successor)
    end
  end

  describe "connections" do
    let(:successor_node) { described_class.new }

    it "connects a successor with #nxt" do
      node.nxt(successor_node, "success")
      expect(node.successors["success"]).to be(successor_node)
    end

    it "connects a default successor with >>" do
      node >> successor_node
      expect(node.successors["default"]).to be(successor_node)
    end

    it "creates a conditional transition with -" do
      transition = node - "failure"
      expect(transition).to be_a(FlowNodes::ConditionalTransition)
      transition >> successor_node
      expect(node.successors["failure"]).to be(successor_node)
    end

    it "warns when overwriting a successor" do
      node.nxt(described_class.new, "action")
      expect { node.nxt(successor_node, "action") }.to output(/Overwriting successor/).to_stderr
    end
  end
end
