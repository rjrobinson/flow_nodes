# frozen_string_literal: true

module FlowNodes
  # A node that processes a batch of items sequentially.
  class BatchNode < Node
    protected

    def _exec(items)
      Array(items).map { |item| super(item) }
    end
  end
end
