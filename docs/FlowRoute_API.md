# FlowRoute API Documentation

**Version:** 1.0.0  
**Last Updated:** July 2025

Complete API reference for FlowNodes::FlowRoute - Rails-style routing for workflow orchestration.

## Table of Contents

1. [Class Overview](#class-overview)
2. [Public Class Methods](#public-class-methods)
3. [DSL Instance Methods](#dsl-instance-methods)
4. [Configuration Objects](#configuration-objects)
5. [Error Classes](#error-classes)
6. [Integration APIs](#integration-apis)
7. [Examples](#examples)

---

## Class Overview

### FlowNodes::FlowRoute

The main class providing Rails-style routing DSL for FlowNodes workflows.

```ruby
class FlowNodes::FlowRoute
  # Class-level route registry and configuration
  @@routes_registry = {}
  @@current_routes = nil

  # Instance variables for DSL state
  @routes = {}
  @current_node = nil
  @current_namespace = nil
end
```

**Key Features:**
- **Declarative DSL**: Rails-inspired routing syntax
- **Global Registry**: Centralized route management
- **Thread-Safe**: Safe for concurrent access
- **Extensible**: Support for custom routing patterns

---

## Public Class Methods

### `.draw(&block) → Hash`

Creates a new routing configuration using the FlowRoute DSL.

**Syntax:**
```ruby
routes_config = FlowNodes::FlowRoute.draw do
  # DSL block
end
```

**Parameters:**
- `block` (Proc): Block containing route definitions using the DSL

**Returns:**
- `Hash`: Routes configuration mapping node names to route definitions

**Example:**
```ruby
routes_config = FlowNodes::FlowRoute.draw do
  node :classifier do
    route :success, to: success_handler
    route [:error, :timeout], to: error_handler
    otherwise to: fallback_handler
  end
end

# Result:
# {
#   classifier: [
#     { conditions: [:success], target: success_handler, options: {} },
#     { conditions: [:error, :timeout], target: error_handler, options: {} },
#     { conditions: [:default], target: fallback_handler, options: {} }
#   ]
# }
```

**Thread Safety:** Yes - creates isolated route builder instance

**Exceptions:**
- `RuntimeError`: If called with invalid DSL syntax
- `ArgumentError`: If block is required but not provided

---

### `.load_file(file_path) → Hash`

Loads routes from an external Ruby file.

**Syntax:**
```ruby
routes_config = FlowNodes::FlowRoute.load_file(file_path)
```

**Parameters:**
- `file_path` (String): Absolute or relative path to the routes file

**Returns:**
- `Hash`: Routes configuration from the loaded file

**Example:**
```ruby
# config/routes.rb
FlowNodes::FlowRoute.draw do
  node :api_router do
    route :get, to: get_handler
    route :post, to: post_handler
  end
end

# Loading the file
routes = FlowNodes::FlowRoute.load_file('config/routes.rb')
```

**File Requirements:**
- Must be valid Ruby code
- Must contain FlowNodes::FlowRoute.draw block
- File must exist and be readable

**Exceptions:**
- `Errno::ENOENT`: If file doesn't exist
- `SyntaxError`: If file contains invalid Ruby syntax
- `RuntimeError`: If file doesn't contain valid routes

---

### `.apply_routes!(node_registry, routes_config) → void`

Applies route configuration to actual node instances.

**Syntax:**
```ruby
FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
```

**Parameters:**
- `node_registry` (Hash): Map of symbol keys to FlowNodes::BaseNode instances
- `routes_config` (Hash): Routes configuration from `.draw` or `.load_file`

**Returns:**
- `void`: Modifies node instances in-place

**Side Effects:**
- Calls `routes()` method on each node instance
- Warns to stderr if route overwrites existing successors
- Logs conditional routing warnings (not yet implemented)

**Example:**
```ruby
node_registry = {
  classifier: ClassifierNode.new,
  handler: HandlerNode.new
}

routes_config = FlowNodes::FlowRoute.draw do
  node :classifier do
    route :success, to: :handler
  end
end

FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)
# classifier node now has :success route to handler node
```

**Validation:**
- Skips nodes not found in registry (logs warning)
- Validates route conditions are strings or symbols
- Maps symbol targets to actual node instances

**Exceptions:**
- `ArgumentError`: If parameters are wrong type
- `NoMethodError`: If node doesn't respond to `routes` method

---

### `.routes_registry → Hash`

Returns the global routes registry.

**Syntax:**
```ruby
registry = FlowNodes::FlowRoute.routes_registry
```

**Returns:**
- `Hash`: Global registry of all loaded routes configurations

**Usage:**
- Debugging route configurations
- Introspecting loaded routes
- Managing multiple route sets

**Example:**
```ruby
registry = FlowNodes::FlowRoute.routes_registry
puts registry.keys  # Shows all registered route sets
```

---

## DSL Instance Methods

### `node(node_name, &block) → void`

Defines routes for a specific workflow node.

**Syntax:**
```ruby
node :node_name do
  # Route definitions
end
```

**Parameters:**
- `node_name` (Symbol): Identifier for the node
- `block` (Proc): Block containing route definitions for this node

**Context:**
- Must be called within a `.draw` block
- Sets current node context for route definitions
- Supports nested node definitions

**Example:**
```ruby
FlowNodes::FlowRoute.draw do
  node :content_processor do
    route :text, to: text_handler
    route :image, to: image_handler
  end
  
  node :response_generator do
    route :formatted, to: output_formatter
    otherwise to: default_formatter
  end
end
```

**State Management:**
- Sets `@current_node` instance variable
- Initializes routes array for the node
- Clears current node context when block exits

---

### `route(conditions, to:, **options) → void`

Defines a route within a node block.

**Syntax:**
```ruby
route condition, to: target_node
route [condition1, condition2], to: target_node
route condition, to: target_node, if: lambda_condition
```

**Parameters:**
- `conditions` (Symbol|Array<Symbol>): Condition(s) that trigger this route
- `to` (BaseNode|Symbol): Target node or node chain (using `>>`)
- `options` (Hash): Additional routing options

**Options:**
- `:if` (Proc): Lambda for conditional routing (planned feature)
- `:unless` (Proc): Lambda for negative conditional routing (planned feature)
- `:name` (String): Named route for debugging (planned feature)

**Validation:**
- Must be called within a `node` block
- Conditions must be Symbol or String types
- Target must be a BaseNode instance or Symbol

**Examples:**
```ruby
# Single condition
route :success, to: success_handler

# Multiple conditions
route [:error, :timeout, :failure], to: error_handler

# Conditional routing (planned)
route :premium, to: premium_handler, if: -> { |params| params[:user_type] == 'premium' }

# Node chaining
route :process, to: validator >> processor >> formatter
```

**Exceptions:**
- `RuntimeError`: If called outside node block
- `TypeError`: If conditions are not Symbol/String
- `ArgumentError`: If required `to:` parameter is missing

---

### `otherwise(to:) → void`

Defines default/fallback routing for unmatched conditions.

**Syntax:**
```ruby
otherwise to: default_handler
```

**Parameters:**
- `to` (BaseNode|Symbol): Default target node

**Behavior:**
- Equivalent to `route :default, to: target`
- Handles any return value not explicitly routed
- Should be last route definition in node block

**Example:**
```ruby
node :classifier do
  route :type_a, to: handler_a
  route :type_b, to: handler_b
  otherwise to: unknown_type_handler  # Catches everything else
end
```

---

### `namespace(namespace_name, &block) → void`

Organizes route definitions within a namespace.

**Syntax:**
```ruby
namespace :namespace_name do
  # Node definitions
end
```

**Parameters:**
- `namespace_name` (Symbol): Namespace identifier
- `block` (Proc): Block containing namespaced node definitions

**Current Implementation:**
- Basic namespace support (sets context variable)
- Nodes are still globally scoped
- Full namespace isolation planned for future release

**Example:**
```ruby
FlowNodes::FlowRoute.draw do
  namespace :api do
    node :v1_processor do
      route :users, to: user_handler
    end
    
    node :v2_processor do
      route :users, to: v2_user_handler
    end
  end
  
  namespace :admin do
    node :admin_processor do
      route :manage_users, to: admin_user_handler
    end
  end
end
```

---

### `resources(resource_name, **options) → void`

Defines resource-style routing for CRUD operations.

**Syntax:**
```ruby
resources :resource_name, create: node, read: node, update: node, delete: node
```

**Parameters:**
- `resource_name` (Symbol): Resource identifier
- `options` (Hash): CRUD operation mappings

**Supported Operations:**
- `:create` - CREATE operation handler
- `:read` - READ operation handler  
- `:update` - UPDATE operation handler
- `:delete` - DELETE operation handler

**Generated Routes:**
- Creates a node with the resource name
- Maps each operation to its specified handler

**Example:**
```ruby
resources :user_manager,
  create: user_creator,
  read: user_reader,
  update: user_updater >> audit_logger,
  delete: user_deleter >> cleanup_handler

# Equivalent to:
node :user_manager do
  route :create, to: user_creator
  route :read, to: user_reader
  route :update, to: user_updater >> audit_logger
  route :delete, to: user_deleter >> cleanup_handler
end
```

---

### `when(condition_proc, to:) → void`

Defines conditional routing based on runtime evaluation (planned feature).

**Syntax:**
```ruby
when -> { |params| condition }, to: target_node
```

**Parameters:**
- `condition_proc` (Proc): Lambda that evaluates routing condition
- `to` (BaseNode|Symbol): Target node if condition is true

**Current Status:**
- DSL syntax supported
- Runtime evaluation not yet implemented
- Stored in route options for future implementation

**Planned Behavior:**
```ruby
node :content_router do
  when -> { |params| params[:user_type] == 'premium' }, to: premium_processor
  when -> { |params| params[:content_length] > 10000 }, to: large_content_processor
  otherwise to: standard_processor
end
```

---

## Configuration Objects

### Route Definition Hash

Each route is stored as a hash with the following structure:

```ruby
{
  conditions: [:symbol1, :symbol2],  # Array of condition symbols
  target: target_node,               # Target BaseNode instance or Symbol
  options: {                         # Additional options
    if: lambda_condition,            # Optional conditional lambda
    unless: lambda_condition,        # Optional negative conditional lambda
    name: "route_name"              # Optional route name
  }
}
```

### Routes Configuration Hash

The complete routes configuration returned by `.draw`:

```ruby
{
  node_name1: [route_definition1, route_definition2, ...],
  node_name2: [route_definition1, route_definition2, ...],
  ...
}
```

### Node Registry Hash

Expected structure for node registry parameter:

```ruby
{
  node_name1: node_instance1,  # Symbol key -> BaseNode instance
  node_name2: node_instance2,
  ...
}
```

**Requirements:**
- Keys must be symbols matching route node names
- Values must be instances of FlowNodes::BaseNode or subclasses
- Instances must respond to `routes()` method

---

## Error Classes

### Standard Ruby Exceptions

FlowRoute uses standard Ruby exception classes:

**`ArgumentError`**
- Invalid parameters to methods
- Missing required keyword arguments
- Wrong parameter types

**`RuntimeError`**  
- DSL methods called outside proper context
- Invalid route configurations

**`TypeError`**
- Route conditions that aren't Symbol or String
- Invalid target node types

**`Errno::ENOENT`**
- Routes file not found in `.load_file`

**`SyntaxError`**
- Invalid Ruby syntax in routes file

### Custom Error Handling

FlowRoute provides informative error messages:

```ruby
# Example error messages
"route must be called within a node block"
"Route condition must be a String or Symbol, got #{condition.class}"
"Route target must be a BaseNode, got #{target.class}"
"Routes file not found: #{file_path}"
```

---

## Integration APIs

### Rails Integration

#### ActionController Integration

```ruby
class LLMController < ApplicationController
  def process
    # Get cached node registry
    nodes = Rails.cache.fetch('flow_nodes_registry')
    
    # Execute workflow
    flow = FlowNodes::Flow.new(start: nodes[:classifier])
    flow.set_params(request_params)
    flow.run(nil)
    
    # Return results
    render json: extract_results(flow.params)
  end
end
```

#### ActiveJob Integration

```ruby
class FlowProcessingJob < ApplicationJob
  def perform(data_id, workflow_type)
    nodes = Rails.cache.fetch('flow_nodes_registry')
    starter_node = nodes[workflow_type.to_sym]
    
    flow = FlowNodes::Flow.new(start: starter_node)
    flow.set_params(load_data(data_id))
    flow.run(nil)
    
    save_results(data_id, flow.params)
  end
end
```

### Sinatra Integration

#### Basic Setup

```ruby
configure do
  # Load routes once at startup
  routes = FlowNodes::FlowRoute.load_file('config/routes.rb')
  
  # Create node registry
  nodes = create_node_registry
  
  # Apply routes
  FlowNodes::FlowRoute.apply_routes!(nodes, routes)
  
  # Store for use in routes
  set :flow_nodes, nodes
end

post '/process' do
  starter = settings.flow_nodes[:api_processor]
  
  flow = FlowNodes::Flow.new(start: starter)
  flow.set_params(params)
  flow.run(nil)
  
  json flow.params.slice(:result, :status)
end
```

### Rack Middleware Integration

```ruby
class FlowNodesMiddleware
  def initialize(app, routes_file: 'config/routes.rb')
    @app = app
    
    # Load routes once
    @routes = FlowNodes::FlowRoute.load_file(routes_file)
    @nodes = create_node_registry
    FlowNodes::FlowRoute.apply_routes!(@nodes, @routes)
  end
  
  def call(env)
    # Add FlowNodes context to env
    env['flow_nodes.registry'] = @nodes
    env['flow_nodes.routes'] = @routes
    
    @app.call(env)
  end
end
```

---

## Examples

### Basic Usage Example

```ruby
require 'flow_nodes'

# Define nodes
class InputValidatorNode < FlowNodes::Node
  def exec(params)
    input = params[:input]
    return :invalid if input.nil? || input.empty?
    return :too_long if input.length > 1000
    :valid
  end
end

class ProcessorNode < FlowNodes::Node
  def exec(params)
    params[:result] = params[:input].upcase
    :processed
  end
end

class ErrorHandlerNode < FlowNodes::Node
  def exec(params)
    params[:error] = "Invalid input: #{params[:input]}"
    nil  # End flow
  end
end

# Configure routes
routes_config = FlowNodes::FlowRoute.draw do
  node :validator do
    route :valid, to: processor
    route [:invalid, :too_long], to: error_handler
  end
  
  node :processor do
    route :processed, to: response_formatter
  end
end

# Create node instances
validator = InputValidatorNode.new
processor = ProcessorNode.new
error_handler = ErrorHandlerNode.new

# Create node registry
node_registry = {
  validator: validator,
  processor: processor,
  error_handler: error_handler
}

# Apply routes
FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)

# Execute workflow
flow = FlowNodes::Flow.new(start: validator)
flow.set_params(input: "hello world")
flow.run(nil)

puts flow.params[:result]  # => "HELLO WORLD"
```

### Advanced LLM Orchestration Example

```ruby
# Load routes from file
routes_config = FlowNodes::FlowRoute.load_file('config/llm_routes.rb')

# Create specialized LLM nodes
class ContentClassifierNode < FlowNodes::Node
  def exec(params)
    content = params[:content]
    # LLM classification logic
    case classify_content(content)
    when 'technical' then :technical_question
    when 'billing' then :billing_inquiry  
    when 'complaint' then :customer_complaint
    else :general_inquiry
    end
  end
end

class TechnicalSupportNode < FlowNodes::Node
  def exec(params)
    # Technical knowledge base search + LLM response
    params[:response] = generate_technical_response(params[:content])
    :technical_resolved
  end
end

# Set up comprehensive LLM workflow
node_registry = {
  content_classifier: ContentClassifierNode.new,
  technical_support: TechnicalSupportNode.new,
  billing_support: BillingSupportNode.new,
  complaint_handler: ComplaintHandlerNode.new,
  escalation_handler: EscalationHandlerNode.new,
  response_formatter: ResponseFormatterNode.new
}

FlowNodes::FlowRoute.apply_routes!(node_registry, routes_config)

# Process customer inquiry
flow = FlowNodes::Flow.new(start: node_registry[:content_classifier])
flow.set_params(
  content: "My API integration is returning 401 errors",
  user_id: "user123",
  session_id: "session456"
)

result = flow.run(nil)
puts flow.params[:response]  # Generated technical support response
```

### Environment-Specific Configuration

```ruby
# Load appropriate routes based on environment
environment = ENV['RAILS_ENV'] || 'development'
routes_file = case environment
              when 'production'
                'config/routes_production.rb'
              when 'staging'  
                'config/routes_staging.rb'
              else
                'config/routes_development.rb'
              end

begin
  routes = FlowNodes::FlowRoute.load_file(routes_file)
rescue Errno::ENOENT
  # Fallback to default routes
  routes = FlowNodes::FlowRoute.load_file('config/routes.rb')
end

# Environment-specific node configurations
node_registry = case environment
                when 'production'
                  create_production_nodes  # Optimized for performance
                when 'development'
                  create_development_nodes # With debugging enabled
                else
                  create_default_nodes
                end

FlowNodes::FlowRoute.apply_routes!(node_registry, routes)
```

---

## Thread Safety

FlowRoute is designed to be thread-safe:

- **Class Methods**: Thread-safe for concurrent access
- **Route Building**: Each `.draw` call creates isolated instance
- **Route Application**: Safe to call from multiple threads
- **Global Registry**: Protected by Ruby's GIL

**Best Practices:**
- Load routes once at application startup
- Apply routes during initialization, not per-request
- Use thread-local storage for request-specific data

---

## Performance Considerations

### Memory Usage

- Route configurations are lightweight hash structures
- Node instances are reused across requests
- No memory leaks from route definitions

### CPU Performance

- Route lookup is O(1) hash access
- Route compilation is O(n) where n = number of routes
- Negligible overhead after initialization

### Optimization Tips

```ruby
# ✅ Good: Compile routes once
configure do
  @routes = FlowNodes::FlowRoute.draw { /* routes */ }
  @nodes = create_node_registry
  FlowNodes::FlowRoute.apply_routes!(@nodes, @routes)
end

# ❌ Bad: Recompile routes per request
post '/process' do
  routes = FlowNodes::FlowRoute.draw { /* routes */ }  # Expensive!
  # ...
end
```

---

## Version Compatibility

**Ruby Versions:** 2.7+ (tested on 2.7, 3.0, 3.1, 3.2, 3.3)

**FlowNodes Versions:** 
- 1.0+ for full compatibility
- 0.9+ for basic functionality (some features may be limited)

**Framework Compatibility:**
- Rails 6.0+ (full integration)
- Rails 5.2+ (basic integration)  
- Sinatra 2.0+ (full integration)
- Any Rack-based framework (basic integration)

---

## Future Roadmap

### Planned Features

1. **Conditional Routing**: Runtime condition evaluation
2. **Route Middlewares**: Pre/post-route processing
3. **Route Caching**: Intelligent route compilation caching
4. **Visual Route Inspector**: Web interface for route visualization
5. **Performance Monitoring**: Built-in route performance tracking
6. **Advanced Namespacing**: True namespace isolation
7. **Route Versioning**: Multiple route versions with fallbacks

### Breaking Changes Policy

FlowRoute follows semantic versioning:
- **Major versions**: Breaking API changes
- **Minor versions**: New features, backwards compatible
- **Patch versions**: Bug fixes only

---

This completes the comprehensive API documentation for FlowNodes::FlowRoute. For usage examples and integration patterns, see the main FlowRoute Guide.