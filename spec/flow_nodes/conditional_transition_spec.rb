# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowNodes::ConditionalTransition do
  let(:source_node) { FlowNodes::BaseNode.new }
  let(:target_node) { FlowNodes::BaseNode.new }
  let(:action) { "custom_action" }

  describe "#>>" do
    it "connects the source node to the target node with the specified action" do
      transition = described_class.new(source_node, action)
      transition >> target_node

      expect(source_node.successors[action]).to be(target_node)
    end
  end
end
