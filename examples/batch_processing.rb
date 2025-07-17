# frozen_string_literal: true

require_relative "../lib/flow_nodes"

module BatchDemo
  class DataTransformNode < FlowNodes::BatchNode
    def exec(item)
      puts "Processing item: #{item}"
      # Simulate some processing time
      sleep(0.01)
      
      # Transform the data
      {
        original: item,
        processed: item.to_s.upcase,
        timestamp: Time.now
      }
    end
  end

  class AsyncDataTransformNode < FlowNodes::AsyncBatchNode
    def exec_async(item)
      puts "Async processing item: #{item}"
      # Simulate async processing time
      sleep(0.01)
      
      # Transform the data
      {
        original: item,
        processed: item.to_s.upcase,
        timestamp: Time.now,
        thread_id: Thread.current.object_id
      }
    end
  end

  class ParallelDataTransformNode < FlowNodes::AsyncParallelBatchNode
    def exec_async(item)
      puts "Parallel processing item: #{item} on thread #{Thread.current.object_id}"
      # Simulate processing time
      sleep(0.1)
      
      # Transform the data
      {
        original: item,
        processed: item.to_s.upcase,
        timestamp: Time.now,
        thread_id: Thread.current.object_id
      }
    end
  end

  class BatchCollectorFlow < FlowNodes::BatchFlow
    def prep(state)
      state[:results] = []
      [1, 2, 3, 4, 5] # Return batch items
    end

    def post(state, prep_result, exec_result)
      puts "Batch processing completed!"
      puts "Results stored in state: #{state[:results].length} items"
    end
  end

  class ResultCollectorNode < FlowNodes::Node
    def exec(processed_item)
      puts "Collecting result: #{processed_item}"
      nil # End the flow for each item
    end
  end
end

# Demo script
if $PROGRAM_NAME == __FILE__
  puts "=== Sequential Batch Processing ==="
  transformer = BatchDemo::DataTransformNode.new
  transformer.set_params([1, 2, 3, 4, 5])
  results = transformer.run(nil)
  puts "Sequential results: #{results}"

  puts "\n=== Async Sequential Batch Processing ==="
  async_transformer = BatchDemo::AsyncDataTransformNode.new
  async_transformer.set_params([1, 2, 3, 4, 5])
  start_time = Time.now
  results = async_transformer.run_async(nil)
  end_time = Time.now
  puts "Async sequential results: #{results}"
  puts "Time taken: #{end_time - start_time} seconds"

  puts "\n=== Parallel Batch Processing ==="
  parallel_transformer = BatchDemo::ParallelDataTransformNode.new
  parallel_transformer.set_params([1, 2, 3, 4, 5])
  start_time = Time.now
  results = parallel_transformer.run_async(nil)
  end_time = Time.now
  puts "Parallel results: #{results}"
  puts "Time taken: #{end_time - start_time} seconds"
  puts "Notice different thread IDs showing parallel execution"

  puts "\n=== Batch Flow Example ==="
  transformer = BatchDemo::DataTransformNode.new
  collector = BatchDemo::ResultCollectorNode.new
  
  transformer >> collector
  
  flow = BatchDemo::BatchCollectorFlow.new(start: transformer)
  flow.run({ results: [] })
end