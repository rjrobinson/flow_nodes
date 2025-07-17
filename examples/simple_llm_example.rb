# frozen_string_literal: true

require_relative "../lib/flow_nodes"

# Simple LLM Integration Example
# This demonstrates the core patterns for LLM workflows with FlowNodes

module SimpleLLMExample
  # Mock LLM service
  class LLMService
    def self.process(text, operation)
      case operation
      when "summarize"
        "Summary: #{text.split('.').first}."
      when "classify"
        text.downcase.include?("error") ? "error_report" : "general_content"
      when "extract_keywords"
        text.scan(/\b\w{4,}\b/).uniq.first(3).join(", ")
      else
        "Processed: #{text}"
      end
    end
  end

  class TextInputNode < FlowNodes::Node
    def exec(params)
      puts "📄 Processing text input..."
      
      # Simulate getting text from params
      text = params[:text] || "This is a sample document about productivity tools. Error handling is important."
      
      puts "📝 Text received: #{text[0..50]}..."
      
      # Return text for next node
      text
    end
  end

  class LLMProcessorNode < FlowNodes::Node
    def initialize(operation: "summarize")
      super()
      @operation = operation
    end

    def exec(text)
      puts "🤖 Processing with LLM operation: #{@operation}"
      
      # Call LLM service
      result = LLMService.process(text, @operation)
      
      puts "✅ LLM processing completed"
      
      # Return result
      result
    end
  end

  class OutputNode < FlowNodes::Node
    def exec(result)
      puts "📤 Delivering result:"
      puts "Result: #{result}"
      
      nil # End flow
    end
  end

  # Conditional node that routes based on classification
  class ClassificationRouterNode < FlowNodes::Node
    def exec(text)
      puts "🔍 Classifying content..."
      
      classification = LLMService.process(text, "classify")
      
      puts "📋 Classification: #{classification}"
      
      # Return symbol for routing
      classification.to_sym
    end
  end

  class ErrorHandlerNode < FlowNodes::Node
    def exec(text)
      puts "🚨 Handling error content..."
      puts "Error analysis: #{text[0..100]}"
      
      nil # End flow
    end
  end

  class GeneralProcessorNode < FlowNodes::Node
    def exec(text)
      puts "📊 Processing general content..."
      
      keywords = LLMService.process(text, "extract_keywords")
      summary = LLMService.process(text, "summarize")
      
      puts "Keywords: #{keywords}"
      puts "Summary: #{summary}"
      
      nil # End flow
    end
  end
end

# Demo showing different LLM workflow patterns
if $PROGRAM_NAME == __FILE__
  puts "🤖 SIMPLE LLM WORKFLOW EXAMPLES"
  puts "=" * 40

  # Example 1: Basic LLM Pipeline
  puts "\n📋 EXAMPLE 1: Basic LLM Processing"
  puts "-" * 30
  
  input_node = SimpleLLMExample::TextInputNode.new
  llm_processor = SimpleLLMExample::LLMProcessorNode.new(operation: "summarize")
  output_node = SimpleLLMExample::OutputNode.new

  # Connect nodes
  input_node >> llm_processor >> output_node

  # Create and run flow
  flow = FlowNodes::Flow.new(start: input_node)
  flow.set_params(text: "This is a comprehensive document about artificial intelligence and machine learning applications. The technology shows great promise for automation.")
  flow.run(nil)

  # Example 2: Conditional LLM Routing
  puts "\n📋 EXAMPLE 2: Conditional LLM Routing"
  puts "-" * 30
  
  input_node = SimpleLLMExample::TextInputNode.new
  classifier = SimpleLLMExample::ClassificationRouterNode.new
  error_handler = SimpleLLMExample::ErrorHandlerNode.new
  general_processor = SimpleLLMExample::GeneralProcessorNode.new

  # Connect with conditional routing
  input_node >> classifier
  classifier - :error_report >> error_handler
  classifier - :general_content >> general_processor

  # Test with error content
  flow = FlowNodes::Flow.new(start: input_node)
  flow.set_params(text: "System error occurred during processing. Database connection failed.")
  flow.run(nil)

  # Test with general content
  flow.set_params(text: "Today's productivity tips focus on time management and workflow optimization.")
  flow.run(nil)

  # Example 3: Multi-step LLM Processing
  puts "\n📋 EXAMPLE 3: Multi-step LLM Processing"
  puts "-" * 30
  
  input_node = SimpleLLMExample::TextInputNode.new
  summarizer = SimpleLLMExample::LLMProcessorNode.new(operation: "summarize")
  keyword_extractor = SimpleLLMExample::LLMProcessorNode.new(operation: "extract_keywords")
  output_node = SimpleLLMExample::OutputNode.new

  # Chain multiple LLM operations
  input_node >> summarizer >> keyword_extractor >> output_node

  flow = FlowNodes::Flow.new(start: input_node)
  flow.set_params(text: "Artificial intelligence and machine learning are transforming modern business operations. Companies are investing heavily in automation technologies to improve efficiency and reduce costs.")
  flow.run(nil)

  puts "\n🎯 All LLM workflow examples completed!"
end