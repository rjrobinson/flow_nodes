# frozen_string_literal: true

require_relative "flow_nodes/version"

# FlowNodes is a minimalist, graph-based framework for building complex workflows
# and agentic systems in Ruby. It is a port of the Python PocketFlow library.
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
      execution_result = _exec(prepared_params)
      post(s, prepared_params, execution_result)
      execution_result
    end
  end

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

  # A node with built-in retry logic.
  class Node < BaseNode
    attr_reader :max_retries, :wait, :current_retry

    def initialize(max_retries: 1, wait: 0)
      super()
      @max_retries = max_retries
      @wait = wait
      @current_retry = 0
    end

    # Public method to execute the node's logic with retries.
    # This is the entry point for a flow to run a node.
    def _run(s)
      prepared_params = prep(s)
      actual_params = prepared_params || @params
      execution_result = _exec(actual_params)
      post(s, actual_params, execution_result)
      execution_result
    end

    protected

    # Internal execution logic with retries.
    # @note If your `exec` method performs actions with side effects (e.g., API calls,
    #   database writes), ensure they are idempotent. Retries will re-execute the logic,
    #   which could cause unintended repeated effects if not designed carefully.
    def _exec(p)
      last_exception = nil
      @max_retries.times do |i|
        @current_retry = i
        begin
          return exec(p)
        rescue => e
          last_exception = e
          sleep @wait if @wait.positive? && i < @max_retries - 1
        end
      end
      exec_fallback(p, last_exception)
    end

    # Fallback method called after all retries have been exhausted.
    # The default behavior is to re-raise the last exception.
    #
    # @param _params [Hash] The parameters that caused the failure.
    # @param exception [Exception] The last exception that was caught.
    def exec_fallback(_params, exception)
      raise exception
    end
  end

  # A node that processes a batch of items sequentially.
  class BatchNode < Node
    protected

    def _exec(items)
      return [] if items.nil?
      items_array = items.is_a?(Array) ? items : [items]
      items_array.map { |item| super(item) }
    end
  end

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
      action_key = (action.nil? || action == "") ? "default" : action.to_s
      successor = current_node.successors[action_key]

      if !successor && !current_node.successors.empty?
        warn("Flow ends: action '#{action_key}' not found in successors: #{current_node.successors.keys.inspect}")
      end
      successor
    end
  end

  # A flow that processes a batch of items sequentially.
  class BatchFlow < Flow
    protected

    def _run(s)
      batch_params = prep(s) || []
      batch_params.each do |item_params|
        _orch(@params.merge(item_params))
      end
      post(s, batch_params, nil)
    end
  end

  # A node designed for asynchronous execution.
  class AsyncNode < Node
    # Runs the node asynchronously. Use with `AsyncFlow` to chain successors.
    def run_async(s)
      warn("Node won't run successors. Use AsyncFlow.") unless @successors.empty?
      _run_async(s)
    end

    def _run(_s)
      raise "Use run_async for AsyncNode."
    end

    protected

    def prep_async(_s); nil; end
    def exec_async(_p); nil; end
    def post_async(_s, _p, _e); nil; end

    def exec_fallback_async(p, exc)
      exec_fallback(p, exc)
    end

    def _exec_async(p)
      last_exception = nil
      @max_retries.times do |i|
        @current_retry = i
        begin
          return exec_async(p)
        rescue => e
          last_exception = e
          sleep @wait if @wait.positive? && i < @max_retries - 1
        end
      end
      exec_fallback_async(p, last_exception)
    end

    def _run_async(s)
      prepared_params = prep_async(s)
      actual_params = prepared_params || @params
      result = _exec_async(actual_params)
      post_async(s, actual_params, result)
      result
    end
  end

  # An async node that processes a batch of items sequentially.
  class AsyncBatchNode < AsyncNode
    protected

    def _exec_async(items)
      return [] if items.nil?
      items_array = items.is_a?(Array) ? items : [items]
      items_array.map { |item| super(item) }
    end
  end

  # An async node that processes a batch of items in parallel using threads.
  class AsyncParallelBatchNode < AsyncNode
    protected

    # @note This uses standard Ruby threads and is subject to the Global VM Lock (GVL).
    # It is best suited for I/O-bound tasks, not for parallelizing CPU-bound work.
    def _exec_async(items)
      return [] if items.nil?
      items_array = items.is_a?(Array) ? items : [items]
      threads = items_array.map { |item| Thread.new { super(item) } }
      threads.map(&:value)
    end
  end

  # A flow that can orchestrate both synchronous and asynchronous nodes.
  class AsyncFlow < Flow
    def run(s); run_async(s); end

    def run_async(s)
      _run_async(s)
    end

    def _run(_s)
      raise "Use run_async for AsyncFlow."
    end

    protected

    def prep_async(_s); nil; end
    def post_async(_s, _p, _e); nil; end

    def _run_async(s)
      prepared_params = prep_async(s)
      result = _orch_async(s, params: prepared_params || @params)
      post_async(s, prepared_params, result)
      result
    end

    # @note Asynchronous operations use Ruby threads and are subject to the GVL.
    # This is best suited for I/O-bound tasks, not CPU-bound parallel processing.
    def _orch_async(state, params: nil)
      raise "Flow has no start node" unless @start_node

      current_node = @start_node.dup
      flow_params = params ? params.dup : @params.dup
      last_result = nil

      while current_node
        current_node.set_params(flow_params)
        last_result = if current_node.is_a?(AsyncNode)
                        current_node.send(:_run_async, state)
                      else
                        current_node._run(state)
                      end
        current_node = get_next_node(current_node, last_result)&.dup
      end
      last_result
    end
  end

  # An async flow that processes a batch of items sequentially.
  class AsyncBatchFlow < AsyncFlow
    protected

    def _run_async(s)
      batch_params = prep_async(s) || []
      batch_params.each do |item_params|
        _orch_async(s, params: @params.merge(item_params))
      end
      post_async(s, batch_params, nil)
    end
  end

  # An async flow that processes a batch of items in parallel using threads.
  class AsyncParallelBatchFlow < AsyncFlow
    protected

    def _run_async(s)
      batch_params = prep_async(s) || []
      threads = batch_params.map do |item_params|
        Thread.new { _orch_async(s, params: @params.merge(item_params)) }
      end
      threads.map(&:value)
      post_async(s, batch_params, nil)
    end
  end
end
