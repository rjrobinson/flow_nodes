# frozen_string_literal: true

require_relative "../lib/flow_nodes"
require "json"
require "securerandom"

# Example: Multi-LLM Content Processing Pipeline
# This demonstrates a sophisticated content processing workflow with:
# - Document ingestion and preprocessing
# - Multi-LLM analysis (summarization, sentiment, classification)
# - Content transformation and formatting
# - Batch processing for multiple documents

module LLMContentProcessor
  # Mock LLM services with different capabilities
  class LLMService
    def self.summarize(text, max_length: 200)
      # Simulate OpenAI/Claude summarization
      sentences = text.split(/[.!?]/).reject(&:empty?)
      key_sentences = sentences.first(3).join(". ") + "."
      
      if key_sentences.length > max_length
        key_sentences = key_sentences[0..max_length-4] + "..."
      end
      
      {
        summary: key_sentences,
        original_length: text.length,
        compressed_ratio: (key_sentences.length.to_f / text.length * 100).round(2),
        key_points: extract_key_points(text)
      }
    end

    def self.analyze_sentiment(text)
      # Simulate sentiment analysis
      positive_words = %w[good great excellent amazing wonderful fantastic success]
      negative_words = %w[bad terrible awful horrible disappointing failed problem]
      
      words = text.downcase.split(/\W+/)
      positive_count = words.count { |w| positive_words.include?(w) }
      negative_count = words.count { |w| negative_words.include?(w) }
      
      if positive_count > negative_count
        sentiment = "positive"
        confidence = [(positive_count.to_f / words.length * 100), 95].min
      elsif negative_count > positive_count
        sentiment = "negative"  
        confidence = [(negative_count.to_f / words.length * 100), 95].min
      else
        sentiment = "neutral"
        confidence = 60
      end
      
      {
        sentiment: sentiment,
        confidence: confidence.round(2),
        positive_indicators: positive_count,
        negative_indicators: negative_count,
        emotional_tone: determine_emotional_tone(sentiment, confidence)
      }
    end

    def self.classify_content(text)
      # Simulate content classification
      if text.include?("technical") || text.include?("code") || text.include?("API")
        category = "technical"
      elsif text.include?("business") || text.include?("revenue") || text.include?("strategy")
        category = "business"
      elsif text.include?("news") || text.include?("announcement") || text.include?("update")
        category = "news"
      else
        category = "general"
      end
      
      {
        category: category,
        confidence: 85.0,
        tags: extract_tags(text),
        complexity: determine_complexity(text)
      }
    end

    def self.transform_content(text, target_format:, target_audience: "general")
      # Simulate content transformation
      case target_format
      when "executive_summary"
        {
          format: "executive_summary",
          content: "Executive Summary: #{text.split('.').first}. Key implications and recommendations follow.",
          target_audience: target_audience,
          word_count: 150
        }
      when "social_media"
        {
          format: "social_media",
          content: "🚀 #{text.split('.').first}! #innovation #update",
          target_audience: target_audience,
          word_count: 25
        }
      when "technical_doc"
        {
          format: "technical_doc",
          content: "## Technical Overview\n\n#{text}\n\n### Implementation Details\n\n[Technical details would follow...]",
          target_audience: target_audience,
          word_count: text.split.length + 50
        }
      else
        {
          format: "standard",
          content: text,
          target_audience: target_audience,
          word_count: text.split.length
        }
      end
    end

    private

    def self.extract_key_points(text)
      sentences = text.split(/[.!?]/).reject(&:empty?)
      sentences.first(3).map.with_index { |s, i| "#{i+1}. #{s.strip}" }
    end

    def self.determine_emotional_tone(sentiment, confidence)
      case sentiment
      when "positive"
        confidence > 80 ? "enthusiastic" : "optimistic"
      when "negative"
        confidence > 80 ? "critical" : "concerned"
      else
        "balanced"
      end
    end

    def self.extract_tags(text)
      # Simple tag extraction
      words = text.downcase.split(/\W+/).reject { |w| w.length < 4 }
      words.uniq.first(5)
    end

    def self.determine_complexity(text)
      avg_sentence_length = text.split(/[.!?]/).reject(&:empty?).map(&:length).sum / text.split(/[.!?]/).reject(&:empty?).length.to_f
      
      if avg_sentence_length > 100
        "high"
      elsif avg_sentence_length > 50
        "medium"
      else
        "low"
      end
    end
  end

  class DocumentIngestionNode < FlowNodes::Node
    def prep(state)
      puts "📄 [#{Time.now.strftime('%H:%M:%S')}] Starting document ingestion..."
      state[:ingestion_start] = Time.now
      state[:documents_processed] = 0
      nil
    end

    def exec(params)
      puts "📊 [#{Time.now.strftime('%H:%M:%S')}] Processing document source: #{params[:source]}..."
      
      # Simulate document ingestion
      sleep(0.1)
      
      # Mock document content
      documents = [
        {
          id: "doc_1",
          title: "Quarterly Business Review",
          content: "Our business has shown excellent growth this quarter. Revenue increased by 25% compared to last quarter. The technical team delivered amazing new features that customers love. Success metrics indicate positive user engagement.",
          source: params[:source],
          metadata: {
            author: "business_team",
            created_at: "2024-01-15T10:00:00Z",
            word_count: 35
          }
        },
        {
          id: "doc_2", 
          title: "Technical API Documentation Update",
          content: "The new API endpoints have been implemented with improved performance. Technical documentation has been updated to reflect the latest changes. Code examples and integration guides are now available.",
          source: params[:source],
          metadata: {
            author: "engineering_team",
            created_at: "2024-01-15T14:30:00Z",
            word_count: 28
          }
        }
      ]
      
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Ingested #{documents.length} documents"
      
      # Return documents for processing
      { documents: documents }
    end

    def post(state, params, result)
      duration = Time.now - state[:ingestion_start]
      doc_count = result[:documents]&.length || 0
      state[:documents_processed] = doc_count
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Ingested #{doc_count} documents in #{duration.round(3)}s"
      
      # Return symbol for routing
      :documents_ingested
    end
  end

  class LLMAnalysisNode < FlowNodes::AsyncBatchNode
    def initialize(analysis_type: "summarize")
      super(max_retries: 2, wait: 0.5)
      @analysis_type = analysis_type
    end

    def prep_async(state)
      puts "🤖 [#{Time.now.strftime('%H:%M:%S')}] Starting LLM analysis: #{@analysis_type}..."
      state[:analysis_start] = Time.now
      state[:llm_calls] = 0
      
      # Extract documents from the result
      @params[:documents] || []
    end

    def exec_async(document)
      puts "🧠 [#{Time.now.strftime('%H:%M:%S')}] Analyzing document: #{document[:id]} (#{@analysis_type})"
      
      # Simulate LLM processing time
      sleep(0.1)
      
      # Call appropriate LLM service
      analysis_result = case @analysis_type
      when "summarize"
        LLMService.summarize(document[:content])
      when "sentiment"
        LLMService.analyze_sentiment(document[:content])
      when "classify"
        LLMService.classify_content(document[:content])
      else
        { error: "Unknown analysis type: #{@analysis_type}" }
      end
      
      # Merge analysis with document
      document.merge({
        analysis: analysis_result,
        analysis_type: @analysis_type,
        analyzed_at: Time.now
      })
    end

    def post_async(state, params, results)
      duration = Time.now - state[:analysis_start]
      successful_analyses = results.count { |r| !r.dig(:analysis, :error) }
      state[:llm_calls] = results.length
      
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] LLM analysis completed: #{successful_analyses}/#{results.length} successful"
      puts "⏱️  Analysis duration: #{duration.round(3)}s"
      
      state[:analysis_duration] = duration
      state[:successful_analyses] = successful_analyses
      
      # Return symbol for routing
      :analysis_completed
    end
  end

  class ContentTransformationNode < FlowNodes::BatchNode
    def initialize(target_format: "executive_summary", target_audience: "general")
      super(max_retries: 2, wait: 0.5)
      @target_format = target_format
      @target_audience = target_audience
    end

    def prep(state)
      puts "🎨 [#{Time.now.strftime('%H:%M:%S')}] Starting content transformation to #{@target_format}..."
      state[:transformation_start] = Time.now
      
      # Get analyzed documents
      @params[:documents] || []
    end

    def exec(document)
      puts "📝 [#{Time.now.strftime('%H:%M:%S')}] Transforming document: #{document[:id]}"
      
      # Use LLM to transform content
      transformation_result = LLMService.transform_content(
        document[:content],
        target_format: @target_format,
        target_audience: @target_audience
      )
      
      document.merge({
        transformation: transformation_result,
        transformed_at: Time.now
      })
    end

    def post(state, params, results)
      duration = Time.now - state[:transformation_start]
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Content transformation completed for #{results.length} documents"
      puts "⏱️  Transformation duration: #{duration.round(3)}s"
      
      state[:transformation_duration] = duration
      
      # Return symbol for routing
      :transformation_completed
    end
  end

  class MultiLLMProcessingNode < FlowNodes::AsyncParallelBatchNode
    def initialize
      super(max_retries: 3, wait: 1)
    end

    def prep_async(state)
      puts "🚀 [#{Time.now.strftime('%H:%M:%S')}] Starting parallel multi-LLM processing..."
      state[:multi_llm_start] = Time.now
      
      # Get documents for parallel processing
      @params[:documents] || []
    end

    def exec_async(document)
      puts "⚡ [#{Time.now.strftime('%H:%M:%S')}] Processing document #{document[:id]} on thread #{Thread.current.object_id}"
      
      # Simulate parallel LLM calls
      sleep(0.2)
      
      # Run multiple LLM analyses in parallel
      summary = LLMService.summarize(document[:content])
      sentiment = LLMService.analyze_sentiment(document[:content])
      classification = LLMService.classify_content(document[:content])
      
      document.merge({
        multi_analysis: {
          summary: summary,
          sentiment: sentiment,
          classification: classification,
          thread_id: Thread.current.object_id
        },
        multi_analyzed_at: Time.now
      })
    end

    def post_async(state, params, results)
      duration = Time.now - state[:multi_llm_start]
      thread_ids = results.map { |r| r.dig(:multi_analysis, :thread_id) }.uniq
      
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Multi-LLM processing completed!"
      puts "⚡ Used #{thread_ids.length} parallel threads"
      puts "⏱️  Processing duration: #{duration.round(3)}s"
      
      state[:multi_llm_duration] = duration
      state[:threads_used] = thread_ids.length
      
      # Return symbol for routing
      :multi_analysis_completed
    end
  end

  class ResultsAggregationNode < FlowNodes::Node
    def prep(state)
      puts "📊 [#{Time.now.strftime('%H:%M:%S')}] Aggregating results..."
      state[:aggregation_start] = Time.now
      nil
    end

    def exec(processed_data)
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Generating comprehensive report..."
      
      documents = processed_data[:documents] || []
      
      # Aggregate insights
      aggregated_insights = {
        total_documents: documents.length,
        processing_summary: {
          documents_processed: documents.length,
          successful_analyses: documents.count { |d| d[:analysis] },
          transformations: documents.count { |d| d[:transformation] },
          multi_analyses: documents.count { |d| d[:multi_analysis] }
        },
        content_insights: generate_content_insights(documents),
        performance_metrics: calculate_performance_metrics(documents)
      }
      
      processed_data.merge({
        aggregated_insights: aggregated_insights,
        aggregated_at: Time.now
      })
    end

    def post(state, params, result)
      duration = Time.now - state[:aggregation_start]
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Results aggregation completed in #{duration.round(3)}s"
      state[:aggregation_duration] = duration
      
      # Return symbol for routing
      :aggregation_completed
    end

    private

    def generate_content_insights(documents)
      sentiments = documents.map { |d| d.dig(:multi_analysis, :sentiment, :sentiment) }.compact
      categories = documents.map { |d| d.dig(:multi_analysis, :classification, :category) }.compact
      
      {
        sentiment_distribution: sentiments.group_by(&:itself).transform_values(&:count),
        category_distribution: categories.group_by(&:itself).transform_values(&:count),
        avg_compression_ratio: documents.map { |d| d.dig(:multi_analysis, :summary, :compressed_ratio) }.compact.sum / documents.length.to_f
      }
    end

    def calculate_performance_metrics(documents)
      {
        total_processing_time: documents.sum { |d| 0.3 }, # Simulated
        avg_processing_time_per_doc: 0.3,
        llm_calls_made: documents.length * 3, # Summary + sentiment + classification
        success_rate: (documents.count { |d| d[:multi_analysis] }.to_f / documents.length * 100).round(2)
      }
    end
  end

  class OutputFormattingNode < FlowNodes::Node
    def initialize(output_format: "comprehensive_report")
      super()
      @output_format = output_format
    end

    def prep(state)
      puts "📝 [#{Time.now.strftime('%H:%M:%S')}] Formatting final output as #{@output_format}..."
      state[:formatting_start] = Time.now
      nil
    end

    def exec(aggregated_data)
      puts "🎨 [#{Time.now.strftime('%H:%M:%S')}] Generating final report..."
      
      formatted_output = case @output_format
      when "comprehensive_report"
        generate_comprehensive_report(aggregated_data)
      when "executive_summary"
        generate_executive_summary(aggregated_data)
      when "json"
        JSON.pretty_generate(aggregated_data)
      else
        generate_simple_report(aggregated_data)
      end
      
      aggregated_data.merge({
        formatted_output: formatted_output,
        output_format: @output_format,
        formatted_at: Time.now
      })
    end

    def post(state, params, result)
      duration = Time.now - state[:formatting_start]
      total_duration = Time.now - state[:ingestion_start]
      
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Output formatting completed in #{duration.round(3)}s"
      puts "🎯 [#{Time.now.strftime('%H:%M:%S')}] Total pipeline duration: #{total_duration.round(3)}s"
      
      # Display pipeline statistics
      puts "\n📊 PIPELINE PERFORMANCE METRICS:"
      puts "   - Document Ingestion: #{state[:documents_processed]} docs"
      puts "   - LLM Analysis: #{state[:successful_analyses]} successful"
      puts "   - Content Transformations: #{state[:transformation_duration]&.round(3)}s"
      puts "   - Multi-LLM Processing: #{state[:multi_llm_duration]&.round(3)}s"
      puts "   - Results Aggregation: #{state[:aggregation_duration]&.round(3)}s"
      puts "   - Output Formatting: #{duration.round(3)}s"
      puts "   - Total Pipeline Time: #{total_duration.round(3)}s"
      
      state[:formatting_duration] = duration
      
      # Return symbol for routing
      :output_ready
    end

    private

    def generate_comprehensive_report(data)
      insights = data[:aggregated_insights]
      
      """
📊 COMPREHENSIVE CONTENT ANALYSIS REPORT
========================================

Processing Summary:
- Total Documents: #{insights[:total_documents]}
- Successful Analyses: #{insights[:processing_summary][:successful_analyses]}
- Transformations: #{insights[:processing_summary][:transformations]}
- Multi-Analyses: #{insights[:processing_summary][:multi_analyses]}

Content Insights:
- Sentiment Distribution: #{insights[:content_insights][:sentiment_distribution]}
- Category Distribution: #{insights[:content_insights][:category_distribution]}
- Average Compression Ratio: #{insights[:content_insights][:avg_compression_ratio].round(2)}%

Performance Metrics:
- Total Processing Time: #{insights[:performance_metrics][:total_processing_time]}s
- Average Time per Document: #{insights[:performance_metrics][:avg_processing_time_per_doc]}s
- LLM Calls Made: #{insights[:performance_metrics][:llm_calls_made]}
- Success Rate: #{insights[:performance_metrics][:success_rate]}%

Generated at: #{Time.now}
"""
    end

    def generate_executive_summary(data)
      insights = data[:aggregated_insights]
      
      """
📋 EXECUTIVE SUMMARY
===================

Processed #{insights[:total_documents]} documents with #{insights[:performance_metrics][:success_rate]}% success rate.

Key Findings:
- Sentiment: #{insights[:content_insights][:sentiment_distribution]}
- Categories: #{insights[:content_insights][:category_distribution]}
- Processing Efficiency: #{insights[:performance_metrics][:avg_processing_time_per_doc]}s per document

Recommendations: Continue monitoring content quality and processing performance.
"""
    end

    def generate_simple_report(data)
      "Content processing completed for #{data[:aggregated_insights][:total_documents]} documents."
    end
  end

  class FinalDeliveryNode < FlowNodes::Node
    def prep(state)
      puts "📤 [#{Time.now.strftime('%H:%M:%S')}] Preparing final delivery..."
      state[:delivery_start] = Time.now
      nil
    end

    def exec(final_data)
      puts "🚀 [#{Time.now.strftime('%H:%M:%S')}] Delivering final results..."
      
      # Display the final formatted output
      puts "\n" + "="*80
      puts "📋 FINAL CONTENT PROCESSING RESULTS"
      puts "="*80
      puts final_data[:formatted_output]
      puts "="*80
      
      puts "\n✅ Content processing pipeline completed successfully!"
      
      nil # End of flow
    end

    def post(state, params, result)
      duration = Time.now - state[:delivery_start]
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Final delivery completed in #{duration.round(3)}s"
    end
  end
