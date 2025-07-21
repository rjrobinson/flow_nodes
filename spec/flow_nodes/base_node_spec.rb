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

  describe "#routes" do
    let(:target_node1) { described_class.new }
    let(:target_node2) { described_class.new }
    let(:target_node3) { described_class.new }

    describe "basic functionality" do
      it "routes multiple conditions to the same target" do
        node.routes(
          %i[condition1 condition2] => target_node1,
          :condition3 => target_node2
        )

        expect(node.successors["condition1"]).to eq(target_node1)
        expect(node.successors["condition2"]).to eq(target_node1)
        expect(node.successors["condition3"]).to eq(target_node2)
      end

      it "handles single conditions" do
        node.routes(
          success: target_node1,
          failure: target_node2
        )

        expect(node.successors["success"]).to eq(target_node1)
        expect(node.successors["failure"]).to eq(target_node2)
      end

      it "handles string and symbol conditions" do
        node.routes(
          ["string_condition", :symbol_condition] => target_node1
        )

        expect(node.successors["string_condition"]).to eq(target_node1)
        expect(node.successors["symbol_condition"]).to eq(target_node1)
      end

      it "returns self to enable method chaining" do
        result = node.routes(condition: target_node1)
        expect(result).to be(node)
      end
    end

    describe "error handling" do
      it "raises ArgumentError when passed non-hash argument" do
        expect { node.routes("not a hash") }.to raise_error(ArgumentError, "routes expects a Hash")
      end

      it "raises TypeError when condition is not String or Symbol" do
        expect do
          node.routes(123 => target_node1)
        end.to raise_error(TypeError, "Route condition must be a String or Symbol, got Integer")
      end

      it "raises TypeError when condition in array is not String or Symbol" do
        expect do
          node.routes([:valid, 123] => target_node1)
        end.to raise_error(TypeError, "Route condition must be a String or Symbol, got Integer")
      end

      it "raises TypeError when target is not a BaseNode" do
        expect do
          node.routes(condition: "not a node")
        end.to raise_error(TypeError, "Route target must be a BaseNode, got String")
      end
    end

    describe "overwriting warnings" do
      it "warns when overwriting existing successors" do
        node.nxt(target_node1, "existing")

        expect do
          node.routes(existing: target_node2)
        end.to output(/routes: Overwriting successor for action 'existing'/).to_stderr
      end

      it "warns for each overwritten successor in array" do
        node.nxt(target_node1, "action1")
        node.nxt(target_node2, "action2")

        expect do
          node.routes(%i[action1 action2] => target_node3)
        end.to output(/routes: Overwriting successor for action 'action1'.*routes: Overwriting successor for action 'action2'/m).to_stderr
      end
    end

    describe "complex routing scenarios" do
      it "handles empty hash" do
        expect { node.routes({}) }.not_to raise_error
        expect(node.successors).to be_empty
      end

      it "handles mixed single and multiple conditions" do
        node.routes(
          %i[multiple1 multiple2] => target_node1,
          :single => target_node2,
          [:another_multiple] => target_node3
        )

        expect(node.successors["multiple1"]).to eq(target_node1)
        expect(node.successors["multiple2"]).to eq(target_node1)
        expect(node.successors["single"]).to eq(target_node2)
        expect(node.successors["another_multiple"]).to eq(target_node3)
      end

      it "works with node chains as targets" do
        # Create a chain: target_node1 >> target_node2
        chain_head = target_node1 >> target_node2

        node.routes(
          %i[condition1 condition2] => chain_head
        )

        expect(node.successors["condition1"]).to eq(chain_head)
        expect(node.successors["condition2"]).to eq(chain_head)
      end
    end

    describe "backwards compatibility" do
      it "works alongside existing nxt method" do
        # Use old syntax
        node.nxt(target_node1, "old_style")

        # Use new syntax
        node.routes(new_style: target_node2)

        # Both should work
        expect(node.successors["old_style"]).to eq(target_node1)
        expect(node.successors["new_style"]).to eq(target_node2)
      end

      it "works alongside existing >> operator" do
        other_node = described_class.new

        # Use old syntax
        node >> target_node1

        # Use new syntax on different node
        other_node.routes(condition: target_node2)

        expect(node.successors["default"]).to eq(target_node1)
        expect(other_node.successors["condition"]).to eq(target_node2)
      end

      it "works alongside existing - operator" do
        # Use old conditional syntax
        (node - :old_condition) >> target_node1

        # Use new syntax
        node.routes(new_condition: target_node2)

        expect(node.successors["old_condition"]).to eq(target_node1)
        expect(node.successors["new_condition"]).to eq(target_node2)
      end

      it "maintains same internal structure as existing methods" do
        # Set up using old methods
        node.nxt(target_node1, "action1")
        (node - :action2) >> target_node2

        # Set up using new method
        node.routes(action3: target_node3)

        # All should have same structure in successors hash
        expect(node.successors).to be_a(Hash)
        expect(node.successors.keys).to contain_exactly("action1", "action2", "action3")
        expect(node.successors.values).to contain_exactly(target_node1, target_node2, target_node3)
      end

      it "can be mixed in the same flow definition" do
        # This simulates a real-world scenario where someone upgrades gradually

        # Old style routing
        node.nxt(target_node1, "legacy")
        (node - :conditional) >> target_node2

        # New style routing
        node.routes(
          %i[modern1 modern2] => target_node3
        )

        # Verify all routes work
        expect(node.successors["legacy"]).to eq(target_node1)
        expect(node.successors["conditional"]).to eq(target_node2)
        expect(node.successors["modern1"]).to eq(target_node3)
        expect(node.successors["modern2"]).to eq(target_node3)
      end
    end
  end
end
