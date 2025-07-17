# FlowNodes

[![Gem Version](https://badge.fury.io/rb/flow_nodes.svg)](https://badge.fury.io/rb/flow_nodes)
[![CI](https://github.com/rjrobinson/flow_nodes/workflows/CI/badge.svg)](https://github.com/rjrobinson/flow_nodes/actions)
[![Qlty](https://img.shields.io/badge/code_quality-qlty-brightgreen.svg)](https://qlty.sh/)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**A Ruby port of the minimalist LLM framework, [PocketFlow](https://github.com/The-Pocket/PocketFlow).**

FlowNodes is a Ruby gem that brings the lightweight, expressive power of [PocketFlow](https://github.com/The-Pocket/PocketFlow) to the Ruby ecosystem. It provides a minimal, graph-based core for building powerful LLM applications like Agents, Workflows, and RAG, without the bloat of larger frameworks.

## Design Philosophy

FlowNodes is inspired by and based on [PocketFlow](https://github.com/The-Pocket/PocketFlow), a Python framework created by [The Pocket](https://github.com/The-Pocket). We've adapted PocketFlow's elegant, minimalist approach to LLM application development for the Ruby ecosystem.

**Core principles:**
- **Minimalist Design**: Core functionality in under 500 lines of code
- **Graph-based Architecture**: Connect nodes to create complex workflows
- **LLM-First**: Built specifically for Large Language Model applications
- **Extensible**: Easy to extend with custom nodes and flows

FlowNodes maintains the same philosophy and API patterns as PocketFlow while providing a native Ruby experience. This ensures Ruby developers can leverage the proven design patterns that make PocketFlow so effective.

## Installation

Add this line to your application's Gemfile:

```ruby
  gem 'flow_nodes'
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install flow_nodes
```

## Features

- **Minimal & Lightweight**: Core framework in under 500 lines of code
- **Graph-based**: Build complex workflows with simple node connections
- **Async Support**: Built-in async and parallel processing capabilities
- **Batch Processing**: Sequential and parallel batch operations
- **Retry Logic**: Built-in retry mechanisms with customizable fallbacks
- **Thread Safety**: Proper isolation and deep copying for concurrent execution
- **Extensible**: Easy to extend with custom nodes and flows
- **Production Ready**: Comprehensive test coverage and clean architecture

## Quick Start

### Basic Node and Flow

```ruby
require 'flow_nodes'

class GreetingNode < FlowNodes::Node
  def exec(params)
    puts "Hello, #{params[:name]}!"
    "greeted"
  end
end

class FarewellNode < FlowNodes::Node
  def exec(params)
    puts "Goodbye, #{params[:name]}!"
    nil # End the flow
  end
end

# Create nodes
greeting = GreetingNode.new
farewell = FarewellNode.new

# Connect nodes: greeting -> farewell
greeting - :greeted >> farewell

# Create and run flow
flow = FlowNodes::Flow.new(start: greeting)
flow.set_params(name: "World")
flow.run(nil)
```

### Conditional Flows

```ruby
class ValidationNode < FlowNodes::Node
  def exec(params)
    params[:email]&.include?("@") ? "valid" : "invalid"
  end
end

class ProcessNode < FlowNodes::Node
  def exec(params)
    puts "Processing #{params[:email]}"
    nil
  end
end

class ErrorNode < FlowNodes::Node
  def exec(params)
    puts "Error: Invalid email #{params[:email]}"
    nil
  end
end

validator = ValidationNode.new
processor = ProcessNode.new
error_handler = ErrorNode.new

# Branch based on validation result
validator - :valid >> processor
validator - :invalid >> error_handler

flow = FlowNodes::Flow.new(start: validator)
flow.set_params(email: "user@example.com")
flow.run(nil)
```

### Batch Processing

```ruby
class DataProcessor < FlowNodes::BatchNode
  def exec(item)
    puts "Processing: #{item}"
    item.upcase
  end
end

processor = DataProcessor.new
processor.set_params(["hello", "world", "ruby"])
results = processor.run(nil)
# => ["HELLO", "WORLD", "RUBY"]
```

### Async and Parallel Processing

```ruby
class AsyncProcessor < FlowNodes::AsyncParallelBatchNode
  def exec_async(item)
    puts "Processing #{item} on thread #{Thread.current.object_id}"
    sleep(0.1) # Simulate I/O
    item.upcase
  end
end

processor = AsyncProcessor.new
processor.set_params(["hello", "world", "ruby"])
results = processor.run_async(nil)
# Processes all items in parallel
```

### Lifecycle Hooks

```ruby
class LoggingNode < FlowNodes::Node
  def prep(state)
    puts "Preparing to process"
    { prepared_at: Time.now }
  end

  def exec(params)
    puts "Processing: #{params}"
    "success"
  end

  def post(state, params, result)
    puts "Completed with result: #{result}"
  end
end
```

### Error Handling and Retries

```ruby
class RetryNode < FlowNodes::Node
  def initialize
    super(max_retries: 3, wait: 1)
  end

  def exec(params)
    # Simulate unreliable operation
    raise "Network error" if rand < 0.7
    "success"
  end

  def exec_fallback(params, exception)
    puts "All retries failed: #{exception.message}"
    "failed"
  end
end
```

## Architecture

FlowNodes is built around several core classes:

- **`BaseNode`**: Foundation class with parameter management and connections
- **`Node`**: Adds retry logic and lifecycle hooks
- **`Flow`**: Orchestrates node execution and state management
- **`BatchNode`**: Processes arrays of items sequentially
- **`AsyncNode`**: Enables asynchronous execution
- **`AsyncBatchNode`**: Async sequential batch processing
- **`AsyncParallelBatchNode`**: Async parallel batch processing
- **`AsyncFlow`**: Orchestrates async and sync nodes together

## Examples

See the [`examples/`](examples/) directory for complete examples:

- [`examples/chatbot.rb`](examples/chatbot.rb) - Interactive chatbot with self-loops
- [`examples/workflow.rb`](examples/workflow.rb) - Data validation and processing workflow
- [`examples/batch_processing.rb`](examples/batch_processing.rb) - Sequential and parallel batch operations

## Development

After checking out the repo, run `bundle install` to install dependencies.

### Running Tests

```bash
bundle exec rspec
```

### Code Quality

```bash
# Run RuboCop for style checking
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a

# Generate documentation
bundle exec yard doc
```

### CI/CD Setup

The project uses GitHub Actions for CI/CD with the following secrets required:

- `QLTY_COVERAGE_TOKEN`: Token for Qlty code coverage reporting
- `RUBYGEMS_AUTH_TOKEN`: Token for publishing to RubyGems (optional)

### Running Examples

```bash
# Run the chatbot example
ruby examples/chatbot.rb

# Run the workflow example
ruby examples/workflow.rb

# Run the batch processing example
ruby examples/batch_processing.rb
```

## API Reference

For detailed API documentation, visit the [YARD documentation](https://rubydoc.info/gems/flow_nodes) or generate it locally:

```bash
bundle exec yard doc
open doc/index.html
```

## Performance Considerations

- **Async Operations**: Use Ruby threads, subject to the GVL. Best for I/O-bound tasks.
- **Parallel Processing**: `AsyncParallelBatchNode` provides concurrency for I/O operations.
- **Memory**: Deep copying ensures thread safety but uses more memory.
- **Batch Size**: Consider batch sizes for memory usage vs. processing efficiency.

## Thread Safety

FlowNodes is designed to be thread-safe:

- Parameters are deep-copied using `Marshal` to prevent state bleed
- Each flow execution operates on isolated node instances
- Shared state objects should be managed carefully in multi-threaded environments

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for your changes
5. Ensure all tests pass (`bundle exec rspec`)
6. Run RuboCop (`bundle exec rubocop`)
7. Commit your changes (`git commit -am 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

### Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

## Acknowledgments

This project is a Ruby port of the excellent [PocketFlow](https://github.com/The-Pocket/PocketFlow) Python framework created by [The Pocket](https://github.com/The-Pocket). 

**Special thanks to:**
- The original PocketFlow team for pioneering the minimalist LLM framework approach
- The Python community for inspiring clean, expressive API design
- The Ruby community for providing excellent tools and libraries that made this port possible

FlowNodes would not exist without the groundbreaking work of the PocketFlow team. We encourage users to also check out the [original Python PocketFlow](https://github.com/The-Pocket/PocketFlow) and its excellent [documentation](https://the-pocket.github.io/PocketFlow/).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
