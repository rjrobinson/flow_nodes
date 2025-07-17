# frozen_string_literal: true

module FlowNodes
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
end
