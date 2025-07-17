# frozen_string_literal: true

module FlowNodes
  # An async node that processes a batch of items in parallel using threads.
  class AsyncParallelBatchNode < AsyncNode
    protected

    # @note This uses standard Ruby threads and is subject to the Global VM Lock (GVL).
    # It is best suited for I/O-bound tasks, not for parallelizing CPU-bound work.
    def _exec_async(items)
      return [] if items.nil?
      items_array = items.is_a?(Array) ? items : [items]
      threads = items_array.map { |item| Thread.new { super(item) } }
      threads.map(&:value)
    end
  end
end
