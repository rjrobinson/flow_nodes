# frozen_string_literal: true

module FlowNodes
  # Rails-inspired routing DSL for FlowNodes
  # 
  # Provides a centralized, declarative way to define routing between nodes,
  # similar to Rails routes but adapted for workflow/state machine patterns.
  #
  # @example Basic usage in a routes file
  #   FlowNodes::FlowRoute.draw do
  #     node :classifier do
  #       route [:technical, :billing, :general], to: knowledge_base >> responder
  #       route :escalate, to: escalator
  #       route :unknown, to: fallback
  #     end
  #   end
  #
  # @example With conditions and middleware
  #   FlowNodes::FlowRoute.draw do
  #     node :user_classifier do
  #       route :premium, to: premium_handler, if: -> { |params| params[:user_type] == 'premium' }
  #       route :basic, to: basic_handler
  #     end
  #   end
  class FlowRoute
    # Global route registry for managing multiple route definitions
    @@routes_registry = {}
    @@current_routes = nil

    # DSL entry point - creates a new routing context
    #
    # @yield [FlowRoute] The route builder instance
    # @return [Hash] The complete routes configuration
    def self.draw(&block)
      route_builder = new
      @@current_routes = route_builder
      route_builder.instance_eval(&block)
      @@current_routes = nil
      route_builder.routes
    end

    # Load routes from a file (Rails-style)
    #
    # @param file_path [String] Path to the routes file
    # @return [Hash] The loaded routes configuration
    def self.load_file(file_path)
      raise "Routes file not found: #{file_path}" unless File.exist?(file_path)
      
      routes_code = File.read(file_path)
      eval(routes_code)
    end

    # Apply loaded routes to actual node instances
    #
    # @param node_registry [Hash] Map of node names to node instances
    # @param routes_config [Hash] Routes configuration from draw or load_file
    def self.apply_routes!(node_registry, routes_config)
      routes_config.each do |node_name, node_routes|
        node = node_registry[node_name]
        next unless node

        node_routes.each do |route_definition|
          conditions = route_definition[:conditions]
          target = route_definition[:target]
          options = route_definition[:options]

          # Apply conditional routing if condition exists
          if options[:if]
            # TODO: Implement conditional routing
            warn "Conditional routing not yet implemented for #{node_name}"
          end

          # Use the existing routes method for compatibility
          node.routes({ conditions => target })
        end
      end
    end

    # Get all registered routes
    def self.routes_registry
      @@routes_registry
    end

    def initialize
      @routes = {}
      @current_node = nil
    end

    attr_reader :routes

    # Define routes for a specific node
    #
    # @param node_name [Symbol] The name of the node to configure
    # @yield Block containing route definitions for this node
    def node(node_name, &block)
      @current_node = node_name
      @routes[@current_node] ||= []
      instance_eval(&block)
      @current_node = nil
    end

    # Define a route within a node block
    #
    # @param conditions [Symbol, Array<Symbol>] Condition(s) that trigger this route
    # @param to [BaseNode, Object] Target node or node chain
    # @param options [Hash] Additional routing options (if:, unless:, etc.)
    def route(conditions, to:, **options)
      raise "route must be called within a node block" unless @current_node

      # Normalize conditions to array
      normalized_conditions = conditions.is_a?(Array) ? conditions : [conditions]

      @routes[@current_node] << {
        conditions: normalized_conditions,
        target: to,
        options: options
      }
    end

    # Convenience method for multiple routes to same target
    #
    # @param conditions [Array<Symbol>] Multiple conditions
    # @param to [BaseNode, Object] Target node or node chain  
    def multiple_routes(conditions, to:, **options)
      route(conditions, to: to, **options)
    end

    # Define conditional routing based on params or state
    #
    # @param condition_proc [Proc] Lambda that evaluates routing condition
    # @param to [BaseNode, Object] Target node if condition is true
    def when(condition_proc, to:)
      raise "when must be called within a node block" unless @current_node

      @routes[@current_node] << {
        conditions: :conditional,
        target: to,
        options: { if: condition_proc }
      }
    end

    # Define fallback/default routing
    #
    # @param to [BaseNode, Object] Default target node
    def otherwise(to:)
      route(:default, to: to)
    end

    # Namespace support for organizing complex routing
    #
    # @param namespace_name [Symbol] Namespace identifier
    # @yield Block containing namespaced route definitions
    def namespace(namespace_name, &block)
      previous_namespace = @current_namespace
      @current_namespace = namespace_name
      instance_eval(&block)
      @current_namespace = previous_namespace
    end

    # Resource-style routing for common patterns
    #
    # @param resource_name [Symbol] Resource identifier
    # @param options [Hash] Configuration options
    def resources(resource_name, **options)
      node resource_name do
        route :create, to: options[:create] if options[:create]
        route :read, to: options[:read] if options[:read] 
        route :update, to: options[:update] if options[:update]
        route :delete, to: options[:delete] if options[:delete]
      end
    end
  end
end