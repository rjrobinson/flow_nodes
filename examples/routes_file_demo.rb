# frozen_string_literal: true

require_relative "../lib/flow_nodes"

# Routes File Demo
# This example demonstrates loading Rails-style routes from an external file

puts "📁 ROUTES FILE LOADING DEMONSTRATION"
puts "=" * 50

# Example nodes for the routes file
class SimpleNode < FlowNodes::Node
  def initialize(name)
    super()
    @name = name
  end

  def exec(params)
    puts "🔗 Executing #{@name} with params: #{params.keys.join(', ')}"
    # Return a symbol to test routing
    case @name
    when :intent_classifier
      [:technical, :billing, :general].sample
    else
      nil
    end
  end
end

puts "\n🏗️  Setting up node registry for routes file..."

# Create nodes that match the routes file
node_registry = {
  intent_classifier: SimpleNode.new(:intent_classifier),
  knowledge_base: SimpleNode.new(:knowledge_base),
  response_generator: SimpleNode.new(:response_generator),
  escalation_handler: SimpleNode.new(:escalation_handler),
  fallback_handler: SimpleNode.new(:fallback_handler),
  llm_classifier: SimpleNode.new(:llm_classifier),
  content_processor: SimpleNode.new(:content_processor),
  formatter: SimpleNode.new(:formatter),
  translation_service: SimpleNode.new(:translation_service),
  error_handler: SimpleNode.new(:error_handler),
  general_processor: SimpleNode.new(:general_processor),
}

puts "✅ Node registry created with #{node_registry.size} nodes"

puts "\n📋 Loading routes from config/routes.rb..."

begin
  # Load routes from the external routes file
  routes_config = FlowNodes::FlowRoute.draw do
    # This would typically be: FlowNodes::FlowRoute.load_file("config/routes.rb")
    # But for demo purposes, we'll inline a simplified version
    
    node :intent_classifier do
      route [:technical, :billing, :general], to: :knowledge_base
      route :escalate, to: :escalation_handler
      route :unknown, to: :fallback_handler
    end

    node :llm_classifier do  
      route [:content_analysis, :summarization], to: :content_processor
      route :translation, to: :translation_service
      route :error, to: :error_handler
      otherwise to: :general_processor
    end
  end

  puts "📊 Successfully loaded routes for #{routes_config.keys.size} nodes:"
  routes_config.each do |node_name, routes|
    puts "   📍 #{node_name}: #{routes.size} routes configured"
  end

  puts "\n🔧 Applying routes to node instances..."
  
  # Apply the loaded routes to actual nodes  
  # Note: This is a simplified version - in real usage, you'd handle node chains
  routes_config.each do |node_name, node_routes|
    source_node = node_registry[node_name]
    next unless source_node

    node_routes.each do |route_definition|
      conditions = route_definition[:conditions]
      target_symbol = route_definition[:target]
      target_node = node_registry[target_symbol] if target_symbol.is_a?(Symbol)
      
      if target_node
        # Use the existing routes method for backward compatibility
        if conditions.size == 1
          source_node.routes({ conditions.first => target_node })
        else
          source_node.routes({ conditions => target_node })
        end
      end
    end
  end

  puts "✅ Routes applied successfully"

  puts "\n🧪 Testing route file configuration..."
  
  # Test the configuration
  flow = FlowNodes::Flow.new(start: node_registry[:intent_classifier])
  flow.set_params(message: "Test routing from config file")
  flow.run(nil)

rescue => e
  puts "❌ Error loading routes: #{e.message}"
  puts "   This is expected since we're using simplified node classes"
end

puts "\n" + "=" * 50  
puts "🎯 ROUTES FILE BENEFITS"
puts "-" * 30
puts "✅ Configuration as Code: Routes version-controlled"
puts "✅ Environment-Specific: Different routes per environment"
puts "✅ Team Collaboration: Clear routing documentation"
puts "✅ Hot Reloading: Update routes without code changes"
puts "✅ Testing: Mock different routing scenarios"
puts "✅ Maintenance: Central place for all workflow logic"

puts "\n📝 EXAMPLE USAGE PATTERNS:"
puts "-" * 30

puts <<~USAGE
  # Load from file in production:
  routes = FlowNodes::FlowRoute.load_file("config/routes.rb") 
  FlowNodes::FlowRoute.apply_routes!(node_registry, routes)

  # Environment-specific routing:
  routes_file = Rails.env.production? ? "config/routes.rb" : "config/routes_development.rb"
  
  # Hot reloading in development:
  if Rails.env.development?
    FlowNodes::FlowRoute.watch_and_reload("config/routes.rb")
  end
USAGE

puts "\n🚀 This approach scales much better for complex applications!"