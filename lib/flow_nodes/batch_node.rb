# frozen_string_literal: true

module FlowNodes
  # A node that processes a batch of items sequentially.
  class BatchNode < Node
    protected

    def _exec(items)
      return [] if items.nil?
      items_array = items.is_a?(Array) ? items : [items]
      items_array.map { |item| super(item) }
    end
  end
end
