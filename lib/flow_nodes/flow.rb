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
    def _orch(state, params: nil)
      raise "Flow has no start node" unless @start_node

      current_node = @start_node.dup
      flow_params = params || @params
      last_result = nil

      while current_node
        current_node.set_params(flow_params)
        last_result = current_node._run(state)
        current_node = get_next_node(current_node, last_result)&.dup
      end
      last_result
    end

    def _run(s)
      prepared_params = prep(s)
      result = _orch(s, params: prepared_params || @params)
      post(s, prepared_params, result)
      result
    end

    # Determines the next node based on the result of the current node.
    # For routing to work predictably, the return value of a node's `exec` method
    # should be a String or Symbol that matches a defined successor action.
    def get_next_node(current_node, action)
      action_key = (action.nil? || action == "") ? "default" : action.to_s
      successor = current_node.successors[action_key]

      if !successor && !current_node.successors.empty?
        warn("Flow ends: action '#{action_key}' not found in successors: #{current_node.successors.keys.inspect}")
      end
      successor
    end
  end
end
