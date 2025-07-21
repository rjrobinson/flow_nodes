# frozen_string_literal: true

# Rails + FlowNodes LLM Orchestration Integration Example
# 
# This example demonstrates how to integrate FlowNodes with Rails applications
# for sophisticated LLM orchestration, including:
# - Controller integration
# - Background job processing
# - Model integration with ActiveRecord
# - Error handling and retries
# - Caching strategies
# - Environment-specific routing

require_relative "../../lib/flow_nodes"
require 'logger'
require 'digest'

# ==============================================================================
# SIMULATED RAILS ENVIRONMENT SETUP
# ==============================================================================

# Simulate Rails environment
class Rails
  def self.env
    ENV['RAILS_ENV'] || 'development'
  end

  def self.cache
    @cache ||= SimpleCache.new
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end
end

# Simple cache implementation for demo
class SimpleCache
  def initialize
    @store = {}
  end

  def fetch(key, expires_in: 3600)
    if @store[key] && @store[key][:expires_at] > Time.now
      @store[key][:value]
    else
      value = yield
      @store[key] = { value: value, expires_at: Time.now + expires_in }
      value
    end
  end

  def write(key, value, expires_in: 3600)
    @store[key] = { value: value, expires_at: Time.now + expires_in }
  end
end

# Simulated ActiveJob for background processing
module ActiveJob
  class Base
    def self.perform_later(*args)
      puts "🔄 Enqueuing job #{self.name} with args: #{args}"
      # In real Rails, this would enqueue the job
      new.perform(*args)
    end

    def perform(*args)
      raise "Not implemented"
    end
  end
end

# ==============================================================================
# LLM ORCHESTRATION NODES FOR RAILS INTEGRATION
# ==============================================================================

