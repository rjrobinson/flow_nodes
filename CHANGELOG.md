# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of FlowNodes gem
- Core node and flow architecture
- BaseNode class with parameter management and connections
- Node class with retry logic and lifecycle hooks
- Flow class for orchestrating node execution
- BatchNode for sequential batch processing
- AsyncNode for asynchronous execution
- AsyncBatchNode for async sequential batch processing
- AsyncParallelBatchNode for parallel batch processing
- AsyncFlow for orchestrating async and sync nodes
- AsyncBatchFlow for async batch processing
- AsyncParallelBatchFlow for parallel batch processing
- ConditionalTransition for conditional flow routing
- Comprehensive test suite with 181 tests
- Thread-safe parameter isolation with deep copying
- Retry mechanisms with customizable fallbacks
- Lifecycle hooks (prep, exec, post)
- Examples directory with practical use cases
- GitHub Actions CI/CD workflow
- RuboCop configuration for code quality
- SimpleCov for code coverage tracking
- Qlty integration for code quality and coverage monitoring
- YARD documentation support
- Comprehensive README with usage examples

### Changed
- Refactored monolithic structure to use individual class files
- Fixed parameter passing issues in async execution
- Improved array handling in batch processing
- Enhanced error handling in async flows
- Optimized performance for I/O-bound tasks

### Fixed
- Parameter flow through prep() → _run() → _orch() → _exec() → exec()
- Array handling to prevent hash-to-array conversion issues
- Post hook parameter passing in async operations
- Conditional flow routing in async contexts
- Thread safety issues in parallel processing
- Retry logic consistency across all node types

## [0.1.0] - 2024-01-XX

### Added
- Initial release with core FlowNodes framework
- Ruby port of PocketFlow's minimalist LLM architecture
- Production-ready architecture with clean separation of concerns
- Support for Ruby 3.1+ with proper dependency management
- MIT license for open source usage
- Full compatibility with PocketFlow's design patterns and philosophy