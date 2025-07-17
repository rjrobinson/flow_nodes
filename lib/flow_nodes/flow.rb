# frozen_string_literal: true

module FlowNodes
  # Orchestrates a sequence of connected nodes, managing state and transitions.
  class Flow < BaseNode
    attr_accessor :start_node

    def initialize(start: nil)
      super()
      @start_node = start
    end

    # Sets the starting node of the flow.
    # @param node [BaseNode] The node to start the flow with.
    # @return [BaseNode] The starting node.
    def start(node)
      @start_node = node
      node
    end

    protected

    # Main orchestration logic that walks through the node graph.
    def _orch(initial_params)
      raise "Flow has no start node" unless @start_node

      current_node = @start_node.dup
      current_params = initial_params

      loop do
        # Merge the node's own params with the incoming params from the flow.
        # The flow's params take precedence.
        merged_params = current_node.params.merge(current_params || {})
        current_node.set_params(merged_params)
        current_params = merged_params # Ensure current_params is updated for the next iteration

        action = current_node._run(current_node.params)

        # If the node returns a symbol, it's an action to determine the next node.
        current_node = get_next_node(current_node, action)&.dup
        break unless current_node
      end
    end

    def _run(s)
      prepared_params = prep(s)
      result = _orch(prepared_params || @params)
      post(s, prepared_params, result)
      result
    end

    # Determines the next node based on the result of the current node.
    # For routing to work predictably, the return value of a node's `exec` method
    # should be a String or Symbol that matches a defined successor action.
    def get_next_node(current_node, action)
      action_key = action.nil? || action == "" ? "default" : action.to_s
      successor = current_node.successors[action_key]

      if !successor && !current_node.successors.empty?
        warn("Flow ends: action '#{action_key}' not found in successors: #{current_node.successors.keys.inspect}")
      end
      successor
    end
  end
end
