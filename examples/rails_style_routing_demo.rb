# frozen_string_literal: true

require_relative "../lib/flow_nodes"

# Rails-Style Routing Demo
# This example demonstrates the new FlowRoute DSL that provides Rails-like routing configuration

module RailsStyleRoutingDemo
  # Sample nodes for demonstration
  class IntentClassifierNode < FlowNodes::Node
    def exec(params)
      message = params[:message].downcase
      
      puts "🔍 [Intent Classifier] Analyzing: '#{params[:message]}'"
      
      case message
      when /billing|payment|invoice/ then :billing
      when /technical|bug|error/ then :technical  
      when /general|help|question/ then :general
      when /urgent|emergency/ then :escalate
      else :unknown
      end
    end
  end

  class KnowledgeBaseNode < FlowNodes::Node
    def exec(params)
      puts "📚 [Knowledge Base] Searching for relevant information..."
      puts "📖 Found 3 relevant articles"
      nil
    end
    
    def post(state, params, result)
      params[:kb_results] = ["How-to Guide", "FAQ Article", "Troubleshooting Steps"]
    end
  end

  class ResponseGeneratorNode < FlowNodes::Node
    def exec(params)
      puts "✍️  [Response Generator] Creating response..."
      puts "📄 Generated personalized response based on:"
      params[:kb_results]&.each { |article| puts "   - #{article}" }
      nil
    end
  end

  class EscalationHandlerNode < FlowNodes::Node
    def exec(params)
      puts "🚨 [Escalation] Connecting to human agent..."
      puts "📞 Agent will contact you within 5 minutes"
      nil
    end
  end

  class FallbackHandlerNode < FlowNodes::Node
    def exec(params)
      puts "🤔 [Fallback] Providing general assistance..."
      puts "💬 Please contact support for specialized help"
      nil
    end
  end
end

if $PROGRAM_NAME == __FILE__
  puts "🛤️  RAILS-STYLE FLOWROUTE DEMONSTRATION"
  puts "=" * 50

  # Create node instances
  puts "\n🏗️  Creating node instances..."
  intent_classifier = RailsStyleRoutingDemo::IntentClassifierNode.new
  knowledge_base = RailsStyleRoutingDemo::KnowledgeBaseNode.new  
  response_generator = RailsStyleRoutingDemo::ResponseGeneratorNode.new
  escalation_handler = RailsStyleRoutingDemo::EscalationHandlerNode.new
  fallback_handler = RailsStyleRoutingDemo::FallbackHandlerNode.new

  # Create node registry (maps route names to actual instances)
  node_registry = {
    intent_classifier: intent_classifier,
    knowledge_base: knowledge_base,
    response_generator: response_generator,
    escalation_handler: escalation_handler,
    fallback_handler: fallback_handler
  }

  puts "✅ Nodes created successfully"

  # Load routes using the new DSL (inline definition for demo)
  puts "\n📋 Loading routes configuration..."
  routes_config = FlowNodes::FlowRoute.draw do
    node :intent_classifier do
      # DRY routing - multiple conditions to same target
      route [:technical, :billing, :general], to: knowledge_base >> response_generator
      
      # Single condition routes
      route :escalate, to: escalation_handler
      route :unknown, to: fallback_handler
    end
  end

  puts "📊 Routes loaded:"
  routes_config.each do |node_name, routes|
    puts "   #{node_name}:"
    routes.each do |route|
      conditions = route[:conditions].join(', ')
      puts "     [#{conditions}] → #{route[:target].class.name}"
    end
  end

  # Apply routes to actual node instances
  puts "\n🔧 Applying routes to nodes..."
  FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
  puts "✅ Routes applied successfully"

  # Test the routing system
  test_messages = [
    "I have a technical issue with login",
    "My billing statement looks wrong", 
    "I need general help with features",
    "This is urgent - system is down!",
    "Can you help me with something weird?"
  ]

  puts "\n🧪 TESTING RAILS-STYLE ROUTING"
  puts "-" * 40

  test_messages.each_with_index do |message, index|
    puts "\n📨 Test #{index + 1}: '#{message}'"
    puts "   " + "─" * 40
    
    flow = FlowNodes::Flow.new(start: intent_classifier)
    flow.set_params(message: message)
    flow.run(nil)
  end

  puts "\n" + "=" * 50
  puts "🎯 BENEFITS OF RAILS-STYLE ROUTING"
  puts "-" * 40
  puts "✅ Centralized Configuration: All routing in one place"
  puts "✅ Rails Familiarity: Ruby developers know this pattern"
  puts "✅ Separation of Concerns: Routes separate from node logic"
  puts "✅ Declarative Style: Intent is clear from configuration"
  puts "✅ Namespace Support: Organize complex applications"
  puts "✅ Resource Routing: CRUD patterns built-in"
  puts "✅ Conditional Logic: Advanced routing capabilities"
  puts "✅ File-Based Config: Load routes from external files"

  puts "\n🚀 This is much more '2025 Ruby' than the previous approach!"
end