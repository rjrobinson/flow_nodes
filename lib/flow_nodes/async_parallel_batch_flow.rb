# frozen_string_literal: true

module FlowNodes
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
