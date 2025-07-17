# frozen_string_literal: true

require_relative "../lib/flow_nodes"
require "securerandom"

# This example demonstrates:
# 1. Full lifecycle hooks (prep, exec, post)
# 2. Symbol-based actions (preferred over strings)
# 3. State management across nodes
# 4. Error handling with retries
# 5. Conditional branching

module AdvancedWorkflow
  class OrderValidationNode < FlowNodes::Node
    def initialize
      super(max_retries: 2, wait: 0.5)
    end

    def prep(state)
      puts "🔍 [#{Time.now.strftime('%H:%M:%S')}] Starting order validation..."
      state[:validation_start] = Time.now
      state[:order_id] = SecureRandom.hex(6)
      
      # Add validation metadata to params
      @params.merge({
        validation_id: SecureRandom.hex(4),
        validated_at: Time.now
      })
    end

    def exec(order_data)
      puts "📝 [#{Time.now.strftime('%H:%M:%S')}] Validating order #{order_data[:validation_id]}..."
      
      # Simulate validation checks
      return :missing_customer if !order_data[:customer_id]
      return :invalid_items if !order_data[:items] || order_data[:items].empty?
      return :invalid_total if !order_data[:total] || order_data[:total] <= 0
      
      # Simulate network failure for retry demo
      if rand < 0.3
        raise StandardError, "Validation service timeout"
      end
      
      :valid_order
    end

    def post(state, params, result)
      duration = Time.now - state[:validation_start]
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Validation completed in #{duration.round(3)}s: #{result}"
      
      state[:validation_result] = result
      state[:validation_duration] = duration
    end

    def exec_fallback(params, exception)
      puts "⚠️  [#{Time.now.strftime('%H:%M:%S')}] Validation failed after retries: #{exception.message}"
      :validation_failed
    end
  end

  class InventoryCheckNode < FlowNodes::Node
    def prep(state)
      puts "📦 [#{Time.now.strftime('%H:%M:%S')}] Checking inventory..."
      state[:inventory_check_start] = Time.now
      nil
    end

    def exec(order_data)
      puts "🔍 [#{Time.now.strftime('%H:%M:%S')}] Checking #{order_data[:items].length} items..."
      
      # Simulate inventory check
      order_data[:items].each do |item|
        puts "   - #{item[:name]}: #{item[:quantity]} units"
      end
      
      sleep(0.1) # Simulate processing time
      
      # Simulate out of stock scenario
      if order_data[:items].any? { |item| item[:quantity] > 10 }
        return :out_of_stock
      end
      
      :inventory_available
    end

    def post(state, params, result)
      duration = Time.now - state[:inventory_check_start]
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Inventory check completed: #{result}"
      
      state[:inventory_result] = result
      state[:inventory_duration] = duration
    end
  end

  class PaymentProcessingNode < FlowNodes::Node
    def prep(state)
      puts "💳 [#{Time.now.strftime('%H:%M:%S')}] Processing payment..."
      state[:payment_start] = Time.now
      
      # Add payment metadata
      @params.merge({
        payment_id: SecureRandom.hex(8),
        processor: "stripe"
      })
    end

    def exec(order_data)
      puts "💰 [#{Time.now.strftime('%H:%M:%S')}] Processing $#{order_data[:total]} payment..."
      puts "📊 Payment ID: #{order_data[:payment_id]}"
      
      # Simulate payment processing
      sleep(0.2)
      
      # Simulate payment failure
      if order_data[:total] > 1000
        return :payment_declined
      end
      
      :payment_successful
    end

    def post(state, params, result)
      duration = Time.now - state[:payment_start]
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Payment processing completed: #{result}"
      
      state[:payment_result] = result
      state[:payment_duration] = duration
    end
  end

  class OrderFulfillmentNode < FlowNodes::Node
    def prep(state)
      puts "🚚 [#{Time.now.strftime('%H:%M:%S')}] Starting order fulfillment..."
      state[:fulfillment_start] = Time.now
      
      @params.merge({
        tracking_id: SecureRandom.hex(10),
        estimated_delivery: Time.now + (3 * 24 * 60 * 60) # 3 days
      })
    end

    def exec(order_data)
      puts "📦 [#{Time.now.strftime('%H:%M:%S')}] Fulfilling order..."
      puts "📊 Tracking ID: #{order_data[:tracking_id]}"
      puts "🚚 Estimated delivery: #{order_data[:estimated_delivery].strftime('%Y-%m-%d')}"
      
      # Simulate fulfillment
      sleep(0.1)
      
      :order_shipped
    end

    def post(state, params, result)
      duration = Time.now - state[:fulfillment_start]
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Order fulfilled in #{duration.round(3)}s"
      
      state[:fulfillment_result] = result
      state[:fulfillment_duration] = duration
    end
  end

  class ErrorHandlerNode < FlowNodes::Node
    def prep(state)
      puts "🚨 [#{Time.now.strftime('%H:%M:%S')}] Handling error condition..."
      state[:error_start] = Time.now
      nil
    end

    def exec(order_data)
      error_type = @params[:error_type] || "unknown_error"
      puts "❌ [#{Time.now.strftime('%H:%M:%S')}] Error: #{error_type}"
      puts "📊 Order ID: #{order_data[:validation_id] || 'N/A'}"
      
      # Log error for monitoring
      puts "📋 Error logged for investigation"
      
      :error_handled
    end

    def post(state, params, result)
      duration = Time.now - state[:error_start]
      puts "🔧 [#{Time.now.strftime('%H:%M:%S')}] Error handling completed in #{duration.round(3)}s"
      
      state[:error_handled] = true
      state[:error_duration] = duration
    end
  end

  class CompletionNode < FlowNodes::Node
    def prep(state)
      puts "🎯 [#{Time.now.strftime('%H:%M:%S')}] Finalizing order..."
      state[:completion_start] = Time.now
      nil
    end

    def exec(order_data)
      puts "🎉 [#{Time.now.strftime('%H:%M:%S')}] Order completed successfully!"
      puts "📊 Final order data:"
      puts "   - Order ID: #{order_data[:validation_id] || 'N/A'}"
      puts "   - Payment ID: #{order_data[:payment_id] || 'N/A'}"
      puts "   - Tracking ID: #{order_data[:tracking_id] || 'N/A'}"
      puts "   - Total: $#{order_data[:total] || 'N/A'}"
      
      nil # End flow
    end

    def post(state, params, result)
      duration = Time.now - state[:completion_start]
      
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Order workflow completed!"
      puts "📊 Performance metrics:"
      if state[:validation_start]
        total_duration = Time.now - state[:validation_start]
        puts "   - Total time: #{total_duration.round(3)}s"
      end
      puts "   - Validation: #{state[:validation_duration]&.round(3)}s"
      puts "   - Inventory: #{state[:inventory_duration]&.round(3)}s"
      puts "   - Payment: #{state[:payment_duration]&.round(3)}s"
      puts "   - Fulfillment: #{state[:fulfillment_duration]&.round(3)}s"
    end
  end
