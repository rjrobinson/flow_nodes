# frozen_string_literal: true

require_relative "../lib/flow_nodes"
require "securerandom"

module WorkflowDemo
  class DataValidationNode < FlowNodes::Node
    def prep(state)
      puts "🔍 Starting validation process..."
      state[:validation_start] = Time.now
      nil # Use node's own params
    end

    def exec(data)
      puts "📝 Validating data: #{data.inspect}"
      return :invalid if data.nil? || data.empty?
      return :invalid unless data.is_a?(Hash)
      return :invalid unless data.key?(:email) && data.key?(:name)

      :valid
    end

    def post(state, params, result)
      duration = Time.now - state[:validation_start]
      puts "✅ Validation completed in #{duration.round(3)}s with result: #{result}"
      state[:validation_result] = result
    end
  end

  class ProcessDataNode < FlowNodes::Node
    def prep(state)
      puts "⚙️  Preparing data processing..."
      state[:processing_start] = Time.now
      # Transform params - add processing metadata
      @params.merge({
        processing_id: SecureRandom.hex(8),
        processed_at: Time.now
      })
    end

    def exec(data)
      puts "⚡ Processing data for #{data[:name]} (#{data[:email]})"
      puts "📊 Processing ID: #{data[:processing_id]}"
      
      # Simulate processing work
      sleep(0.1)
      
      data[:processed] = true
      data[:processed_at] = Time.now
      :success
    end

    def post(state, params, result)
      duration = Time.now - state[:processing_start]
      puts "✅ Processing completed in #{duration.round(3)}s"
      state[:processed_count] = (state[:processed_count] || 0) + 1
    end
  end

  class SendEmailNode < FlowNodes::Node
    def prep(state)
      puts "📧 Preparing email service..."
      state[:email_attempts] = (state[:email_attempts] || 0) + 1
      nil
    end

    def exec(data)
      puts "📤 Sending welcome email to #{data[:email]}"
      puts "📊 Processing ID: #{data[:processing_id]}"
      
      # Simulate email sending
      sleep(0.1)
      
      :email_sent
    end

    def post(state, params, result)
      puts "✅ Email sent successfully"
      state[:emails_sent] = (state[:emails_sent] || 0) + 1
      state[:last_email_sent] = Time.now
    end
  end

  class ErrorHandlerNode < FlowNodes::Node
    def prep(state)
      puts "🚨 Error handling activated..."
      state[:error_count] = (state[:error_count] || 0) + 1
      nil
    end

    def exec(data)
      puts "❌ Error: Invalid data received - #{data}"
      puts "📊 Total errors handled: #{@params[:error_count] || 0}"
      :error_handled
    end

    def post(state, params, result)
      puts "🔧 Error handling completed"
      state[:last_error_handled] = Time.now
    end
  end

  class CompletionNode < FlowNodes::Node
    def prep(state)
      puts "🎯 Finalizing workflow..."
      state[:completion_start] = Time.now
      nil
    end

    def exec(data)
      puts "🎉 Workflow completed successfully for #{data[:name]}"
      puts "📊 Processing ID: #{data[:processing_id]}"
      puts "📈 Final data: #{data}"
      nil # End the flow
    end

    def post(state, params, result)
      duration = Time.now - state[:completion_start]
      puts "✅ Workflow finalized in #{duration.round(3)}s"
      puts "📊 Final state: #{state}"
    end
  end
end

# Demo script
if $PROGRAM_NAME == __FILE__
  # Create nodes
  validator = WorkflowDemo::DataValidationNode.new
  processor = WorkflowDemo::ProcessDataNode.new
  emailer = WorkflowDemo::SendEmailNode.new
  error_handler = WorkflowDemo::ErrorHandlerNode.new
  completion = WorkflowDemo::CompletionNode.new

  # Connect the workflow using symbols
  validator - :valid >> processor
  validator - :invalid >> error_handler
  processor - :success >> emailer  
  emailer - :email_sent >> completion

  # Create flow
  flow = FlowNodes::Flow.new(start: validator)

  # Test with valid data
  puts "=== Testing with valid data ==="
  state = { workflow_id: SecureRandom.hex(4) }
  flow.set_params({ email: "user@example.com", name: "John Doe" })
  flow.run(state)

  puts "\n=== Testing with invalid data ==="
  state = { workflow_id: SecureRandom.hex(4) }
  flow.set_params({ invalid: "data" })
  flow.run(state)

  puts "\n=== Testing with nil data ==="
  state = { workflow_id: SecureRandom.hex(4) }
  flow.set_params(nil)
  flow.run(state)
end