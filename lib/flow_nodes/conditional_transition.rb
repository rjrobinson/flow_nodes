# frozen_string_literal: true

module FlowNodes
  # Represents a pending conditional transition from one node to another.
  class ConditionalTransition
    def initialize(source_node, action)
      @source_node = source_node
      @action = action
    end

    # Completes the transition by connecting the source node to the target.
    # @param target_node [BaseNode] The node to transition to.
    def >>(target_node)
      @source_node.nxt(target_node, @action)
    end
  end
end