module LLMOrchestration
  # Base class for LLM-integrated nodes with Rails features
  class LLMNode < FlowNodes::Node

    def exec(params)
      start_time = Time.now
      result = perform_llm_operation(params)
      duration = Time.now - start_time
      
      Rails.logger&.info("#{self.class.name} completed in #{duration.round(3)}s")
      result
    rescue => e
      Rails.logger&.error("#{self.class.name} failed: #{e.message}")
      handle_error(e, params)
    end

    private

    def perform_llm_operation(params)
      raise NotImplementedError, "Subclasses must implement perform_llm_operation"
    end

    def handle_error(error, params)
      # Default error handling - can be overridden
      :error
    end
  end

  # Content Classification Node with Rails Caching
  class ContentClassifierNode < LLMNode
    def perform_llm_operation(params)
      content = params[:content] || params[:text]
      cache_key = "classifier:#{Digest::MD5.hexdigest(content.to_s)}"
      
      # Use Rails caching for expensive LLM calls
      classification = Rails.cache.fetch(cache_key, expires_in: 3600) do
        puts "🤖 [LLM] Classifying content: '#{content[0..50]}...'"
        classify_content(content)
      end

      puts "📋 Classification result: #{classification}"
      classification
    end

    private

    def classify_content(content)
      # Simulate LLM content classification
      case content.to_s.downcase
      when /question|help|how.*to|what.*is/ then :question
      when /complaint|problem|issue|bug|error/ then :complaint  
      when /praise|great|awesome|love|excellent/ then :praise
      when /request|need|want|please/ then :request
      when /urgent|asap|immediately|emergency/ then :urgent
      else :general
      end
    end
  end

  # Sentiment Analysis Node with Retry Logic
  class SentimentAnalysisNode < LLMNode
    MAX_RETRIES = 3

    def perform_llm_operation(params)
      content = params[:content] || params[:text]
      
      retries = 0
      begin
        puts "😊 [LLM] Analyzing sentiment..."
        sentiment = analyze_sentiment(content)
        
        # Store result for next nodes
        params[:sentiment] = sentiment
        params[:sentiment_score] = rand(0.1..1.0).round(2)
        
        nil # Continue to next node
      rescue => e
        retries += 1
        if retries <= MAX_RETRIES
          puts "⚠️  Retry #{retries}/#{MAX_RETRIES}: #{e.message}"
          sleep(2 ** retries) # Exponential backoff
          retry
        else
          raise e
        end
      end
    end

    private

    def analyze_sentiment(content)
      # Simulate LLM sentiment analysis
      positive_words = %w[good great excellent awesome love wonderful happy]
      negative_words = %w[bad terrible awful hate horrible sad angry]
      
      words = content.to_s.downcase.split
      positive_count = words.count { |w| positive_words.any? { |pw| w.include?(pw) } }
      negative_count = words.count { |w| negative_words.any? { |nw| w.include?(nw) } }
      
      if positive_count > negative_count
        :positive
      elsif negative_count > positive_count  
        :negative
      else
        :neutral
      end
    end
  end

  # Response Generation Node with Template Support
  class ResponseGeneratorNode < LLMNode
    def perform_llm_operation(params)
      classification = params[:classification] || :general
      sentiment = params[:sentiment] || :neutral
      content = params[:content] || params[:text]

      puts "✍️  [LLM] Generating response..."
      
      response = generate_response(classification, sentiment, content, params)
      
      # Store response for controller use
      params[:generated_response] = response
      params[:response_metadata] = {
        classification: classification,
        sentiment: sentiment,
        generated_at: Time.now,
        template_used: get_template_name(classification)
      }
      
      nil # End of flow
    end

    private

    def generate_response(classification, sentiment, content, params)
      template = get_template(classification, sentiment)
      
      # Simple template substitution (in real app, use ERB or similar)
      template
        .gsub('{{sentiment_tone}}', get_sentiment_tone(sentiment))
        .gsub('{{user_name}}', params[:user_name] || 'valued customer')
        .gsub('{{original_content}}', content[0..100])
    end

    def get_template(classification, sentiment)
      templates = {
        question: "Thank you for your question! {{sentiment_tone}} I'll help you find the answer...",
        complaint: "I understand your concern, {{user_name}}. {{sentiment_tone}} Let me help resolve this issue...",
        praise: "Thank you so much for your kind words, {{user_name}}! {{sentiment_tone}} We really appreciate it...",
        request: "I'd be happy to help with your request, {{user_name}}. {{sentiment_tone}} Here's what I can do...",
        urgent: "I see this is urgent, {{user_name}}. {{sentiment_tone}} I'm prioritizing this immediately...",
        general: "Thank you for contacting us, {{user_name}}. {{sentiment_tone}} Here's my response..."
      }
      
      templates[classification] || templates[:general]
    end

    def get_template_name(classification)
      "response_#{classification}.erb"
    end

    def get_sentiment_tone(sentiment)
      case sentiment
      when :positive then "I'm glad to hear from you!"
      when :negative then "I'm sorry you're experiencing this."
      else "I appreciate you reaching out."
      end
    end
  end

  # Content Moderation Node with Rails Integration
  class ContentModerationNode < LLMNode
    def perform_llm_operation(params)
      content = params[:content] || params[:text]
      
      puts "🔍 [LLM] Checking content moderation..."
      
      moderation_result = moderate_content(content)
      
      case moderation_result[:action]
      when :approve
        params[:moderation_status] = :approved
        :approved
      when :flag
        params[:moderation_status] = :flagged
        params[:moderation_reason] = moderation_result[:reason]
        # Queue for human review
        ContentReviewJob.perform_later(params.dup)
        :flagged
      when :block
        params[:moderation_status] = :blocked
        params[:moderation_reason] = moderation_result[:reason]
        :blocked
      end
    end

    private

    def moderate_content(content)
      # Simulate content moderation
      if content.to_s.match?(/spam|scam|fraud/i)
        { action: :block, reason: "Potential spam detected" }
      elsif content.to_s.match?(/inappropriate|offensive/i)
        { action: :flag, reason: "Content flagged for review" }
      else
        { action: :approve, reason: "Content approved" }
      end
    end
  end

  # Knowledge Base Search Node with Rails Model Integration
  class KnowledgeBaseNode < LLMNode
    def perform_llm_operation(params)
      query = extract_search_query(params[:content] || params[:text])
      
      puts "📚 [KB] Searching knowledge base for: '#{query}'"
      
      # Simulate ActiveRecord query
      results = search_knowledge_base(query)
      
      params[:kb_results] = results
      params[:kb_query] = query
      
      results.any? ? :found : :not_found
    end

    private

    def extract_search_query(content)
      # Simple keyword extraction (in real app, use NLP)
      content.to_s.downcase
        .gsub(/[^\w\s]/, '')
        .split
        .reject { |word| %w[the a an is are was were can could how what].include?(word) }
        .join(' ')
    end

    def search_knowledge_base(query)
      # Simulate database search results
      mock_articles = [
        { title: "Getting Started Guide", content: "Basic setup and configuration...", score: 0.9 },
        { title: "Troubleshooting Common Issues", content: "Solutions for frequent problems...", score: 0.7 },
        { title: "Advanced Features", content: "Power user functionality...", score: 0.5 }
      ]

      # Filter based on query relevance
      mock_articles.select { |article| article[:score] > 0.6 }
    end
  end
