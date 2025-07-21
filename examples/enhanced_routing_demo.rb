# frozen_string_literal: true

require_relative "../lib/flow_nodes"

# Enhanced Routing DSL Demo
# This example demonstrates the new routes() method that eliminates repetitive routing syntax

module EnhancedRoutingDemo
  # Customer support classifier that routes to different handlers
  class IntentClassifierNode < FlowNodes::Node
    def exec(params)
      message = params[:message].downcase
      
      puts "🔍 Classifying message: '#{params[:message]}'"
      
      # Simple keyword-based classification
      case message
      when /billing|payment|invoice|charge/
        puts "📋 Classification: billing"
        :billing
      when /technical|bug|error|crash/
        puts "📋 Classification: technical"
        :technical  
      when /general|help|question/
        puts "📋 Classification: general"
        :general
      when /cancel|refund|urgent/
        puts "📋 Classification: escalate"
        :escalate
      else
        puts "📋 Classification: unknown"
        :unknown
      end
    end
  end

  class KnowledgeBaseNode < FlowNodes::Node
    def exec(params)
      puts "📚 Searching knowledge base query..."
      puts "📖 Found relevant articles"
      
      # Return nil to use default transition (since we're using >>)
      nil
    end
    
    def post(state, params, result)
      # Add kb_results to params for next node
      params[:kb_results] = ["Article 1: How to solve common issues", "Article 2: Troubleshooting guide"]
    end
  end

  class ResponseGeneratorNode < FlowNodes::Node
    def exec(params)
      puts "✍️  Generating response based on knowledge base results..."
      puts "📤 Response: Here's what I found to help with your question:"
      
      if params[:kb_results]
        params[:kb_results].each_with_index do |article, index|
          puts "   #{index + 1}. #{article}"
        end
      else
        puts "   I found some helpful information for you."
      end
      
      puts "   Is this helpful? Let me know if you need more assistance!"
      
      nil # End flow
    end
  end

  class EscalationNode < FlowNodes::Node
    def exec(params)
      puts "🚨 Escalating to human agent..."
      puts "📞 Connecting you with a specialist who can help with: #{params[:message]}"
      puts "⏳ Estimated wait time: 2-5 minutes"
      
      nil # End flow
    end
  end

  class FallbackNode < FlowNodes::Node
    def exec(params)
      puts "🤔 I'm not sure how to help with that specific request."
      puts "💬 Could you please rephrase your question or contact our support team directly?"
      puts "📧 Support email: help@example.com"
      
      nil # End flow
    end
  end
end