end

# Demo script
if $PROGRAM_NAME == __FILE__
  # Create nodes
  validator = AdvancedWorkflow::OrderValidationNode.new
  inventory = AdvancedWorkflow::InventoryCheckNode.new
  payment = AdvancedWorkflow::PaymentProcessingNode.new
  fulfillment = AdvancedWorkflow::OrderFulfillmentNode.new
  error_handler = AdvancedWorkflow::ErrorHandlerNode.new
  completion = AdvancedWorkflow::CompletionNode.new

  # Connect workflow with symbol-based actions
  validator - :valid_order >> inventory
  validator - :missing_customer >> error_handler
  validator - :invalid_items >> error_handler
  validator - :invalid_total >> error_handler
  validator - :validation_failed >> error_handler
  
  inventory - :inventory_available >> payment
  inventory - :out_of_stock >> error_handler
  
  payment - :payment_successful >> fulfillment
  payment - :payment_declined >> error_handler
  
  fulfillment - :order_shipped >> completion

  # Create flow
  flow = FlowNodes::Flow.new(start: validator)

  # Test scenarios
  puts "=" * 60
  puts "🛒 E-COMMERCE ORDER PROCESSING WORKFLOW"
  puts "=" * 60

  # Scenario 1: Successful order
  puts "\n📋 SCENARIO 1: Successful Order"
  puts "-" * 40
  state = { session_id: SecureRandom.hex(4) }
  flow.set_params({
    customer_id: "cust_123",
    items: [
      { name: "Widget A", quantity: 2, price: 29.99 },
      { name: "Widget B", quantity: 1, price: 19.99 }
    ],
    total: 79.97
  })
  flow.run(state)

  # Scenario 2: Out of stock
  puts "\n📋 SCENARIO 2: Out of Stock"
  puts "-" * 40
  state = { session_id: SecureRandom.hex(4) }
  flow.set_params({
    customer_id: "cust_456",
    items: [
      { name: "Popular Item", quantity: 15, price: 49.99 }
    ],
    total: 49.99
  })
  flow.run(state)

  # Scenario 3: Invalid order
  puts "\n📋 SCENARIO 3: Invalid Order (Missing Customer)"
  puts "-" * 40
  state = { session_id: SecureRandom.hex(4) }
  flow.set_params({
    items: [
      { name: "Widget C", quantity: 1, price: 39.99 }
    ],
    total: 39.99
  })
  flow.run(state)

  puts "\n" + "=" * 60
  puts "🎯 WORKFLOW DEMONSTRATIONS COMPLETE"
  puts "=" * 60
end