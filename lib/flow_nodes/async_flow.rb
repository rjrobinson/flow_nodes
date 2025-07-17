# frozen_string_literal: true

module FlowNodes
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
      result = _orch_async(s, params: prepared_params)
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
                        current_node._run_async(state)
                      else
                        current_node._run(state)
                      end
        current_node = get_next_node(current_node, last_result)&.dup
      end
      last_result
    end
  end
end
