# frozen_string_literal: true

module FlowNodes
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
      result = _exec_async(prepared_params)
      post_async(s, prepared_params, result)
      result
    end
  end
end
