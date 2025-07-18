# frozen_string_literal: true

require_relative "lib/flow_nodes/version"

Gem::Specification.new do |spec|
  spec.name = "flow_nodes"
  spec.version = FlowNodes::VERSION
  spec.authors = ["RJ Robinson"]
  spec.email = ["rj@trainual.com"]

  spec.summary = "A Ruby port of PocketFlow, the minimalist LLM framework."
  spec.description = "FlowNodes is a Ruby port of PocketFlow, the Python framework created by The Pocket. " \
                     "It brings the power and simplicity of PocketFlow's graph-based architecture to the Ruby " \
                     "ecosystem. Build powerful LLM applications like Agents, Workflows, and RAG systems " \
                     "with minimal code and maximum expressiveness."
  spec.homepage = "https://github.com/rjrobinson/flow_nodes"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rjrobinson/flow_nodes"
  spec.metadata["changelog_uri"] = "https://github.com/rjrobinson/flow_nodes/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.end_with?(".gem") ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile .idea/ coverage/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
