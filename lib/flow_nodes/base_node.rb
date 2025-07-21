# frozen_string_literal: true

module FlowNodes
  # Base class for all nodes in a flow. Defines the core API for connecting
  # nodes and executing logic.
  class BaseNode
    # @return [Hash] parameters passed to the node during execution.
    attr_accessor :params

    # @return [Hash<String, BaseNode>] a hash mapping action names to successor nodes.
    attr_accessor :successors

    def initialize
      @params = {}
      @successors = {}
    end

    # Creates a deep copy of the node. This is critical for ensuring that each
    # execution of a flow operates on its own isolated set of node instances,
    # preventing state bleed.
    #
    # @param other [BaseNode] The original node being duplicated.
    def initialize_copy(other)
      super
      @params = Marshal.load(Marshal.dump(other.params))
      # Successors are other nodes. The orchestration loop handles duplicating them
      # as they are traversed. A shallow copy of the hash is sufficient here.
      @successors = other.successors.dup
    end

    # Sets the parameters for the node. To ensure thread safety and prevent
    # state bleed, the parameters are deep-copied.
    #
    # @param p [Hash] The parameters to set.
    def set_params(p)
      @params = Marshal.load(Marshal.dump(p || {}))
    end

    # Connects this node to a successor for a given action.
    #
    # @param node [BaseNode] The successor node.
    # @param action [String] The action name that triggers the transition.
    # @return [BaseNode] The successor node.
    def nxt(node, action = "default")
      warn("Overwriting successor for action '#{action}'") if @successors.key?(action)
      @successors[action] = node
      node
    end
    alias next nxt

    # Defines the default transition to the next node.
    # @param other [BaseNode] The node to transition to.
    def >>(other)
      nxt(other)
    end

    # Creates a conditional transition to a successor node.
    # @param action [String, Symbol] The action that triggers this transition.
    # @return [ConditionalTransition] An object to define the target node.
    def -(other)
      raise TypeError, "Action must be a String or Symbol" unless other.is_a?(String) || other.is_a?(Symbol)

      ConditionalTransition.new(self, other.to_s)
    end

    # Enhanced routing DSL that allows multiple conditions to route to the same target.
    # Eliminates repetitive routing syntax when multiple conditions lead to the same flow path.
    #
    # @param route_hash [Hash] A hash mapping conditions to target nodes.
    #   Keys can be individual conditions (String/Symbol) or arrays of conditions.
    #   Values should be BaseNode instances or node chains (e.g., node1 >> node2).
    # @return [BaseNode] Self to enable method chaining.
    #
    # @example Basic usage
    #   node.routes(
    #     [:technical, :billing, :general] => knowledge_base >> responder,
    #     :escalate => escalator,
    #     :unknown => fallback_handler
    #   )
    #
    # @example Single conditions
    #   node.routes(
    #     :success => success_node,
    #     :failure => failure_node
    #   )
    def routes(route_hash)
      raise ArgumentError, "routes expects a Hash" unless route_hash.is_a?(Hash)

      route_hash.each do |conditions, target_node|
        # Convert single conditions to arrays for uniform processing
        conditions_array = conditions.is_a?(Array) ? conditions : [conditions]

        # Validate that all conditions are strings or symbols
        conditions_array.each do |condition|
          unless condition.is_a?(String) || condition.is_a?(Symbol)
            raise TypeError, "Route condition must be a String or Symbol, got #{condition.class}"
          end
        end

        # Validate that target_node is a BaseNode
        raise TypeError, "Route target must be a BaseNode, got #{target_node.class}" unless target_node.is_a?(BaseNode)

        # Set up the routing for each condition
        conditions_array.each do |condition|
          action = condition.to_s
          warn("routes: Overwriting successor for action '#{action}'") if @successors.key?(action)
          @successors[action] = target_node
        end
      end

      self # Enable method chaining
    end

    # Executes the main logic of the node.
    # This is intended to be overridden by subclasses.
    #
    # @param _p [Hash] The parameters for execution.
    # @return [String, Symbol, nil] The result action to determine the next node in a flow.
    def exec(_p)
      nil
    end

    # Runs the full lifecycle of the node: prep, exec, and post.
    # If not part of a Flow, successors will not be executed.
    #
    # @param state [Object] An optional shared state object passed through the flow.
    def run(state)
      warn("Node won't run successors. Use Flow.") unless @successors.empty?
      _run(state)
    end

    protected

    # Pre-execution hook. Can be used to prepare data.
    # @param _state [Object] The shared state object.
    def prep(_state)
      nil
    end

    # Post-execution hook. Can be used for cleanup or logging.
    # @param _state [Object] The shared state object.
    # @param _params [Hash] The parameters used in execution.
    # @param _result [Object] The value returned by `exec`.
    def post(_state, _params, _result)
      nil
    end

    # Internal execution wrapper.
    # @param p [Hash] The parameters for execution.
    def _exec(p)
      exec(p)
    end

    # Internal run lifecycle.
    # @param s [Object] The shared state object.
    def _run(s)
      prepared_params = prep(s)
      # Use the node's params if prep returns nil
      params_to_use = prepared_params || @params
      execution_result = _exec(params_to_use)
      post(s, prepared_params, execution_result)
      execution_result
    end
  end
end