end

# Demo script showing LLM content processing workflows
if $PROGRAM_NAME == __FILE__
  puts "🤖 LLM CONTENT PROCESSING PIPELINE"
  puts "=" * 50

  # Create pipeline state
  state = {
    pipeline_id: SecureRandom.hex(4),
    user_id: "content_team",
    pipeline_start: Time.now
  }

  # Create nodes
  ingestion = LLMContentProcessor::DocumentIngestionNode.new
  llm_analysis = LLMContentProcessor::LLMAnalysisNode.new(analysis_type: "summarize")
  transformation = LLMContentProcessor::ContentTransformationNode.new(
    target_format: "executive_summary",
    target_audience: "executives"
  )
  multi_llm = LLMContentProcessor::MultiLLMProcessingNode.new
  aggregation = LLMContentProcessor::ResultsAggregationNode.new
  formatting = LLMContentProcessor::OutputFormattingNode.new(output_format: "comprehensive_report")
  delivery = LLMContentProcessor::FinalDeliveryNode.new

  # Connect the pipeline with symbol-based routing
  ingestion - :documents_ingested >> llm_analysis
  llm_analysis - :analysis_completed >> transformation
  transformation - :transformation_completed >> multi_llm
  multi_llm - :multi_analysis_completed >> aggregation
  aggregation - :aggregation_completed >> formatting
  formatting - :output_ready >> delivery

  # Create and run the flow
  flow = FlowNodes::Flow.new(start: ingestion)
  flow.set_params({ source: "document_management_system" })
  flow.run(state)

  puts "\n🎯 LLM Content Processing Pipeline Completed!"
  puts "Pipeline ID: #{state[:pipeline_id]}"
  puts "Total Runtime: #{(Time.now - state[:pipeline_start]).round(3)}s"
end