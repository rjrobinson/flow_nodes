# frozen_string_literal: true

require_relative "../lib/flow_nodes"
require "json"
require "time"
require "securerandom"

# Example: Calendar Data Processing with LLM Integration
# This demonstrates parsing calendar data, extracting insights with LLM,
# and formatting results - a common MCP (Model Context Protocol) pattern

module LLMCalendarParser
  # Mock LLM service - in real usage, this would call OpenAI, Claude, etc.
  class MockLLMService
    def self.call(prompt, context = {})
      # Simulate LLM processing with realistic responses
      if prompt.include?("extract key information")
        extract_calendar_info(context[:events])
      elsif prompt.include?("suggest optimizations")
        suggest_optimizations(context[:events])
      elsif prompt.include?("format as")
        format_events(context[:events], context[:format])
      else
        "I understand you want me to process calendar data."
      end
    end

    private

    def self.extract_calendar_info(events)
      busy_hours = events.map { |e| e[:duration] || 1 }.sum
      conflicts = events.select { |e| e[:title].downcase.include?("conflict") }.length
      
      {
        summary: "Found #{events.length} events totaling #{busy_hours} hours",
        busy_hours: busy_hours,
        conflicts: conflicts,
        busiest_day: events.group_by { |e| e[:date] }.max_by { |_, v| v.length }&.first,
        meeting_types: events.map { |e| e[:type] }.uniq.compact
      }
    end

    def self.suggest_optimizations(events)
      suggestions = []
      
      # Back-to-back meetings
      if events.any? { |e| e[:title].include?("Back-to-back") }
        suggestions << "Consider adding buffer time between meetings"
      end
      
      # Too many meetings in one day
      busy_days = events.group_by { |e| e[:date] }.select { |_, v| v.length > 5 }
      if busy_days.any?
        suggestions << "Consider redistributing meetings from busy days: #{busy_days.keys.join(', ')}"
      end
      
      # Long meetings
      long_meetings = events.select { |e| (e[:duration] || 1) > 2 }
      if long_meetings.any?
        suggestions << "Review necessity of long meetings: #{long_meetings.map { |e| e[:title] }.join(', ')}"
      end
      
      suggestions.empty? ? ["Schedule looks well optimized!"] : suggestions
    end

    def self.format_events(events, format)
      return "No events to format" if events.nil? || events.empty?
      
      case format
      when "executive_summary"
        total_time = events.sum { |e| e[:duration] || 1 }
        "Executive Summary: #{events.length} meetings scheduled, #{total_time} total hours"
      when "daily_agenda"
        events.group_by { |e| e[:date] }.map do |date, day_events|
          "#{date}: #{day_events.length} events (#{day_events.sum { |e| e[:duration] || 1 }}h)"
        end.join("\n")
      when "json"
        JSON.pretty_generate(events)
      else
        events.map { |e| "#{e[:date]} #{e[:time]}: #{e[:title]}" }.join("\n")
      end
    end
  end

  class CalendarDataIngestionNode < FlowNodes::Node
    def prep(state)
      puts "📅 [#{Time.now.strftime('%H:%M:%S')}] Starting calendar data ingestion..."
      state[:ingestion_start] = Time.now
      state[:source] = "calendar_api"
      nil
    end

    def exec(params)
      puts "📊 [#{Time.now.strftime('%H:%M:%S')}] Ingesting calendar data from #{params[:source] || 'default source'}..."
      
      # Simulate calendar data ingestion
      sleep(0.1)
      
      # Mock calendar events
      events = [
        {
          id: "evt_1",
          title: "Team Standup",
          date: "2024-01-15",
          time: "09:00",
          duration: 0.5,
          type: "recurring",
          attendees: ["alice@company.com", "bob@company.com"]
        },
        {
          id: "evt_2", 
          title: "Project Planning Session",
          date: "2024-01-15",
          time: "10:00",
          duration: 2,
          type: "planning",
          attendees: ["alice@company.com", "charlie@company.com"]
        },
        {
          id: "evt_3",
          title: "Back-to-back Client Call",
          date: "2024-01-15", 
          time: "14:00",
          duration: 1,
          type: "external",
          attendees: ["client@external.com"]
        },
        {
          id: "evt_4",
          title: "Code Review",
          date: "2024-01-16",
          time: "11:00",
          duration: 1,
          type: "technical",
          attendees: ["dev@company.com"]
        }
      ]
      
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Ingested #{events.length} calendar events"
      
      # Store events in params for next node
      @params.merge!({ events: events })
      
      # Return symbol for flow routing
      :data_ingested
    end

    def post(state, params, result)
      duration = Time.now - state[:ingestion_start]
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Ingestion completed in #{duration.round(3)}s"
      state[:ingestion_duration] = duration
    end
  end

  class LLMAnalysisNode < FlowNodes::Node
    def initialize(analysis_type: "extract")
      super(max_retries: 3, wait: 1)
      @analysis_type = analysis_type
    end

    def prep(state)
      puts "🤖 [#{Time.now.strftime('%H:%M:%S')}] Starting LLM analysis: #{@analysis_type}..."
      state[:analysis_start] = Time.now
      state[:llm_calls] = (state[:llm_calls] || 0) + 1
      
      # Add analysis metadata to params
      @params.merge({
        analysis_type: @analysis_type,
        analysis_id: SecureRandom.hex(6),
        timestamp: Time.now
      })
    end

    def exec(calendar_data)
      puts "🧠 [#{Time.now.strftime('%H:%M:%S')}] Analyzing calendar data with LLM..."
      puts "📊 Analysis ID: #{calendar_data[:analysis_id]}"
      
      # Construct LLM prompt based on analysis type
      prompt = case @analysis_type
      when "extract"
        "Please extract key information from this calendar data: meeting count, total hours, conflicts, and patterns."
      when "optimize"
        "Please suggest optimizations for this calendar schedule to improve productivity and reduce meeting fatigue."
      when "insights"
        "Please provide strategic insights about this calendar data: time allocation, meeting patterns, and recommendations."
      else
        "Please analyze this calendar data and provide relevant insights."
      end
      
      # Call LLM service
      events = calendar_data[:events] || []
      llm_response = MockLLMService.call(prompt, { events: events })
      
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] LLM analysis completed"
      
      # Merge LLM response with calendar data
      merged_data = calendar_data.merge({
        llm_analysis: llm_response,
        analysis_type: @analysis_type,
        processed_at: Time.now
      })
      
      # Store in params for next node
      @params.merge!(merged_data)
      
      # Return symbol for routing
      :llm_analysis_completed
    end

    def post(state, params, result)
      duration = Time.now - state[:analysis_start]
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] LLM analysis completed in #{duration.round(3)}s"
      state[:analysis_duration] = duration
    end

    def exec_fallback(params, exception)
      puts "⚠️  [#{Time.now.strftime('%H:%M:%S')}] LLM analysis failed: #{exception.message}"
      puts "🔄 Using fallback analysis..."
      
      # Fallback to simple analysis
      params.merge({
        llm_analysis: "Analysis unavailable - LLM service error",
        analysis_type: "fallback",
        error: exception.message
      })
    end
  end

  class DataFormattingNode < FlowNodes::Node
    def initialize(format: "json")
      super()
      @format = format
    end

    def prep(state)
      puts "📝 [#{Time.now.strftime('%H:%M:%S')}] Formatting data as #{@format}..."
      state[:formatting_start] = Time.now
      nil
    end

    def exec(analyzed_data)
      puts "🎨 [#{Time.now.strftime('%H:%M:%S')}] Formatting analysis results..."
      
      # Use LLM for formatting if needed
      formatted_output = case @format
      when "executive_summary"
        format_executive_summary(analyzed_data)
      when "daily_agenda"
        format_daily_agenda(analyzed_data)
      when "json"
        format_json(analyzed_data)
      else
        format_default(analyzed_data)
      end
      
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Data formatted successfully"
      
      # Store formatted data in params for next node
      formatted_data = analyzed_data.merge({
        formatted_output: formatted_output,
        format: @format,
        formatted_at: Time.now
      })
      
      @params.merge!(formatted_data)
      
      # Return symbol for routing
      :data_formatted
    end

    def post(state, params, result)
      duration = Time.now - state[:formatting_start]
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Formatting completed in #{duration.round(3)}s"
      state[:formatting_duration] = duration
    end

    private

    def format_executive_summary(data)
      MockLLMService.call("format as executive_summary", { events: data[:events] })
    end

    def format_daily_agenda(data)
      MockLLMService.call("format as daily_agenda", { events: data[:events] })
    end

    def format_json(data)
      JSON.pretty_generate(data)
    end

    def format_default(data)
      """
Calendar Analysis Results
=========================

Analysis Type: #{data[:analysis_type]}
Processed At: #{data[:processed_at]}

LLM Analysis:
#{data[:llm_analysis]}

Raw Data:
#{data[:events]&.length || 0} events processed
"""
    end
  end

  class OutputDeliveryNode < FlowNodes::Node
    def initialize(delivery_method: "console")
      super()
      @delivery_method = delivery_method
    end

    def prep(state)
      puts "📤 [#{Time.now.strftime('%H:%M:%S')}] Preparing output delivery via #{@delivery_method}..."
      state[:delivery_start] = Time.now
      nil
    end

    def exec(formatted_data)
      puts "🚀 [#{Time.now.strftime('%H:%M:%S')}] Delivering formatted output..."
      
      case @delivery_method
      when "console"
        deliver_to_console(formatted_data)
      when "file"
        deliver_to_file(formatted_data)
      when "api"
        deliver_to_api(formatted_data)
      else
        puts "📄 Output: #{formatted_data[:formatted_output]}"
      end
      
      puts "✅ [#{Time.now.strftime('%H:%M:%S')}] Output delivered successfully"
      
      nil # End of flow
    end

    def post(state, params, result)
      duration = Time.now - state[:delivery_start]
      
      puts "📈 [#{Time.now.strftime('%H:%M:%S')}] Delivery completed in #{duration.round(3)}s"
      
      if state[:ingestion_start]
        total_duration = Time.now - state[:ingestion_start]
        puts "🎯 [#{Time.now.strftime('%H:%M:%S')}] Total pipeline duration: #{total_duration.round(3)}s"
      end
      
      puts "📊 Pipeline Statistics:"
      puts "   - Ingestion: #{state[:ingestion_duration]&.round(3)}s"
      puts "   - LLM Analysis: #{state[:analysis_duration]&.round(3)}s"
      puts "   - Formatting: #{state[:formatting_duration]&.round(3)}s"
      puts "   - Delivery: #{duration.round(3)}s"
      puts "   - Total LLM Calls: #{state[:llm_calls] || 0}"
    end

    private

    def deliver_to_console(data)
      puts "\n" + "="*60
      puts "📋 CALENDAR ANALYSIS RESULTS"
      puts "="*60
      puts data[:formatted_output]
      puts "="*60
    end

    def deliver_to_file(data)
      filename = "calendar_analysis_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt"
      File.write(filename, data[:formatted_output])
      puts "📁 Results saved to: #{filename}"
    end

    def deliver_to_api(data)
      puts "📡 Sending to API endpoint..."
      # Simulate API delivery
      sleep(0.1)
      puts "✅ API delivery completed"
    end
  end