end

# ==============================================================================
# RAILS BACKGROUND JOBS
# ==============================================================================

class ContentReviewJob < ActiveJob::Base
  def perform(params)
    puts "👨‍💼 Human review queued for content: #{params[:content][0..50]}..."
    puts "   Reason: #{params[:moderation_reason]}"
    puts "   Status: #{params[:moderation_status]}"
    
    # In real app, this would create a review task
    # ReviewTask.create!(
    #   content: params[:content],
    #   reason: params[:moderation_reason],
    #   priority: params[:urgent] ? 'high' : 'normal'
    # )
  end
end

class LLMProcessingJob < ActiveJob::Base
  def perform(content_id, workflow_type = 'customer_support')
    puts "🚀 Processing content #{content_id} with workflow: #{workflow_type}"
    
    # Load content from database
    # content = Content.find(content_id)
    content_data = { content: "Sample content for processing", id: content_id }
    
    # Run appropriate workflow
    case workflow_type
    when 'customer_support'
      run_customer_support_workflow(content_data)
    when 'content_analysis'
      run_content_analysis_workflow(content_data) 
    else
      raise "Unknown workflow type: #{workflow_type}"
    end
  end

  private

  def run_customer_support_workflow(content_data)
    # Create node instances
    classifier = LLMOrchestration::ContentClassifierNode.new
    sentiment = LLMOrchestration::SentimentAnalysisNode.new
    moderation = LLMOrchestration::ContentModerationNode.new
    knowledge_base = LLMOrchestration::KnowledgeBaseNode.new
    responder = LLMOrchestration::ResponseGeneratorNode.new

    # Set up routing using existing method for compatibility
    # In production, you'd use FlowRoute.draw with proper node registry mapping
    
    # Moderation routing
    moderation.routes({ :approved => classifier })
    
    # Classification routing  
    classifier.routes({
      :question => knowledge_base >> responder,
      [:complaint, :urgent] => sentiment >> responder,
      :general => sentiment >> responder
    })

    # Execute workflow
    flow = FlowNodes::Flow.new(start: moderation)
    flow.set_params(content_data)
    result = flow.run(nil)
    
    puts "✅ Workflow completed for content #{content_data[:id]}"
    result
  end

  def run_content_analysis_workflow(content_data)
    puts "📊 Running content analysis workflow..."
    # Implementation would go here
  end
end

# ==============================================================================
# RAILS CONTROLLER INTEGRATION
# ==============================================================================

module RailsControllers
  # Base controller with FlowNodes integration
  class ApplicationController
    def render_json(data, status: 200)
      puts "📤 API Response (#{status}): #{data}"
    end

    def render_error(message, status: 500)
      puts "❌ API Error (#{status}): #{message}"
    end
  end

  class LLMController < ApplicationController
    # Synchronous LLM processing for real-time responses
    def process_content
      content = params[:content]
      user_id = params[:user_id]

      return render_error("Content is required", status: 400) if content.nil? || content.to_s.empty?

      begin
        # Run lightweight synchronous workflow for fast responses
        result = run_sync_llm_workflow(content, user_id)
        
        render_json({
          success: true,
          classification: result[:classification],
          sentiment: result[:sentiment],
          response: result[:generated_response],
          processed_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
        })
      rescue => e
        Rails.logger&.error("LLM processing failed: #{e.message}")
        render_error("Processing failed. Please try again.", status: 500)
      end
    end

    # Asynchronous LLM processing for complex workflows
    def analyze_content
      content_id = params[:content_id]
      workflow_type = params[:workflow_type] || 'customer_support'

      return render_error("Content ID is required", status: 400) if content_id.nil? || content_id.to_s.empty?

      begin
        # Queue background job for complex processing
        LLMProcessingJob.perform_later(content_id, workflow_type)
        
        render_json({
          success: true,
          message: "Content queued for analysis",
          content_id: content_id,
          workflow_type: workflow_type,
          queued_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
        })
      rescue => e
        Rails.logger&.error("Failed to queue LLM job: #{e.message}")
        render_error("Failed to queue analysis. Please try again.", status: 500)
      end
    end

    private

    def run_sync_llm_workflow(content, user_id)
      # Create lightweight workflow for synchronous processing
      classifier = LLMOrchestration::ContentClassifierNode.new
      sentiment = LLMOrchestration::SentimentAnalysisNode.new
      responder = LLMOrchestration::ResponseGeneratorNode.new

      # Simple chain for fast processing
      classifier >> sentiment >> responder

      # Execute workflow
      flow = FlowNodes::Flow.new(start: classifier)
      params = { 
        content: content, 
        user_id: user_id,
        user_name: "User #{user_id}" # In real app, fetch from database
      }
      
      flow.set_params(params)
      flow.run(nil)
      
      # Return processed data
      {
        classification: params[:classification],
        sentiment: params[:sentiment],
        generated_response: params[:generated_response],
        metadata: params[:response_metadata]
      }
    end

    def params
      # Simulate Rails params
      @params ||= {
        content: "I need help with billing questions",
        user_id: "user123",
        content_id: "content456",
        workflow_type: "customer_support"
      }
    end
  end
