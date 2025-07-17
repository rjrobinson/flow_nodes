# frozen_string_literal: true

require_relative "../lib/flow_nodes"
require "securerandom"

module ChatDemo
  # Simple utility to simulate an LLM call
  module Utils
    def self.call_llm(messages)
      # In a real implementation, this would call OpenAI, Claude, etc.
      # For demo purposes, we'll just echo the last user message
      last_user_message = messages.reverse.find { |msg| msg[:role] == :user }
      return "I heard you say: #{last_user_message[:content]}" if last_user_message

      "Hello! How can I help you today?"
    end
  end

  class ChatNode < FlowNodes::Node
    # Initialize messages array + prompt for user input.
    def prep(shared)
      unless shared.key?(:messages)
        shared[:messages] = []
        shared[:chat_session_id] = SecureRandom.hex(8)
        shared[:start_time] = Time.now
        puts "🤖 Welcome to the chat! Type 'exit' to end the conversation."
        puts "📊 Session ID: #{shared[:chat_session_id]}"
      end

      print "\nYou: "
      user_input = $stdin.gets
      return nil unless user_input # EOF (Ctrl-D)

      user_input = user_input.chomp
      return nil if user_input.strip.downcase == "exit"

      # push user message
      shared[:messages] << { role: :user, content: user_input }
      shared[:turn_count] = (shared[:turn_count] || 0) + 1
      
      puts "🔄 Processing turn #{shared[:turn_count]}..."
      shared[:messages]
    end

    # Call the LLM with full history.
    def exec(messages)
      return nil unless messages

      puts "🧠 Calling LLM with #{messages.length} messages..."
      Utils.call_llm(messages)
    end

    # Print assistant reply, store it, and loop.
    def post(shared, prep_res, exec_res)
      if prep_res.nil? || exec_res.nil?
        duration = Time.now - shared[:start_time]
        puts "\n👋 Goodbye!"
        puts "📊 Chat session stats:"
        puts "   - Session ID: #{shared[:chat_session_id]}"
        puts "   - Total turns: #{shared[:turn_count] || 0}"
        puts "   - Duration: #{duration.round(2)}s"
        puts "   - Messages: #{shared[:messages]&.length || 0}"
        return nil
      end

      puts "\n🤖 Assistant: #{exec_res}"
      shared[:messages] << { role: :assistant, content: exec_res }
      :continue
    end

    # Optional: graceful fallback on final retry failure.
    def exec_fallback(_prep_res, exc)
      puts "⚠️  LLM service unavailable: #{exc.class}: #{exc.message}"
      puts "🔄 Retrying in a moment..."
      :continue
    end
  end
end

# Demo script
if $PROGRAM_NAME == __FILE__
  shared = {}
  chat_node = ChatDemo::ChatNode.new

  # Create self-loop: when exec returns "continue", go back to same node
  chat_node - :continue >> chat_node

  # Create flow and run
  flow = FlowNodes::Flow.new(start: chat_node)
  flow.run(shared)
end