# frozen_string_literal: true

module FlowNodes
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
end