end

# ==============================================================================
# RAILS INITIALIZER FOR FLOWNODES + LLM SETUP
# ==============================================================================

module LLMInitializer
  def self.setup!
    puts "🔧 Initializing FlowNodes + LLM integration for Rails..."

    # Load environment-specific routes
    routes_file = case Rails.env
                  when 'production'
                    'config/llm_routes.rb'
                  when 'staging'
                    'config/llm_routes_staging.rb'
                  else
                    'config/llm_routes_development.rb'
                  end

    puts "📋 Loading LLM routes from: #{routes_file}"

    # Register global LLM nodes (in real app, these would be cached)
    Rails.cache.write('llm_nodes_registry', create_node_registry, expires_in: 3600)
    
    puts "✅ FlowNodes + LLM integration initialized successfully!"
  end

  private

  def self.create_node_registry
    {
      content_classifier: LLMOrchestration::ContentClassifierNode.new,
      sentiment_analyzer: LLMOrchestration::SentimentAnalysisNode.new,
      content_moderator: LLMOrchestration::ContentModerationNode.new,
      knowledge_base: LLMOrchestration::KnowledgeBaseNode.new,
      response_generator: LLMOrchestration::ResponseGeneratorNode.new
    }
  end
end

# ==============================================================================
# DEMONSTRATION
# ==============================================================================

if $PROGRAM_NAME == __FILE__
  puts "🚀 RAILS + FLOWNODES LLM ORCHESTRATION DEMO"
  puts "=" * 60

  # Initialize the Rails + LLM system
  LLMInitializer.setup!

  puts "\n🎯 SCENARIO 1: Synchronous LLM Processing"
  puts "-" * 50
  
  controller = RailsControllers::LLMController.new
  puts "📥 Processing customer support request..."
  controller.process_content

  puts "\n🎯 SCENARIO 2: Asynchronous LLM Processing"
  puts "-" * 50
  
  puts "📥 Queueing content for complex analysis..."
  controller.analyze_content

  puts "\n🎯 SCENARIO 3: Environment-Specific Configuration"
  puts "-" * 50
  
  puts "🌍 Current environment: #{Rails.env}"
  puts "📋 Routes file: config/llm_routes_#{Rails.env}.rb"
  puts "🔄 Cache strategy: #{Rails.env == 'production' ? 'Redis' : 'Memory'}"
  puts "📊 Logging level: #{Rails.env == 'production' ? 'INFO' : 'DEBUG'}"

  puts "\n" + "=" * 60
  puts "🎯 RAILS INTEGRATION BENEFITS"
  puts "-" * 40
  puts "✅ Controller Integration: Direct API endpoints for LLM workflows"
  puts "✅ Background Jobs: Complex processing without blocking requests"
  puts "✅ ActiveRecord Integration: Seamless database operations"
  puts "✅ Rails Caching: Expensive LLM calls cached automatically"
  puts "✅ Environment Configuration: Different routes per environment"
  puts "✅ Error Handling: Rails-native error handling and logging"
  puts "✅ Retry Logic: Exponential backoff for LLM API failures"
  puts "✅ Template Support: Rails views/templates for responses"
  puts "✅ Middleware Support: Authentication, rate limiting, etc."
  puts "✅ Monitoring: Rails APM tools work out-of-the-box"

  puts "\n📚 NEXT STEPS FOR PRODUCTION:"
  puts "-" * 30
  puts "1. Configure Redis for caching and job queues"
  puts "2. Set up LLM API credentials (OpenAI, Claude, etc.)"
  puts "3. Implement proper error monitoring (Sentry, Rollbar)"
  puts "4. Add rate limiting for LLM endpoints"
  puts "5. Set up background job monitoring (Sidekiq Web UI)"
  puts "6. Configure environment-specific LLM models"
  puts "7. Implement content persistence and audit trails"
  puts "8. Add comprehensive logging and metrics"

  puts "\n🚀 FlowNodes + Rails = Production-Ready LLM Orchestration!"
end