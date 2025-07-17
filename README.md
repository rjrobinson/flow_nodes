<div align="center">
  <a href="https://github.com/The-Pocket/PocketFlow">
    <img src="https://github.com/The-Pocket/.github/raw/main/assets/title.png" alt="Pocket Flow – 100-line minimalist LLM framework" width="600"/>
  </a>
</div>

# FlowNodes

**A Ruby port of the minimalist LLM framework, [PocketFlow](https://github.com/The-Pocket/PocketFlow).**

---

`flow_nodes` is a Ruby gem that brings the lightweight, expressive power of PocketFlow to the Ruby ecosystem. It provides a minimal, graph-based core for building powerful LLM applications like Agents, Workflows, and RAG, without the bloat of larger frameworks.

This project gives full credit to the original Python-based [PocketFlow](https://github.com/The-Pocket/PocketFlow) and aims to bring the same minimalist philosophy to Ruby developers.

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

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

## Usage

The core abstraction of `flow_nodes` is a simple, powerful graph. You define nodes and connect them to create complex workflows and agentic systems.

_(More detailed usage examples and documentation for the Ruby implementation are coming soon.)_

For the conceptual background and design patterns (which are language-agnostic), please refer to the excellent documentation of the original [PocketFlow project](https://the-pocket.github.io/PocketFlow/).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/rjrobinson/flow_nodes](https://github.com/rjrobinson/flow_nodes).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
