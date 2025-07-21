# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlowNodes::FlowRoute do
  let(:test_node1) { FlowNodes::Node.new }
  let(:test_node2) { FlowNodes::Node.new }
  let(:test_node3) { FlowNodes::Node.new }
  let(:test_node4) { FlowNodes::Node.new }

  let(:node_registry) do
    {
      classifier: test_node1,
      handler1: test_node2,
      handler2: test_node3,
      fallback: test_node4,
    }
  end

  describe ".draw" do
    it "creates a route configuration with single node" do
      routes_config = described_class.draw do
        node :classifier do
          route :success, to: :handler1
          route :failure, to: :handler2
        end
      end

      expect(routes_config).to be_a(Hash)
      expect(routes_config[:classifier]).to be_an(Array)
      expect(routes_config[:classifier].size).to eq(2)
    end

    it "supports multiple conditions routing to same target" do
      routes_config = described_class.draw do
        node :classifier do
          route %i[success partial], to: :handler1
          route :failure, to: :handler2
        end
      end

      classifier_routes = routes_config[:classifier]
      success_route = classifier_routes.find { |r| r[:conditions].include?(:success) }

      expect(success_route[:conditions]).to eq(%i[success partial])
      expect(success_route[:target]).to eq(:handler1)
    end

    it "supports nested node definitions" do
      routes_config = described_class.draw do
        node :classifier1 do
          route :route1, to: :handler1
        end

        node :classifier2 do
          route :route2, to: :handler2
        end
      end

      expect(routes_config.keys).to contain_exactly(:classifier1, :classifier2)
      expect(routes_config[:classifier1].size).to eq(1)
      expect(routes_config[:classifier2].size).to eq(1)
    end

    it "supports otherwise/default routing" do
      routes_config = described_class.draw do
        node :classifier do
          route :success, to: :handler1
          otherwise to: :handler2
        end
      end

      classifier_routes = routes_config[:classifier]
      default_route = classifier_routes.find { |r| r[:conditions].include?(:default) }

      expect(default_route[:target]).to eq(:handler2)
    end

    it "supports conditional routing with options" do
      condition_proc = ->(params) { params[:priority] == "high" }

      routes_config = described_class.draw do
        node :classifier do
          route :urgent, to: :handler1, if: condition_proc
        end
      end

      urgent_route = routes_config[:classifier].first
      expect(urgent_route[:options][:if]).to eq(condition_proc)
    end

    it "supports namespace organization" do
      routes_config = described_class.draw do
        namespace :api do
          node :v1_classifier do
            route :success, to: :handler1
          end
        end
      end

      # NOTE: Basic implementation doesn't fully support namespaces yet
      # This test ensures the DSL doesn't break with namespace blocks
      expect(routes_config[:v1_classifier]).not_to be_empty
    end

    it "supports resource-style routing" do
      routes_config = described_class.draw do
        resources :document_processor,
                  create: :creator_node,
                  read: :reader_node,
                  update: :updater_node
      end

      doc_routes = routes_config[:document_processor]
      create_route = doc_routes.find { |r| r[:conditions].include?(:create) }
      read_route = doc_routes.find { |r| r[:conditions].include?(:read) }

      expect(create_route[:target]).to eq(:creator_node)
      expect(read_route[:target]).to eq(:reader_node)
    end
  end

  describe ".apply_routes!" do
    let(:routes_config) do
      {
        classifier: [
          {
            conditions: %i[success partial],
            target: test_node2,
            options: {},
          },
          {
            conditions: [:failure],
            target: test_node3,
            options: {},
          },
        ],
      }
    end

    it "applies routes to node instances" do
      expect(test_node1).to receive(:routes).with({ %i[success partial] => test_node2 })
      expect(test_node1).to receive(:routes).with({ [:failure] => test_node3 })

      described_class.apply_routes!(node_registry, routes_config)
    end

    it "skips missing nodes in registry" do
      limited_registry = { classifier: test_node1 }
      routes_with_missing = {
        classifier: [{ conditions: [:success], target: test_node2, options: {} }],
        missing_node: [{ conditions: [:test], target: test_node3, options: {} }],
      }

      expect(test_node1).to receive(:routes).once
      expect { described_class.apply_routes!(limited_registry, routes_with_missing) }.not_to raise_error
    end

    it "warns about conditional routing not yet implemented" do
      conditional_routes = {
        classifier: [
          {
            conditions: [:conditional],
            target: test_node2,
            options: { if: -> { true } },
          },
        ],
      }

      expect { described_class.apply_routes!(node_registry, conditional_routes) }
        .to output(/Conditional routing not yet implemented/).to_stderr
    end
  end

  describe ".load_file" do
    let(:routes_file_path) { "/tmp/test_routes.rb" }
    let(:routes_content) do
      <<~RUBY
        FlowNodes::FlowRoute.draw do
          node :test_classifier do
            route :success, to: :handler
          end
        end
      RUBY
    end

    before do
      File.write(routes_file_path, routes_content)
    end

    after do
      FileUtils.rm_f(routes_file_path)
    end

    it "loads routes from file" do
      expect(File).to exist(routes_file_path)
      expect { described_class.load_file(routes_file_path) }.not_to raise_error
    end

    it "raises error for non-existent file" do
      expect { described_class.load_file("/non/existent/file.rb") }
        .to raise_error(/Routes file not found/)
    end
  end

  describe "route validation" do
    it "raises error when route is called outside node block" do
      expect do
        described_class.draw do
          route :invalid, to: :invalid_handler
        end
      end.to raise_error(/route must be called within a node block/)
    end

    it "raises error when when is called outside node block" do
      expect do
        described_class.draw do
          send(:when, -> { true }, to: :handler1)
        end
      end.to raise_error(/when must be called within a node block/)
    end
  end

  describe "DSL method delegation" do
    let(:route_instance) { described_class.new }

    it "has routes accessor" do
      expect(route_instance.routes).to be_a(Hash)
    end

    it "supports method chaining in node blocks" do
      routes_config = described_class.draw do
        node :classifier do
          route :success, to: :handler1
          route :failure, to: :handler2
        end
      end

      # Basic test - the DSL should not break
      expect(routes_config[:classifier]).not_to be_empty
    end
  end

  describe "integration with existing routing system" do
    it "generates routes compatible with BaseNode#routes method" do
      routes_config = described_class.draw do
        node :classifier do
          route %i[success partial], to: :handler1
        end
      end

      # The generated config should work with the existing routes() method
      route_def = routes_config[:classifier].first
      expect { test_node1.routes({ route_def[:conditions] => test_node2 }) }
        .not_to raise_error
    end
  end

  describe "complex routing scenarios" do
    it "handles mixed single and array conditions" do
      routes_config = described_class.draw do
        node :complex_classifier do
          route :single_condition, to: :handler1
          route %i[multi condition], to: :handler2
          route :another_single, to: :handler3
        end
      end

      classifier_routes = routes_config[:complex_classifier]

      single_route = classifier_routes.find { |r| r[:conditions] == [:single_condition] }
      multi_route = classifier_routes.find { |r| r[:conditions] == %i[multi condition] }

      expect(single_route[:target]).to eq(:handler1)
      expect(multi_route[:target]).to eq(:handler2)
      expect(classifier_routes.size).to eq(3)
    end

    it "supports symbol and string target references" do
      routes_config = described_class.draw do
        node :classifier do
          route :success, to: :handler_symbol
          route :failure, to: "handler_string"
        end
      end

      success_route = routes_config[:classifier].first
      failure_route = routes_config[:classifier].last
      expect(success_route[:target]).to eq(:handler_symbol)
      expect(failure_route[:target]).to eq("handler_string")
    end
  end

  describe "error handling and edge cases" do
    it "handles empty route blocks gracefully" do
      routes_config = described_class.draw do
        node :empty_classifier do
          # Empty block
        end
      end

      expect(routes_config[:empty_classifier]).to be_empty
    end

    it "handles duplicate route definitions" do
      routes_config = described_class.draw do
        node :duplicate_classifier do
          route :success, to: :handler1
          route :success, to: :handler2 # Duplicate - should add both
        end
      end

      success_routes = routes_config[:duplicate_classifier]
      expect(success_routes.size).to eq(2)
    end
  end
end
