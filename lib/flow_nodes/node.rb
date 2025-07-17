# frozen_string_literal: true

module FlowNodes
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
end