end

# Demo script showing different LLM workflows
if $PROGRAM_NAME == __FILE__
  puts "🤖 LLM CALENDAR PROCESSING PIPELINE"
  puts "=" * 50

  # Create shared state for the entire pipeline
  state = {
    pipeline_id: SecureRandom.hex(4),
    user_id: "user_123"
  }

  # Scenario 1: Basic extraction and formatting
  puts "\n📋 SCENARIO 1: Calendar Data Extraction & Analysis"
  puts "-" * 40
  
  ingestion = LLMCalendarParser::CalendarDataIngestionNode.new
  analysis = LLMCalendarParser::LLMAnalysisNode.new(analysis_type: "extract")
  formatting = LLMCalendarParser::DataFormattingNode.new(format: "executive_summary")
  delivery = LLMCalendarParser::OutputDeliveryNode.new(delivery_method: "console")

  # Connect with symbol-based routing
  ingestion - :data_ingested >> analysis
  analysis - :llm_analysis_completed >> formatting
  formatting - :data_formatted >> delivery

  flow = FlowNodes::Flow.new(start: ingestion)
  flow.set_params({ source: "google_calendar_api" })
  flow.run(state)

  # Scenario 2: Optimization suggestions
  puts "\n📋 SCENARIO 2: Calendar Optimization Suggestions"
  puts "-" * 40
  
  state[:pipeline_id] = SecureRandom.hex(4)
  
  optimization_analysis = LLMCalendarParser::LLMAnalysisNode.new(analysis_type: "optimize")
  daily_formatting = LLMCalendarParser::DataFormattingNode.new(format: "daily_agenda")
  
  ingestion - :data_ingested >> optimization_analysis
  optimization_analysis - :llm_analysis_completed >> daily_formatting
  daily_formatting - :data_formatted >> delivery

  flow2 = FlowNodes::Flow.new(start: ingestion)
  flow2.set_params({ source: "outlook_calendar_api" })
  flow2.run(state)

  puts "\n🎯 All calendar processing scenarios completed!"
end