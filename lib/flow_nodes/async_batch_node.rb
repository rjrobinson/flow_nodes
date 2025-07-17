# frozen_string_literal: true

module FlowNodes
  # An async node that processes a batch of items sequentially.
  class AsyncBatchNode < AsyncNode
    protected

    def _exec_async(items)
      return [] if items.nil?
      items_array = items.is_a?(Array) ? items : [items]
      items_array.map { |item| super(item) }
    end
  end
end
