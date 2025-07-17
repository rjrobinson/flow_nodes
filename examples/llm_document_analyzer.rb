# frozen_string_literal: true

require_relative "../lib/flow_nodes"
require "json"
require "securerandom"

# Simple LLM Document Analysis Pipeline
# This demonstrates the core patterns for LLM integration with FlowNodes:
# 1. Document ingestion
# 2. LLM analysis with proper error handling
# 3. Result formatting and delivery
# 4. Symbol-based flow control

module LLMDocumentAnalyzer
  # Mock LLM service
  class LLMService
    def self.analyze_document(content, analysis_type = "summary")
      case analysis_type
      when "summary"
        { 
          summary: content.split('.').first(2).join('.') + '.',
          word_count: content.split.length,
          key_themes: ["productivity", "analysis", "automation"]
        }
      when "sentiment"
        {
          sentiment: content.include?("good") ? "positive" : "neutral",
          confidence: 0.85,
          emotional_tone: "professional"
        }
      when "extract_entities"
        {
          people: content.scan(/\b[A-Z][a-z]+ [A-Z][a-z]+\b/),
          organizations: content.scan(/\b[A-Z][a-z]+ Inc\.|Corp\.|LLC\b/),
          dates: content.scan(/\d{4}-\d{2}-\d{2}/)
        }
      else
        { error: "Unknown analysis type: #{analysis_type}" }
      end
    end
  end

  class DocumentIngestionNode < FlowNodes::Node
    def prep(state)
      puts "📄 Starting document ingestion..."
      state[:start_time] = Time.now
      nil
    end

    def exec(params)
      puts "📊 Loading document: #{params[:document_path] || 'sample.txt'}"
      
      # Mock document content
      document = {
        id: SecureRandom.hex(4),
        content: "This is a sample document for analysis. It contains good information about productivity and automation tools. The document discusses various approaches to streamline workflows and improve efficiency.",
        metadata: {
          title: "Sample Document",
          author: "John Smith",
          created_at: "2024-01-15",
          word_count: 31
        }
      }
      
      puts "✅ Document loaded successfully"
      
      # Store document for next node
      @params.merge!(document: document)
      
      :document_loaded
    end

    def post(state, params, result)
      puts "📈 Document ingestion completed"
    end
  end

  class LLMAnalysisNode < FlowNodes::Node
    def initialize(analysis_type: "summary")
      super(max_retries: 3, wait: 1)
      @analysis_type = analysis_type
    end

    def prep(state)
      puts "🤖 Starting LLM analysis: #{@analysis_type}"
      state[:llm_start] = Time.now
      nil
    end

    def exec(params)
      document = params[:document]
      
      unless document
        puts "❌ No document found in params"
        return :missing_document
      end
      
      puts "🧠 Analyzing document: #{document[:id]}"
      
      # Call LLM service
      analysis_result = LLMService.analyze_document(document[:content], @analysis_type)
      
      puts "✅ LLM analysis completed"
      
      # Store analysis result
      @params.merge!(analysis: analysis_result)
      
      :analysis_completed
    end

    def post(state, params, result)
      duration = Time.now - state[:llm_start]
      puts "📈 LLM analysis completed in #{duration.round(3)}s"
    end

    def exec_fallback(params, exception)
      puts "⚠️  LLM analysis failed: #{exception.message}"
      
      # Fallback analysis
      @params.merge!(analysis: { error: "LLM service unavailable", fallback: true })
      
      :analysis_failed
    end
  end

  class ResultFormattingNode < FlowNodes::Node
    def initialize(format: "json")
      super()
      @format = format
    end

    def prep(state)
      puts "📝 Formatting results as #{@format}"
      nil
    end

    def exec(params)
      document = params[:document]
      analysis = params[:analysis]
      
      formatted_result = case @format
      when "json"
        JSON.pretty_generate({
          document: document,
          analysis: analysis,
          processed_at: Time.now
        })
      when "summary"
        """
Document Analysis Results
========================

Document: #{document[:metadata][:title]}
Author: #{document[:metadata][:author]}
Analysis Type: summary

Results:
#{analysis.map { |k, v| "#{k}: #{v}" }.join("\n")}

Processed at: #{Time.now}
"""
      else
        "Analysis completed for document #{document[:id]}"
      end
      
      puts "✅ Results formatted successfully"
      
      @params.merge!(formatted_result: formatted_result)
      
      :results_formatted
    end

    def post(state, params, result)
      puts "📈 Results formatting completed"
    end
  end

  class OutputDeliveryNode < FlowNodes::Node
    def prep(state)
      puts "📤 Preparing output delivery"
      nil
    end

    def exec(params)
      puts "🚀 Delivering results..."
      
      # Display results
      puts "\n" + "="*50
      puts "📋 DOCUMENT ANALYSIS RESULTS"
      puts "="*50
      puts params[:formatted_result]
      puts "="*50
      
      puts "\n✅ Analysis pipeline completed successfully!"
      
      nil # End flow
    end

    def post(state, params, result)
      if state[:start_time]
        total_duration = Time.now - state[:start_time]
        puts "📈 Total pipeline duration: #{total_duration.round(3)}s"
      end
    end
  end

  class ErrorHandlerNode < FlowNodes::Node
    def prep(state)
      puts "🚨 Handling analysis error"
      nil
    end

    def exec(params)
      puts "❌ LLM analysis failed, providing fallback response"
      
      # Simple fallback
      @params.merge!(
        formatted_result: "Document analysis failed. Please try again later."
      )
      
      :error_handled
    end

    def post(state, params, result)
      puts "🔧 Error handling completed"
    end
  end
