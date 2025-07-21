# FlowRoute: Rails-Style Routing for FlowNodes

**Version:** 1.0.0  
**Author:** FlowNodes Team  
**Last Updated:** July 2025

FlowRoute brings Rails-style routing configuration to FlowNodes, providing a familiar, declarative way to define complex workflow routing patterns. Perfect for LLM orchestration, business process automation, and any scenario requiring sophisticated flow control.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Concepts](#core-concepts)
3. [Basic Usage](#basic-usage)
4. [Advanced Features](#advanced-features)
5. [Rails Integration](#rails-integration)
6. [Sinatra Integration](#sinatra-integration)
7. [LLM Orchestration Patterns](#llm-orchestration-patterns)
8. [Performance & Best Practices](#performance--best-practices)
9. [API Reference](#api-reference)
10. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Installation

Add FlowNodes to your Gemfile:

```ruby
gem 'flow_nodes'
```

Or install directly:

```bash
gem install flow_nodes
```

### Basic Example

```ruby
require 'flow_nodes'

# Define your workflow nodes
classifier = ClassificationNode.new
handler = ProcessingNode.new
responder = ResponseNode.new

# Configure routing with FlowRoute
FlowNodes::FlowRoute.draw do
  node :classifier do
    route [:success, :partial], to: handler >> responder
    route :error, to: error_handler
    otherwise to: fallback_handler
  end
end

# Execute workflow
flow = FlowNodes::Flow.new(start: classifier)
flow.set_params(input: "Process this content")
result = flow.run(nil)
```

---

## Core Concepts

### Routes File Approach

FlowRoute uses a Rails-inspired routes file pattern that separates routing configuration from business logic:

- **Centralized Configuration**: All routing logic in one place
- **Environment-Specific**: Different routes per environment
- **Version Control Friendly**: Routes are code, tracked in git
- **Team Collaboration**: Clear visibility into workflow structure

### Node-Based Routing

Unlike traditional web routing, FlowRoute routes between workflow nodes:

```ruby
FlowNodes::FlowRoute.draw do
  node :content_processor do
    route :text, to: text_handler
    route :image, to: image_handler >> text_extractor
    route :video, to: video_processor >> text_extractor
  end
end
```

### Routing Symbols

Nodes return symbols to indicate which route to take:

```ruby
class ContentProcessorNode < FlowNodes::Node
  def exec(params)
    content_type = detect_content_type(params[:input])
    case content_type
    when 'text' then :text
    when 'image' then :image
    when 'video' then :video
    else :unknown
    end
  end
end
```

---

## Basic Usage

### Single Condition Routing

Route specific conditions to target nodes:

```ruby
FlowNodes::FlowRoute.draw do
  node :classifier do
    route :approved, to: approval_handler
    route :rejected, to: rejection_handler
    route :pending, to: review_queue
  end
end
```

### Multiple Condition Routing (DRY)

Route multiple conditions to the same target:

```ruby
FlowNodes::FlowRoute.draw do
  node :content_classifier do
    # Multiple conditions → same handler (eliminates repetition)
    route [:blog_post, :article, :news], to: content_processor
    route [:image, :video], to: media_processor
    route :spam, to: spam_handler
  end
end
```

### Node Chaining

Chain multiple nodes in sequence:

```ruby
FlowNodes::FlowRoute.draw do
  node :input_validator do
    route :valid, to: processor >> analyzer >> responder
    route :invalid, to: error_handler
  end
end
```

### Default/Fallback Routing

Handle unexpected or default cases:

```ruby
FlowNodes::FlowRoute.draw do
  node :classifier do
    route :category_a, to: handler_a
    route :category_b, to: handler_b
    otherwise to: default_handler  # Fallback for any other result
  end
end
```

### Loading Routes from Files

#### Option 1: Inline Definition

```ruby
routes_config = FlowNodes::FlowRoute.draw do
  node :processor do
    route :success, to: success_handler
  end
end

FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
```

#### Option 2: External Routes File

Create `config/routes.rb`:

```ruby
FlowNodes::FlowRoute.draw do
  node :api_processor do
    route [:get, :post], to: request_handler
    route :websocket, to: websocket_handler
  end
  
  node :data_validator do
    route :valid, to: processor >> formatter
    route :invalid, to: validation_error_handler
  end
end
```

Load in your application:

```ruby
# Development
routes = FlowNodes::FlowRoute.load_file('config/routes.rb')
FlowNodes::FlowRoute.apply_routes!(node_registry, routes)

# Production with error handling
begin
  routes = FlowNodes::FlowRoute.load_file('config/routes_production.rb')
  FlowNodes::FlowRoute.apply_routes!(node_registry, routes)
rescue => e
  logger.error("Failed to load routes: #{e.message}")
  # Load fallback routes
end
```

---

## Advanced Features

### Conditional Routing

Route based on runtime conditions (planned feature):

```ruby
FlowNodes::FlowRoute.draw do
  node :user_processor do
    route :premium, to: premium_handler, if: -> { |params| params[:user_type] == 'premium' }
    route :basic, to: basic_handler
  end
end
```

### Namespace Organization

Organize complex applications with namespaces:

```ruby
FlowNodes::FlowRoute.draw do
  namespace :api do
    node :v1_processor do
      route :users, to: user_handler
      route :orders, to: order_handler
    end
    
    node :v2_processor do
      route :users, to: v2_user_handler
      route :orders, to: v2_order_handler
    end
  end
  
  namespace :admin do
    node :admin_processor do
      route :users, to: admin_user_handler
      route :reports, to: report_generator
    end
  end
end
```

### Resource-Style Routing

CRUD-style routing patterns:

```ruby
FlowNodes::FlowRoute.draw do
  resources :document_manager,
    create: document_creator,
    read: document_reader,
    update: document_updater,
    delete: document_deleter
    
  resources :user_manager,
    create: user_creator >> email_notifier,
    read: user_reader,
    update: user_updater >> audit_logger,
    delete: user_deleter >> cleanup_handler
end
```

### Environment-Specific Routing

Different routes per environment:

```ruby
# config/routes_development.rb
FlowNodes::FlowRoute.draw do
  node :logger do
    route :debug, to: console_logger
    route :info, to: console_logger
  end
end

# config/routes_production.rb  
FlowNodes::FlowRoute.draw do
  node :logger do
    route :debug, to: null_handler  # Skip debug in production
    route :info, to: structured_logger >> log_aggregator
  end
end
```

---

## Rails Integration

### Setup in Rails Application

#### 1. Add to Gemfile

```ruby
gem 'flow_nodes'
```

#### 2. Create Initializer

Create `config/initializers/flow_nodes.rb`:

```ruby
Rails.application.configure do
  # Load FlowNodes configuration
  config.after_initialize do
    FlowNodesConfig.setup!
  end
end

class FlowNodesConfig
  def self.setup!
    # Load environment-specific routes
    routes_file = Rails.root.join('config', 'flow_routes.rb')
    routes_file = Rails.root.join('config', "flow_routes_#{Rails.env}.rb") if File.exist?(Rails.root.join('config', "flow_routes_#{Rails.env}.rb"))
    
    if File.exist?(routes_file)
      routes_config = FlowNodes::FlowRoute.load_file(routes_file.to_s)
      
      # Create global node registry
      node_registry = create_node_registry
      
      # Apply routes
      FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
      
      # Cache for use in controllers
      Rails.cache.write('flow_nodes_registry', node_registry, expires_in: 1.hour)
    end
    
    Rails.logger.info "FlowNodes initialized successfully"
  end
  
  private
  
  def self.create_node_registry
    {
      content_classifier: LLM::ContentClassifierNode.new,
      sentiment_analyzer: LLM::SentimentAnalyzerNode.new,
      response_generator: LLM::ResponseGeneratorNode.new,
      # Add your nodes here
    }
  end
end
```

#### 3. Create Routes File

Create `config/flow_routes.rb`:

```ruby
FlowNodes::FlowRoute.draw do
  # Customer support workflow
  node :content_classifier do
    route [:question, :help], to: knowledge_base >> response_generator
    route [:complaint, :issue], to: sentiment_analyzer >> escalation_handler
    route :spam, to: spam_handler
    otherwise to: general_handler
  end
  
  # LLM processing pipeline
  node :llm_router do
    route :text_analysis, to: text_processor >> result_formatter
    route :image_analysis, to: image_processor >> text_processor >> result_formatter
    route :bulk_processing, to: batch_processor
  end
end
```

#### 4. Controller Integration

```ruby
class LLMController < ApplicationController
  def process_content
    content = params[:content]
    user_id = params[:user_id]
    
    # Get node registry from Rails cache
    nodes = Rails.cache.fetch('flow_nodes_registry')
    classifier = nodes[:content_classifier]
    
    # Execute workflow
    flow = FlowNodes::Flow.new(start: classifier)
    flow.set_params(
      content: content,
      user_id: user_id,
      request_id: request.uuid
    )
    
    result = flow.run(nil)
    
    render json: {
      success: true,
      result: extract_result(flow.params),
      processed_at: Time.current.iso8601
    }
    
  rescue => e
    Rails.logger.error("FlowNodes processing failed: #{e.message}")
    render json: { error: "Processing failed" }, status: 500
  end
  
  private
  
  def extract_result(params)
    {
      classification: params[:classification],
      sentiment: params[:sentiment],
      response: params[:generated_response],
      confidence: params[:confidence]
    }
  end
end
```

#### 5. Background Job Integration

```ruby
class FlowProcessingJob < ApplicationJob
  queue_as :llm_processing
  
  def perform(content_id, workflow_type)
    content = Content.find(content_id)
    nodes = Rails.cache.fetch('flow_nodes_registry')
    
    case workflow_type
    when 'customer_support'
      classifier = nodes[:content_classifier]
    when 'content_analysis'
      classifier = nodes[:content_analyzer]
    else
      raise "Unknown workflow: #{workflow_type}"
    end
    
    flow = FlowNodes::Flow.new(start: classifier)
    flow.set_params(
      content: content.body,
      content_id: content_id,
      user_id: content.user_id
    )
    
    flow.run(nil)
    
    # Save results
    content.update!(
      processed_at: Time.current,
      classification: flow.params[:classification],
      sentiment: flow.params[:sentiment],
      processing_result: flow.params.slice(:confidence, :generated_response)
    )
    
    # Trigger notifications, webhooks, etc.
    NotificationService.notify_completion(content, flow.params)
  end
end
```

### Rails-Specific Features

- **ActiveRecord Integration**: Seamless database operations
- **Rails Caching**: Intelligent caching of expensive operations
- **Background Jobs**: Integration with Sidekiq, Resque, etc.
- **ActionController**: Direct controller integration
- **Rails Logging**: Structured logging with Rails logger
- **Environment Configuration**: Automatic environment detection

---

## Sinatra Integration

### Setup in Sinatra Application

#### 1. Basic Setup

```ruby
require 'sinatra'
require 'flow_nodes'

# Configure FlowNodes
configure do
  # Load routes
  routes_config = FlowNodes::FlowRoute.draw do
    node :api_processor do
      route :success, to: success_handler
      route :error, to: error_handler
    end
  end
  
  # Create node registry
  node_registry = {
    api_processor: APIProcessorNode.new,
    success_handler: SuccessHandlerNode.new,
    error_handler: ErrorHandlerNode.new
  }
  
  FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
  
  # Store for use in routes
  set :flow_nodes, node_registry
end
```

#### 2. Route Handlers

```ruby
post '/api/process' do
  content_type :json
  
  begin
    processor = settings.flow_nodes[:api_processor]
    
    flow = FlowNodes::Flow.new(start: processor)
    flow.set_params(
      input: params[:content],
      user_id: params[:user_id],
      ip_address: request.ip
    )
    
    flow.run(nil)
    
    {
      success: true,
      result: flow.params[:result],
      processing_time: flow.params[:duration]
    }.to_json
    
  rescue => e
    logger.error("Processing failed: #{e.message}")
    status 500
    { error: "Processing failed" }.to_json
  end
end

# Streaming support
get '/api/stream' do
  content_type 'text/event-stream'
  
  stream do |out|
    processor = settings.flow_nodes[:streaming_processor]
    
    flow = FlowNodes::Flow.new(start: processor)
    flow.set_params(
      output_stream: out,
      query: params[:q]
    )
    
    flow.run(nil)
  end
end
```

#### 3. Middleware Integration

```ruby
# Rate limiting middleware
use Rack::Throttle::Hourly, max: 100

# Custom middleware for FlowNodes
class FlowNodesMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    
    # Add FlowNodes context to request
    env['flow_nodes.request_id'] = SecureRandom.uuid
    env['flow_nodes.start_time'] = Time.now
    
    status, headers, body = @app.call(env)
    
    # Log FlowNodes metrics
    duration = Time.now - env['flow_nodes.start_time']
    logger.info("FlowNodes request #{env['flow_nodes.request_id']} completed in #{duration}s")
    
    [status, headers, body]
  end
end

use FlowNodesMiddleware
```

### Sinatra-Specific Benefits

- **Lightweight**: Minimal overhead and fast startup
- **Streaming Support**: Real-time response generation  
- **Simple Deployment**: Single file applications
- **Middleware Stack**: Flexible request processing
- **Performance**: High throughput for API endpoints

---

## LLM Orchestration Patterns

### Pattern 1: Content Classification Pipeline

```ruby
FlowNodes::FlowRoute.draw do
  node :content_classifier do
    route :technical_question, to: tech_knowledge_base >> detailed_responder
    route :billing_inquiry, to: billing_knowledge_base >> billing_responder
    route :general_question, to: general_knowledge_base >> standard_responder
    route :complaint, to: sentiment_analyzer >> escalation_handler
    route :compliment, to: sentiment_analyzer >> thank_you_responder
  end
end
```

### Pattern 2: Multi-LLM Workflow

```ruby
FlowNodes::FlowRoute.draw do
  node :content_router do
    route :summarization, to: summarization_llm >> quality_checker
    route :translation, to: translation_llm >> quality_checker  
    route :code_generation, to: code_llm >> code_validator >> code_formatter
    route :creative_writing, to: creative_llm >> content_filter >> style_enhancer
  end
end
```

### Pattern 3: Adaptive LLM Selection

```ruby
FlowNodes::FlowRoute.draw do
  node :llm_selector do
    # Route to different LLMs based on content complexity
    route :simple, to: fast_llm >> result_formatter
    route :complex, to: advanced_llm >> quality_enhancer >> result_formatter
    route :creative, to: creative_llm >> style_checker >> result_formatter
    route :technical, to: specialist_llm >> accuracy_validator >> result_formatter
  end
end
```

### Pattern 4: Conversation Management

```ruby
FlowNodes::FlowRoute.draw do
  node :conversation_manager do
    route :new_conversation, to: context_initializer >> llm_responder
    route :continue_conversation, to: context_loader >> conversation_llm >> context_saver
    route :end_conversation, to: conversation_summarizer >> context_archiver
  end
end
```

### Pattern 5: Quality Assurance Pipeline

```ruby
FlowNodes::FlowRoute.draw do
  node :llm_processor do
    route :generated, to: quality_checker
  end
  
  node :quality_checker do
    route :high_quality, to: response_formatter
    route :medium_quality, to: enhancement_llm >> response_formatter
    route :low_quality, to: regeneration_llm >> quality_checker  # Recursive improvement
    route :unacceptable, to: fallback_response
  end
end
```

---

## Performance & Best Practices

### Performance Optimization

#### 1. Node Instance Reuse

```ruby
# ✅ Good: Reuse node instances
configure do
  classifier = ClassificationNode.new
  set :classifier_node, classifier
end

post '/classify' do
  flow = FlowNodes::Flow.new(start: settings.classifier_node)
  # ...
end

# ❌ Bad: Create new instances per request  
post '/classify' do
  classifier = ClassificationNode.new  # Expensive!
  flow = FlowNodes::Flow.new(start: classifier)
  # ...
end
```

#### 2. Route Compilation

```ruby
# ✅ Good: Load routes once at startup
configure do
  routes = FlowNodes::FlowRoute.draw { /* routes */ }
  FlowNodes::FlowRoute.apply_routes!(node_registry, routes)
end

# ❌ Bad: Reload routes per request
post '/process' do
  routes = FlowNodes::FlowRoute.draw { /* routes */ }  # Expensive!
  # ...
end
```

#### 3. Caching Strategies

```ruby
class LLMNode < FlowNodes::Node
  def exec(params)
    cache_key = generate_cache_key(params[:input])
    
    # Check cache first
    if cached = Rails.cache.read(cache_key)
      return cached[:result]
    end
    
    # Expensive LLM operation
    result = call_llm_api(params[:input])
    
    # Cache result
    Rails.cache.write(cache_key, { result: result }, expires_in: 1.hour)
    
    result
  end
end
```

### Memory Management

#### 1. Parameter Cleanup

```ruby
class ProcessingNode < FlowNodes::Node
  def exec(params)
    # Process large data
    result = process_large_dataset(params[:data])
    
    # Clean up large objects to prevent memory leaks
    params.delete(:data)  # Remove large input data
    params[:result] = result
    
    nil
  end
end
```

#### 2. Streaming for Large Responses

```ruby
class StreamingLLMNode < FlowNodes::Node
  def exec(params)
    if params[:stream]
      # Stream response chunk by chunk
      stream_llm_response(params[:input]) do |chunk|
        params[:output_stream] << chunk
      end
    else
      # Standard response
      params[:response] = generate_full_response(params[:input])
    end
    
    nil
  end
end
```

### Error Handling Best Practices

#### 1. Graceful Degradation

```ruby
FlowNodes::FlowRoute.draw do
  node :primary_llm do
    route :success, to: response_formatter
    route :error, to: fallback_llm >> response_formatter
    route :timeout, to: cached_response_handler
  end
end
```

#### 2. Retry Logic

```ruby
class ResilientLLMNode < FlowNodes::Node
  MAX_RETRIES = 3
  
  def exec(params)
    retries = 0
    
    begin
      result = call_llm_api(params[:input])
      params[:result] = result
      :success
    rescue => e
      retries += 1
      
      if retries <= MAX_RETRIES
        sleep(2 ** retries)  # Exponential backoff
        retry
      else
        params[:error] = e.message
        :error
      end
    end
  end
end
```

### Security Best Practices

#### 1. Input Validation

```ruby
class ValidatorNode < FlowNodes::Node
  def exec(params)
    input = params[:input]
    
    # Validate input
    return :invalid if input.nil? || input.empty?
    return :too_long if input.length > 10_000
    return :suspicious if contains_suspicious_content?(input)
    
    # Sanitize input
    params[:sanitized_input] = sanitize_input(input)
    :valid
  end
end
```

#### 2. Rate Limiting

```ruby
# In Sinatra
before do
  client_id = request.ip
  rate_limit_key = "rate_limit:#{client_id}"
  
  current_count = cache.get(rate_limit_key) || 0
  
  if current_count > 100  # 100 requests per hour
    halt 429, { error: "Rate limit exceeded" }.to_json
  end
  
  cache.set(rate_limit_key, current_count + 1, ttl: 3600)
end
```

---

## API Reference

### FlowNodes::FlowRoute

#### Class Methods

##### `.draw(&block) → Hash`

Create a routes configuration using the DSL.

```ruby
routes_config = FlowNodes::FlowRoute.draw do
  node :classifier do
    route :success, to: handler
  end
end
```

**Returns:** Hash containing the routes configuration

##### `.load_file(file_path) → Hash`

Load routes from an external file.

```ruby
routes = FlowNodes::FlowRoute.load_file('config/routes.rb')
```

**Parameters:**
- `file_path` (String): Path to the routes file

**Returns:** Hash containing the routes configuration  
**Raises:** Exception if file not found

##### `.apply_routes!(node_registry, routes_config) → void`

Apply routes configuration to actual node instances.

```ruby
FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
```

**Parameters:**
- `node_registry` (Hash): Map of node names to node instances
- `routes_config` (Hash): Routes configuration from `draw` or `load_file`

#### Instance Methods (DSL)

##### `node(node_name, &block) → void`

Define routes for a specific node.

```ruby
node :classifier do
  route :success, to: handler
end
```

**Parameters:**
- `node_name` (Symbol): Name of the node to configure

##### `route(conditions, to:, **options) → void`

Define a route within a node block.

```ruby
route :success, to: handler
route [:success, :partial], to: handler  # Multiple conditions
```

**Parameters:**
- `conditions` (Symbol|Array<Symbol>): Condition(s) that trigger this route
- `to` (BaseNode|Symbol): Target node or node chain
- `options` (Hash): Additional routing options

##### `otherwise(to:) → void`

Define fallback/default routing.

```ruby
otherwise to: default_handler
```

**Parameters:**
- `to` (BaseNode|Symbol): Default target node

##### `namespace(namespace_name, &block) → void`

Organize routes within a namespace.

```ruby
namespace :api do
  node :v1_processor do
    route :users, to: user_handler
  end
end
```

**Parameters:**
- `namespace_name` (Symbol): Namespace identifier

##### `resources(resource_name, **options) → void`

Define resource-style routing for common CRUD patterns.

```ruby
resources :document_manager,
  create: creator,
  read: reader,
  update: updater,
  delete: deleter
```

**Parameters:**
- `resource_name` (Symbol): Resource identifier  
- `options` (Hash): CRUD operation mappings

---

## Troubleshooting

### Common Issues

#### 1. "Route target must be a BaseNode"

**Problem:** Trying to use symbol targets with `apply_routes!`

```ruby
# ❌ This will fail
FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
```

**Solution:** Ensure your routes use actual node instances or map symbols correctly:

```ruby
# ✅ Use node instances in routes
FlowNodes::FlowRoute.draw do
  node :classifier do
    route :success, to: actual_node_instance
  end
end

# ✅ Or map symbols in node_registry
node_registry = {
  classifier: classifier_instance,
  handler: handler_instance
}
```

#### 2. "undefined method `routes`"

**Problem:** Node doesn't inherit from FlowNodes::BaseNode

```ruby
# ❌ Custom node without proper inheritance
class MyNode
  def exec(params)
    # ...
  end
end
```

**Solution:** Inherit from FlowNodes::Node or FlowNodes::BaseNode:

```ruby
# ✅ Proper inheritance
class MyNode < FlowNodes::Node
  def exec(params)
    # ...
  end
end
```

#### 3. Routes not being applied

**Problem:** Calling `apply_routes!` with wrong parameters

**Solution:** Check node registry keys match route definitions:

```ruby
# Routes definition
FlowNodes::FlowRoute.draw do
  node :my_classifier do  # ← This key name
    route :success, to: handler
  end
end

# Node registry
node_registry = {
  my_classifier: classifier_instance  # ← Must match this key
}
```

#### 4. Flow ends unexpectedly

**Problem:** Node returns symbol not defined in routes

```ruby
class MyNode < FlowNodes::Node
  def exec(params)
    :unknown_result  # ← Not defined in routes
  end
end
```

**Solution:** Ensure all possible return values have routes:

```ruby
FlowNodes::FlowRoute.draw do
  node :my_node do
    route :unknown_result, to: fallback_handler
    otherwise to: default_handler  # Catch-all
  end
end
```

### Debugging Tools

#### 1. Enable Flow Logging

```ruby
# Add to your node
class DebuggingNode < FlowNodes::Node
  def exec(params)
    puts "Node: #{self.class.name}"
    puts "Params: #{params.keys}"
    puts "Input: #{params[:input][0..100]}"
    
    result = perform_operation(params)
    
    puts "Output: #{result}"
    result
  end
end
```

#### 2. Route Introspection

```ruby
# Check what routes are configured
routes_config = FlowNodes::FlowRoute.draw { /* your routes */ }
puts routes_config.inspect

# Check node successors after applying routes
node_registry = { /* your nodes */ }
FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)

node_registry[:classifier].instance_variable_get(:@successors).each do |action, target|
  puts "#{action} → #{target.class.name}"
end
```

#### 3. Performance Monitoring

```ruby
class PerformanceMonitoringNode < FlowNodes::Node
  def exec(params)
    start_time = Time.now
    result = super(params)
    duration = Time.now - start_time
    
    if duration > 1.0  # Log slow operations
      Rails.logger.warn("Slow node: #{self.class.name} took #{duration}s")
    end
    
    result
  end
end
```

### Performance Issues

#### Problem: High Memory Usage

**Cause:** Large objects accumulating in params hash

**Solution:** Clean up params between nodes:

```ruby
class CleanupNode < FlowNodes::Node
  def exec(params)
    result = process(params[:large_data])
    
    # Clean up large objects
    params.delete(:large_data)
    params[:result] = result
    
    nil
  end
end
```

#### Problem: Slow Route Resolution

**Cause:** Routes being compiled on every request

**Solution:** Compile routes once at application startup:

```ruby
# In Rails initializer or Sinatra configure block
ROUTES_CONFIG = FlowNodes::FlowRoute.draw { /* routes */ }
NODE_REGISTRY = { /* nodes */ }
FlowNodes::FlowRoute.apply_routes!(NODE_REGISTRY, ROUTES_CONFIG)
```

---

## Migration Guide

### From Hash-Based Routing

#### Before (Hash-based)

```ruby
classifier.routes(
  [:success, :partial] => handler >> responder,
  :error => error_handler,
  :unknown => fallback_handler
)
```

#### After (FlowRoute)

```ruby
FlowNodes::FlowRoute.draw do
  node :classifier do
    route [:success, :partial], to: handler >> responder
    route :error, to: error_handler
    otherwise to: fallback_handler
  end
end
```

### Migration Steps

1. **Extract routing configuration** from node definitions
2. **Create routes file** (`config/flow_routes.rb`)  
3. **Update application initialization** to load routes
4. **Test thoroughly** - routing behavior should be identical
5. **Remove old `.routes()` calls** from node classes
6. **Add environment-specific routes** as needed

---

## Contributing

### Reporting Issues

Please report issues on GitHub with:
- Ruby version
- FlowNodes version  
- Minimal reproduction case
- Expected vs actual behavior

### Feature Requests

We welcome feature requests! Please describe:
- Use case and motivation
- Proposed API design
- Examples of usage
- Impact on existing functionality

### Development Setup

```bash
git clone https://github.com/flowNodes/flow_nodes.git
cd flow_nodes
bundle install
bundle exec rspec
```

---

## License

MIT License - see LICENSE file for details.

---

## Changelog

### Version 1.0.0 (July 2025)
- Initial FlowRoute release
- Rails-style DSL implementation
- Support for multiple condition routing
- Namespace and resource routing
- Rails and Sinatra integration examples
- Comprehensive documentation and test suite