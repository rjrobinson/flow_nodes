# frozen_string_literal: true

module FlowNodes
  # An async node that processes a batch of items sequentially.
  class AsyncBatchNode < AsyncNode
    protected

    def _exec_async(items)
      Array(items).map { |item| super(item) }
    end
  end
end