end

# Demo showing LLM document analysis
if $PROGRAM_NAME == __FILE__
  puts "🤖 LLM DOCUMENT ANALYSIS PIPELINE"
  puts "=" * 45

  # Create nodes
  ingestion = LLMDocumentAnalyzer::DocumentIngestionNode.new
  analysis = LLMDocumentAnalyzer::LLMAnalysisNode.new(analysis_type: "summary")
  formatting = LLMDocumentAnalyzer::ResultFormattingNode.new(format: "summary")
  delivery = LLMDocumentAnalyzer::OutputDeliveryNode.new
  error_handler = LLMDocumentAnalyzer::ErrorHandlerNode.new

  # Connect with symbol-based routing
  ingestion - :document_loaded >> analysis
  analysis - :analysis_completed >> formatting
  analysis - :analysis_failed >> error_handler
  formatting - :results_formatted >> delivery
  error_handler - :error_handled >> delivery

  # Create flow
  flow = FlowNodes::Flow.new(start: ingestion)
  
  # Test successful analysis
  puts "\n📋 SCENARIO 1: Successful Document Analysis"
  puts "-" * 40
  state = { pipeline_id: SecureRandom.hex(4) }
  flow.set_params(document_path: "sample_document.txt")
  flow.run(state)

  # Test with different analysis type
  puts "\n📋 SCENARIO 2: Sentiment Analysis"
  puts "-" * 40
  sentiment_analysis = LLMDocumentAnalyzer::LLMAnalysisNode.new(analysis_type: "sentiment")
  json_formatting = LLMDocumentAnalyzer::ResultFormattingNode.new(format: "json")

  # Create new flow for sentiment analysis
  ingestion - :document_loaded >> sentiment_analysis
  sentiment_analysis - :analysis_completed >> json_formatting
  json_formatting - :results_formatted >> delivery

  flow2 = FlowNodes::Flow.new(start: ingestion)
  state2 = { pipeline_id: SecureRandom.hex(4) }
  flow2.set_params(document_path: "sentiment_test.txt")
  flow2.run(state2)

  puts "\n🎯 All document analysis scenarios completed!"
end