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
    def -(action)
      unless action.is_a?(String) || action.is_a?(Symbol)
        raise TypeError, "Action must be a String or Symbol"
      end
      ConditionalTransition.new(self, action.to_s)
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