# Demo showing the difference between old and new routing syntax
if $PROGRAM_NAME == __FILE__
  puts "🚀 ENHANCED ROUTING DSL DEMONSTRATION"
  puts "=" * 50

  # Sample customer messages
  test_messages = [
    "I have a billing question about my invoice",
    "The app is crashing when I try to login", 
    "Can you help me with general information?",
    "I want to cancel my subscription immediately",
    "How do I reset my password?"
  ]

  puts "\n📋 EXAMPLE 1: OLD REPETITIVE SYNTAX"
  puts "-" * 40

  # Create nodes
  old_classifier = EnhancedRoutingDemo::IntentClassifierNode.new
  old_kb = EnhancedRoutingDemo::KnowledgeBaseNode.new
  old_responder = EnhancedRoutingDemo::ResponseGeneratorNode.new
  old_escalator = EnhancedRoutingDemo::EscalationNode.new
  old_fallback = EnhancedRoutingDemo::FallbackNode.new

  # OLD SYNTAX - Repetitive and verbose
  puts "🔧 Setting up routing (old way - repetitive):"
  puts "   classifier - :technical >> knowledge_base >> responder"
  puts "   classifier - :billing >> knowledge_base >> responder"  
  puts "   classifier - :general >> knowledge_base >> responder"
  puts "   classifier - :escalate >> escalator"
  puts "   classifier - :unknown >> fallback"
  
  old_classifier - :technical >> old_kb >> old_responder
  old_classifier - :billing >> old_kb >> old_responder
  old_classifier - :general >> old_kb >> old_responder
  old_classifier - :escalate >> old_escalator
  old_classifier - :unknown >> old_fallback

  # Test with billing question
  puts "\n🧪 Testing with: '#{test_messages[0]}'"
  old_flow = FlowNodes::Flow.new(start: old_classifier)
  old_flow.set_params(message: test_messages[0])
  old_flow.run(nil)

  puts "\n" + "=" * 50
  puts "\n📋 EXAMPLE 2: NEW ENHANCED ROUTING DSL"
  puts "-" * 40

  # Create nodes
  new_classifier = EnhancedRoutingDemo::IntentClassifierNode.new
  new_kb = EnhancedRoutingDemo::KnowledgeBaseNode.new
  new_responder = EnhancedRoutingDemo::ResponseGeneratorNode.new
  new_escalator = EnhancedRoutingDemo::EscalationNode.new
  new_fallback = EnhancedRoutingDemo::FallbackNode.new

  # NEW SYNTAX - Clean and readable
  puts "🔧 Setting up routing (new way - clean & DRY):"
  puts "   classifier.routes("
  puts "     [:technical, :billing, :general] => knowledge_base >> responder,"
  puts "     :escalate => escalator,"
  puts "     :unknown => fallback"
  puts "   )"
  
  new_classifier.routes(
    [:technical, :billing, :general] => new_kb >> new_responder,
    :escalate => new_escalator,
    :unknown => new_fallback
  )

  # Test with technical question
  puts "\n🧪 Testing with: '#{test_messages[1]}'"
  new_flow = FlowNodes::Flow.new(start: new_classifier)
  new_flow.set_params(message: test_messages[1])
  new_flow.run(nil)

  puts "\n" + "=" * 50
  puts "\n📋 EXAMPLE 3: BACKWARDS COMPATIBILITY"
  puts "-" * 40

  # Show that both syntaxes can be mixed
  mixed_classifier = EnhancedRoutingDemo::IntentClassifierNode.new
  mixed_kb = EnhancedRoutingDemo::KnowledgeBaseNode.new
  mixed_responder = EnhancedRoutingDemo::ResponseGeneratorNode.new
  mixed_escalator = EnhancedRoutingDemo::EscalationNode.new
  mixed_fallback = EnhancedRoutingDemo::FallbackNode.new

  puts "🔧 Mixing old and new syntax (backwards compatible):"
  puts "   # Old syntax for some routes"
  puts "   classifier - :escalate >> escalator"
  puts "   # New syntax for others"
  puts "   classifier.routes([:technical, :billing] => kb >> responder)"
  
  # Mix old and new syntax
  mixed_classifier - :escalate >> mixed_escalator  # Old syntax
  mixed_classifier.routes(                          # New syntax
    [:technical, :billing, :general] => mixed_kb >> mixed_responder,
    :unknown => mixed_fallback
  )

  # Test with escalation
  puts "\n🧪 Testing with: '#{test_messages[3]}'"
  mixed_flow = FlowNodes::Flow.new(start: mixed_classifier)
  mixed_flow.set_params(message: test_messages[3])
  mixed_flow.run(nil)

  puts "\n" + "=" * 50
  puts "\n🎯 BENEFITS OF ENHANCED ROUTING DSL"
  puts "-" * 40
  
  puts "✅ DRY Principle: Eliminate repetitive routing syntax"
  puts "✅ Readability: See all routing logic in one clear block"
  puts "✅ Ruby Idioms: Familiar Hash-based configuration"
  puts "✅ Maintainability: Single place to define routing rules"
  puts "✅ Backwards Compatible: Works alongside existing syntax"
  puts "✅ Method Chaining: Returns self for fluent interfaces"
  puts "✅ Error Handling: Clear validation and helpful error messages"

  puts "\n🚀 The enhanced routing DSL makes FlowNodes more Ruby-native!"
  puts "   Perfect for complex LLM workflows with multiple routing paths."
end