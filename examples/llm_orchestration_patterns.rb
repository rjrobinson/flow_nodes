# frozen_string_literal: true

# LLM Orchestration Patterns with FlowRoute
#
# This example demonstrates sophisticated LLM orchestration patterns using FlowRoute,
# including:
# - Multi-LLM workflows with different models
# - Content processing pipelines
# - Quality assurance and validation
# - Adaptive routing based on content complexity
# - Error handling and fallbacks
# - Chain-of-thought reasoning workflows
# - Collaborative multi-agent patterns

require_relative "../lib/flow_nodes"
require 'json'
require 'digest'

# ==============================================================================
# LLM SIMULATION FRAMEWORK
# ==============================================================================

module LLMSimulator
  # Simulate different LLM models with different characteristics
  class LLMModel
    attr_reader :name, :capabilities, :cost_per_token, :latency, :quality_score

    def initialize(name:, capabilities:, cost_per_token:, latency:, quality_score:)
      @name = name
      @capabilities = capabilities
      @cost_per_token = cost_per_token
      @latency = latency
      @quality_score = quality_score
    end

    def supports_capability?(capability)
      @capabilities.include?(capability)
    end

    def call(prompt, **options)
      # Simulate API call latency
      sleep(@latency)
      
      # Simulate different model responses
      case @name
      when 'gpt-4-turbo'
        generate_high_quality_response(prompt, **options)
      when 'gpt-3.5-turbo'
        generate_fast_response(prompt, **options)
      when 'claude-3-opus'
        generate_thoughtful_response(prompt, **options)
      when 'claude-3-sonnet'
        generate_balanced_response(prompt, **options)
      when 'gemini-pro'
        generate_multimodal_response(prompt, **options)
      else
        generate_generic_response(prompt, **options)
      end
    end

    private

    def generate_high_quality_response(prompt, **options)
      {
        content: "High-quality response to: #{prompt[0..50]}...",
        reasoning: "Detailed analysis and reasoning...",
        confidence: 0.95,
        tokens_used: 150,
        model: @name
      }
    end

    def generate_fast_response(prompt, **options)
      {
        content: "Quick response to: #{prompt[0..30]}...",
        confidence: 0.8,
        tokens_used: 80,
        model: @name
      }
    end

    def generate_thoughtful_response(prompt, **options)
      {
        content: "Thoughtful, nuanced response to: #{prompt[0..40]}...",
        reasoning: "Step-by-step analysis with multiple perspectives...",
        confidence: 0.92,
        tokens_used: 200,
        model: @name
      }
    end

    def generate_balanced_response(prompt, **options)
      {
        content: "Balanced response to: #{prompt[0..40]}...",
        confidence: 0.87,
        tokens_used: 120,
        model: @name
      }
    end

    def generate_multimodal_response(prompt, **options)
      {
        content: "Multimodal-aware response to: #{prompt[0..35]}...",
        supports_images: true,
        confidence: 0.85,
        tokens_used: 100,
        model: @name
      }
    end

    def generate_generic_response(prompt, **options)
      {
        content: "Generic response to: #{prompt[0..40]}...",
        confidence: 0.75,
        tokens_used: 90,
        model: @name
      }
    end
  end

  # Model registry
  MODELS = {
    'gpt-4-turbo' => LLMModel.new(
      name: 'gpt-4-turbo',
      capabilities: [:reasoning, :coding, :analysis, :creative_writing],
      cost_per_token: 0.00003,
      latency: 0.3,
      quality_score: 0.95
    ),
    'gpt-3.5-turbo' => LLMModel.new(
      name: 'gpt-3.5-turbo', 
      capabilities: [:general, :coding, :summarization],
      cost_per_token: 0.000002,
      latency: 0.1,
      quality_score: 0.8
    ),
    'claude-3-opus' => LLMModel.new(
      name: 'claude-3-opus',
      capabilities: [:reasoning, :analysis, :creative_writing, :safety],
      cost_per_token: 0.000075,
      latency: 0.4,
      quality_score: 0.98
    ),
    'claude-3-sonnet' => LLMModel.new(
      name: 'claude-3-sonnet',
      capabilities: [:reasoning, :analysis, :coding],
      cost_per_token: 0.000015,
      latency: 0.2,
      quality_score: 0.9
    ),
    'gemini-pro' => LLMModel.new(
      name: 'gemini-pro',
      capabilities: [:multimodal, :reasoning, :coding],
      cost_per_token: 0.0000005,
      latency: 0.15,
      quality_score: 0.85
    )
  }.freeze

  def self.get_model(name)
    MODELS[name] or raise "Unknown model: #{name}"
  end

  def self.list_models
    MODELS.keys
  end
end

# ==============================================================================
# LLM ORCHESTRATION NODES
# ==============================================================================

module LLMOrchestration
  # Base node for LLM operations with common functionality
  class LLMNode < FlowNodes::Node
    def initialize(default_model: 'gpt-3.5-turbo')
      super()
      @default_model = default_model
      @metrics = { calls: 0, total_cost: 0.0, total_tokens: 0 }
    end

    protected

    def call_llm(prompt, model: @default_model, **options)
      llm_model = LLMSimulator.get_model(model)
      
      puts "🤖 [#{model}] Processing: #{prompt[0..50]}..."
      
      result = llm_model.call(prompt, **options)
      
      # Track metrics
      @metrics[:calls] += 1
      @metrics[:total_cost] += result[:tokens_used] * llm_model.cost_per_token
      @metrics[:total_tokens] += result[:tokens_used]
      
      result
    end

    def get_metrics
      @metrics.dup
    end
  end

  # Content complexity analyzer to route to appropriate LLM
  class ComplexityAnalyzerNode < LLMNode
    def exec(params)
      content = params[:content] || params[:text]
      
      # Analyze content complexity
      complexity = analyze_complexity(content)
      params[:complexity_score] = complexity[:score]
      params[:complexity_factors] = complexity[:factors]
      
      puts "📊 Complexity Analysis: #{complexity[:score]} (#{complexity[:level]})"
      puts "   Factors: #{complexity[:factors].join(', ')}"
      
      # Route based on complexity
      case complexity[:level]
      when :simple then :simple_processing
      when :moderate then :moderate_processing  
      when :complex then :complex_processing
      when :expert then :expert_processing
      else :moderate_processing
      end
    end

    private

    def analyze_complexity(content)
      text = content.to_s
      
      factors = []
      score = 0.0
      
      # Length factor
      if text.length > 5000
        factors << "very_long"
        score += 0.3
      elsif text.length > 1000
        factors << "long"
        score += 0.1
      end
      
      # Technical content
      if text.match?(/\b(algorithm|function|class|API|database|architecture)\b/i)
        factors << "technical"
        score += 0.2
      end
      
      # Complex reasoning required
      if text.match?(/\b(analyze|compare|evaluate|synthesize|critique)\b/i)
        factors << "analytical"
        score += 0.25
      end
      
      # Multiple topics
      topic_indicators = text.scan(/\b(however|furthermore|additionally|meanwhile|in contrast)\b/i).length
      if topic_indicators > 3
        factors << "multi_topic"
        score += 0.15
      end
      
      # Mathematical/scientific content
      if text.match?(/\b(equation|formula|hypothesis|theorem|analysis)\b/i)
        factors << "mathematical"
        score += 0.2
      end
      
      # Determine level
      level = case score
              when 0..0.2 then :simple
              when 0.2..0.5 then :moderate
              when 0.5..0.8 then :complex
              else :expert
              end
      
      { score: score, level: level, factors: factors }
    end
  end

  # Simple content processor using fast, cost-effective models
  class SimpleProcessorNode < LLMNode
    def initialize
      super(default_model: 'gpt-3.5-turbo')
    end

    def exec(params)
      content = params[:content]
      
      result = call_llm(
        "Please provide a concise response to: #{content}",
        model: 'gpt-3.5-turbo'
      )
      
      params[:response] = result[:content]
      params[:model_used] = result[:model]
      params[:processing_cost] = @metrics[:total_cost]
      
      :processed
    end
  end

  # Moderate complexity processor with balanced model selection
  class ModerateProcessorNode < LLMNode
    def initialize
      super(default_model: 'claude-3-sonnet')
    end

    def exec(params)
      content = params[:content]
      
      result = call_llm(
        "Please provide a detailed, well-reasoned response to: #{content}",
        model: 'claude-3-sonnet'
      )
      
      params[:response] = result[:content]
      params[:reasoning] = result[:reasoning]
      params[:model_used] = result[:model]
      params[:confidence] = result[:confidence]
      params[:processing_cost] = @metrics[:total_cost]
      
      :processed
    end
  end

  # Complex content processor using high-capability models
  class ComplexProcessorNode < LLMNode
    def initialize
      super(default_model: 'claude-3-opus')
    end

    def exec(params)
      content = params[:content]
      complexity_factors = params[:complexity_factors] || []
      
      # Build specialized prompt based on complexity factors
      prompt = build_complex_prompt(content, complexity_factors)
      
      result = call_llm(prompt, model: 'claude-3-opus')
      
      params[:response] = result[:content]
      params[:reasoning] = result[:reasoning]
      params[:model_used] = result[:model]
      params[:confidence] = result[:confidence]
      params[:processing_cost] = @metrics[:total_cost]
      
      :processed
    end

    private

    def build_complex_prompt(content, factors)
      prompt = "Please provide a comprehensive, expert-level analysis of: #{content}\n\n"
      
      if factors.include?("technical")
        prompt += "Focus on technical accuracy and implementation details.\n"
      end
      
      if factors.include?("analytical")
        prompt += "Provide deep analysis with multiple perspectives.\n"
      end
      
      if factors.include?("multi_topic")
        prompt += "Address all relevant topics and their interconnections.\n"
      end
      
      prompt += "\nProvide detailed reasoning for your response."
      prompt
    end
  end

  # Expert-level processor for the most complex content
  class ExpertProcessorNode < LLMNode
    def initialize
      super(default_model: 'gpt-4-turbo')
    end

    def exec(params)
      content = params[:content]
      
      # Use the most capable model for expert-level processing
      result = call_llm(
        "As an expert in this domain, please provide a comprehensive, authoritative analysis of: #{content}",
        model: 'gpt-4-turbo'
      )
      
      params[:response] = result[:content]
      params[:reasoning] = result[:reasoning]
      params[:model_used] = result[:model]
      params[:confidence] = result[:confidence]
      params[:processing_cost] = @metrics[:total_cost]
      
      :processed
    end
  end

  # Quality assurance node that validates responses
  class QualityAssuranceNode < LLMNode
    QUALITY_THRESHOLD = 0.8

    def exec(params)
      response = params[:response]
      confidence = params[:confidence] || 0.5
      
      # Evaluate response quality
      quality_score = evaluate_quality(response, confidence)
      params[:quality_score] = quality_score
      
      puts "✅ Quality Check: #{quality_score} (threshold: #{QUALITY_THRESHOLD})"
      
      if quality_score >= QUALITY_THRESHOLD
        :high_quality
      elsif quality_score >= 0.6
        :medium_quality
      else
        :low_quality
      end
    end

    private

    def evaluate_quality(response, confidence)
      score = 0.0
      
      # Handle nil response
      return 0.0 if response.nil? || response.empty?
      
      # Base score from model confidence
      score += confidence * 0.4
      
      # Length check (not too short, not too verbose)
      length_score = case response.length
                     when 50..500 then 0.3
                     when 500..2000 then 0.2
                     else 0.1
                     end
      score += length_score
      
      # Content quality heuristics
      if response.match?(/\b(because|therefore|however|specifically|for example)\b/i)
        score += 0.1  # Explanatory language
      end
      
      if response.include?('.')
        sentence_count = response.count('.')
        score += [sentence_count * 0.02, 0.2].min  # Multiple sentences, capped
      end
      
      [score, 1.0].min
    end
  end

  # Enhancement node for medium-quality responses
  class ResponseEnhancementNode < LLMNode
    def exec(params)
      original_response = params[:response]
      
      enhancement_prompt = "Please improve this response by making it more detailed and accurate: #{original_response}"
      
      result = call_llm(enhancement_prompt, model: 'claude-3-sonnet')
      
      params[:response] = result[:content]
      params[:enhanced] = true
      params[:original_response] = original_response
      params[:model_used] = result[:model]
      
      :enhanced
    end
  end

  # Regeneration node for low-quality responses
  class ResponseRegenerationNode < LLMNode
    def exec(params)
      original_content = params[:content]
      failed_response = params[:response]
      
      regeneration_prompt = "The previous response was insufficient: #{failed_response}\n\n"
      regeneration_prompt += "Please provide a much better response to: #{original_content}"
      
      result = call_llm(regeneration_prompt, model: 'claude-3-opus')
      
      params[:response] = result[:content]
      params[:regenerated] = true
      params[:failed_response] = failed_response
      params[:model_used] = result[:model]
      
      :regenerated
    end
  end

  # Multi-agent collaboration node
  class CollaborativeReasoningNode < LLMNode
    def exec(params)
      content = params[:content]
      
      # Get perspectives from different models
      perspectives = gather_perspectives(content)
      
      # Synthesize perspectives
      synthesis = synthesize_perspectives(content, perspectives)
      
      params[:perspectives] = perspectives
      params[:response] = synthesis[:content]
      params[:collaboration_summary] = synthesis[:summary]
      params[:models_consulted] = perspectives.keys
      
      :collaborated
    end

    private

    def gather_perspectives(content)
      perspectives = {}
      
      # Get analytical perspective
      analytical_result = call_llm(
        "From an analytical perspective, please analyze: #{content}",
        model: 'claude-3-opus'
      )
      perspectives[:analytical] = analytical_result
      
      # Get practical perspective  
      practical_result = call_llm(
        "From a practical implementation perspective, please respond to: #{content}",
        model: 'gpt-4-turbo'
      )
      perspectives[:practical] = practical_result
      
      # Get creative perspective
      creative_result = call_llm(
        "From a creative problem-solving perspective, please address: #{content}",
        model: 'claude-3-sonnet'
      )
      perspectives[:creative] = creative_result
      
      perspectives
    end

    def synthesize_perspectives(content, perspectives)
      synthesis_prompt = "Please synthesize these different perspectives on '#{content}':\n\n"
      
      perspectives.each do |type, result|
        synthesis_prompt += "#{type.to_s.capitalize} perspective: #{result[:content]}\n\n"
      end
      
      synthesis_prompt += "Provide a comprehensive response that incorporates the best insights from each perspective."
      
      result = call_llm(synthesis_prompt, model: 'gpt-4-turbo')
      
      {
        content: result[:content],
        summary: "Synthesized insights from #{perspectives.keys.join(', ')} perspectives"
      }
    end
  end

  # Chain-of-thought reasoning node
  class ChainOfThoughtNode < LLMNode
    def exec(params)
      content = params[:content]
      
      # Build chain-of-thought prompt
      cot_prompt = build_cot_prompt(content)
      
      result = call_llm(cot_prompt, model: 'claude-3-opus')
      
      # Parse reasoning steps
      reasoning_steps = extract_reasoning_steps(result[:content])
      
      params[:response] = result[:content]
      params[:reasoning_steps] = reasoning_steps
      params[:reasoning_method] = "chain_of_thought"
      params[:model_used] = result[:model]
      
      :reasoned
    end

    private

    def build_cot_prompt(content)
      <<~PROMPT
        Please think through this step by step:

        #{content}

        Let's work through this systematically:
        1. First, let me understand what's being asked...
        2. What are the key factors to consider...
        3. Let me analyze each factor...
        4. Now I'll synthesize this information...
        5. Based on this analysis, my response is...

        Please follow this reasoning structure in your response.
      PROMPT
    end

    def extract_reasoning_steps(response)
      steps = response.scan(/\d+\.\s+([^0-9]+?)(?=\d+\.|$)/m)
      steps.map(&:first).map(&:strip).reject(&:empty?)
    end
  end

  # Fallback response node for when everything else fails
  class FallbackResponseNode < LLMNode
    def exec(params)
      content = params[:content]
      error_context = params[:error_context] || "processing failed"
      
      fallback_response = generate_fallback_response(content, error_context)
      
      params[:response] = fallback_response
      params[:is_fallback] = true
      params[:model_used] = "fallback_system"
      
      nil  # End flow
    end

    private

    def generate_fallback_response(content, error_context)
      "I apologize, but I encountered difficulties processing your request. " \
      "While I understand you're asking about '#{content[0..50]}...', " \
      "I'm unable to provide a complete response at this time. " \
      "Please try rephrasing your question or contact support if this issue persists."
    end
  end

  # Response formatting and output node
  class ResponseFormatterNode < LLMNode
    def exec(params)
      response = params[:response]
      metadata = extract_metadata(params)
      
      formatted_response = {
        content: response,
        metadata: metadata,
        formatted_at: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        processing_summary: generate_processing_summary(params)
      }
      
      params[:formatted_response] = formatted_response
      
      puts "\n📄 FORMATTED RESPONSE:"
      puts "=" * 60
      puts formatted_response[:content]
      puts "\n📊 PROCESSING SUMMARY:"
      puts formatted_response[:processing_summary]
      puts "=" * 60
      
      nil  # End flow
    end

    private

    def extract_metadata(params)
      {
        model_used: params[:model_used],
        complexity_score: params[:complexity_score],
        quality_score: params[:quality_score],
        processing_cost: params[:processing_cost],
        confidence: params[:confidence],
        enhanced: params[:enhanced] || false,
        regenerated: params[:regenerated] || false,
        collaborated: params.key?(:models_consulted),
        reasoning_method: params[:reasoning_method]
      }
    end

    def generate_processing_summary(params)
      summary = []
      
      if params[:complexity_score]
        summary << "Complexity: #{params[:complexity_score].round(2)}"
      end
      
      if params[:model_used]
        summary << "Model: #{params[:model_used]}"
      end
      
      if params[:quality_score]
        summary << "Quality: #{params[:quality_score].round(2)}"
      end
      
      if params[:processing_cost]
        summary << "Cost: $#{params[:processing_cost].round(6)}"
      end
      
      if params[:enhanced]
        summary << "Enhanced: Yes"
      end
      
      if params[:regenerated]
        summary << "Regenerated: Yes"
      end
      
      if params[:models_consulted]
        summary << "Collaboration: #{params[:models_consulted].join(', ')}"
      end
      
      summary.join(" | ")
    end
  end
end

# ==============================================================================
# LLM ORCHESTRATION ROUTING CONFIGURATIONS
# ==============================================================================

def create_adaptive_llm_routing
  FlowNodes::FlowRoute.draw do
    # Main content analysis and routing
    node :complexity_analyzer do
      route :simple_processing, to: :simple_processor
      route :moderate_processing, to: :moderate_processor  
      route :complex_processing, to: :complex_processor
      route :expert_processing, to: :expert_processor
    end
    
    # Quality assurance pipeline
    node :simple_processor do
      route :processed, to: :quality_assurance
    end
    
    node :moderate_processor do
      route :processed, to: :quality_assurance
    end
    
    node :complex_processor do
      route :processed, to: :quality_assurance
    end
    
    node :expert_processor do
      route :processed, to: :quality_assurance
    end
    
    # Quality-based routing
    node :quality_assurance do
      route :high_quality, to: :response_formatter
      route :medium_quality, to: :response_enhancement
      route :low_quality, to: :response_regeneration
    end
    
    # Enhancement and regeneration paths
    node :response_enhancement do
      route :enhanced, to: :response_formatter
    end
    
    node :response_regeneration do
      route :regenerated, to: :quality_assurance  # Re-check quality after regeneration
    end
  end
end

def create_collaborative_llm_routing
  FlowNodes::FlowRoute.draw do
    node :complexity_analyzer do
      route [:complex_processing, :expert_processing], to: :collaborative_reasoning
      route [:simple_processing, :moderate_processing], to: :moderate_processor
    end
    
    node :collaborative_reasoning do
      route :collaborated, to: :quality_assurance
    end
    
    node :quality_assurance do
      route :high_quality, to: :response_formatter
      route [:medium_quality, :low_quality], to: :response_enhancement
    end
    
    node :response_enhancement do
      route :enhanced, to: :response_formatter
    end
  end
end

def create_chain_of_thought_routing
  FlowNodes::FlowRoute.draw do
    node :complexity_analyzer do
      route [:complex_processing, :expert_processing], to: :chain_of_thought
      route [:simple_processing, :moderate_processing], to: :simple_processor
    end
    
    node :chain_of_thought do
      route :reasoned, to: :quality_assurance
    end
    
    node :simple_processor do
      route :processed, to: :response_formatter
    end
    
    node :quality_assurance do
      route :high_quality, to: :response_formatter
      route [:medium_quality, :low_quality], to: :fallback_response
    end
  end
end

# ==============================================================================
# DEMONSTRATION SCENARIOS
# ==============================================================================

def run_adaptive_llm_demo
  puts "🚀 ADAPTIVE LLM ORCHESTRATION DEMO"
  puts "=" * 60

  # Create node instances
  complexity_analyzer = LLMOrchestration::ComplexityAnalyzerNode.new
  simple_processor = LLMOrchestration::SimpleProcessorNode.new
  moderate_processor = LLMOrchestration::ModerateProcessorNode.new
  complex_processor = LLMOrchestration::ComplexProcessorNode.new
  expert_processor = LLMOrchestration::ExpertProcessorNode.new
  quality_assurance = LLMOrchestration::QualityAssuranceNode.new
  response_enhancement = LLMOrchestration::ResponseEnhancementNode.new
  response_regeneration = LLMOrchestration::ResponseRegenerationNode.new
  response_formatter = LLMOrchestration::ResponseFormatterNode.new

  # Create node registry
  node_registry = {
    complexity_analyzer: complexity_analyzer,
    simple_processor: simple_processor,
    moderate_processor: moderate_processor,
    complex_processor: complex_processor,
    expert_processor: expert_processor,
    quality_assurance: quality_assurance,
    response_enhancement: response_enhancement,
    response_regeneration: response_regeneration,
    response_formatter: response_formatter
  }

  # Apply adaptive routing using existing methods for compatibility
  # In production, you'd use FlowRoute with proper symbol-to-instance mapping
  
  # Main routing
  complexity_analyzer.routes({
    :simple_processing => simple_processor,
    :moderate_processing => moderate_processor,
    :complex_processing => complex_processor,
    :expert_processing => expert_processor
  })
  
  # Quality pipeline routing
  simple_processor.routes({ :processed => quality_assurance })
  moderate_processor.routes({ :processed => quality_assurance })
  complex_processor.routes({ :processed => quality_assurance })
  expert_processor.routes({ :processed => quality_assurance })
  
  # Quality-based routing
  quality_assurance.routes({
    :high_quality => response_formatter,
    :medium_quality => response_enhancement,
    :low_quality => response_regeneration
  })
  
  # Enhancement paths
  response_enhancement.routes({ :enhanced => response_formatter })
  response_regeneration.routes({ :regenerated => quality_assurance })

  # Test cases with different complexity levels
  test_cases = [
    {
      name: "Simple Query",
      content: "What is the capital of France?"
    },
    {
      name: "Moderate Technical Query", 
      content: "How do I implement a REST API in Node.js with proper error handling and authentication?"
    },
    {
      name: "Complex Analysis Request",
      content: "Please analyze the architectural trade-offs between microservices and monolithic applications, considering scalability, development complexity, operational overhead, and team coordination factors. Provide specific recommendations for a team of 20 developers working on an e-commerce platform."
    },
    {
      name: "Expert-Level Question",
      content: "Design a distributed consensus algorithm that can handle network partitions while maintaining strong consistency guarantees. Compare your approach with Raft and PBFT algorithms, analyze the mathematical properties of safety and liveness, and discuss the theoretical lower bounds on message complexity in asynchronous networks with Byzantine failures."
    }
  ]

  test_cases.each_with_index do |test_case, index|
    puts "\n🧪 TEST CASE #{index + 1}: #{test_case[:name]}"
    puts "-" * 50
    puts "Content: #{test_case[:content][0..100]}..."
    
    # Run the workflow
    flow = FlowNodes::Flow.new(start: complexity_analyzer)
    flow.set_params(content: test_case[:content])
    flow.run(nil)
    
    sleep(0.5)  # Brief pause between tests
  end
end

def run_collaborative_llm_demo
  puts "\n\n🤝 COLLABORATIVE LLM ORCHESTRATION DEMO"
  puts "=" * 60

  # Create specialized nodes
  complexity_analyzer = LLMOrchestration::ComplexityAnalyzerNode.new
  moderate_processor = LLMOrchestration::ModerateProcessorNode.new
  collaborative_reasoning = LLMOrchestration::CollaborativeReasoningNode.new
  quality_assurance = LLMOrchestration::QualityAssuranceNode.new
  response_enhancement = LLMOrchestration::ResponseEnhancementNode.new
  response_formatter = LLMOrchestration::ResponseFormatterNode.new

  node_registry = {
    complexity_analyzer: complexity_analyzer,
    moderate_processor: moderate_processor,
    collaborative_reasoning: collaborative_reasoning,
    quality_assurance: quality_assurance,
    response_enhancement: response_enhancement,
    response_formatter: response_formatter
  }

  # Apply collaborative routing using existing methods for compatibility
  complexity_analyzer.routes({
    [:complex_processing, :expert_processing] => collaborative_reasoning,
    [:simple_processing, :moderate_processing] => moderate_processor
  })
  
  collaborative_reasoning.routes({ :collaborated => quality_assurance })
  
  quality_assurance.routes({
    :high_quality => response_formatter,
    [:medium_quality, :low_quality] => response_enhancement
  })
  
  response_enhancement.routes({ :enhanced => response_formatter })

  # Test collaborative reasoning
  collaborative_query = "How can we design a sustainable urban transportation system that balances environmental impact, economic viability, social equity, and technological innovation?"
  
  puts "\n🧪 COLLABORATIVE REASONING TEST:"
  puts "Query: #{collaborative_query}"
  
  flow = FlowNodes::Flow.new(start: complexity_analyzer)
  flow.set_params(content: collaborative_query)
  flow.run(nil)
end

def run_chain_of_thought_demo
  puts "\n\n🧠 CHAIN-OF-THOUGHT REASONING DEMO"
  puts "=" * 60

  # Create reasoning-focused nodes
  complexity_analyzer = LLMOrchestration::ComplexityAnalyzerNode.new
  simple_processor = LLMOrchestration::SimpleProcessorNode.new
  chain_of_thought = LLMOrchestration::ChainOfThoughtNode.new
  quality_assurance = LLMOrchestration::QualityAssuranceNode.new
  fallback_response = LLMOrchestration::FallbackResponseNode.new
  response_formatter = LLMOrchestration::ResponseFormatterNode.new

  node_registry = {
    complexity_analyzer: complexity_analyzer,
    simple_processor: simple_processor,
    chain_of_thought: chain_of_thought,
    quality_assurance: quality_assurance,
    fallback_response: fallback_response,
    response_formatter: response_formatter
  }

  # Apply chain-of-thought routing using existing methods for compatibility
  complexity_analyzer.routes({
    [:complex_processing, :expert_processing] => chain_of_thought,
    [:simple_processing, :moderate_processing] => simple_processor
  })
  
  chain_of_thought.routes({ :reasoned => quality_assurance })
  simple_processor.routes({ :processed => response_formatter })
  
  quality_assurance.routes({
    :high_quality => response_formatter,
    [:medium_quality, :low_quality] => fallback_response
  })

  # Test systematic reasoning
  reasoning_query = "A company is deciding whether to build an internal tool or buy an existing solution. The internal tool would cost $500K to develop and $100K/year to maintain. The external solution costs $200K upfront and $150K/year in licensing. The internal tool would be customized perfectly but might have technical debt. The external solution is proven but may not fit all needs. What should they choose and why?"
  
  puts "\n🧪 CHAIN-OF-THOUGHT REASONING TEST:"
  puts "Query: #{reasoning_query[0..100]}..."
  
  flow = FlowNodes::Flow.new(start: complexity_analyzer)
  flow.set_params(content: reasoning_query)
  flow.run(nil)
end

# ==============================================================================
# MAIN DEMONSTRATION
# ==============================================================================

if $PROGRAM_NAME == __FILE__
  puts "🤖 LLM ORCHESTRATION PATTERNS WITH FLOWROUTE"
  puts "=" * 70
  puts "Demonstrating sophisticated LLM workflows using FlowRoute routing"
  puts "Available models: #{LLMSimulator.list_models.join(', ')}"
  puts "=" * 70

  # Run all demonstrations
  run_adaptive_llm_demo
  run_collaborative_llm_demo
  run_chain_of_thought_demo

  puts "\n" + "=" * 70
  puts "🎯 LLM ORCHESTRATION BENEFITS WITH FLOWROUTE"
  puts "-" * 50
  puts "✅ Adaptive Model Selection: Route to optimal model based on complexity"
  puts "✅ Quality Assurance Pipeline: Automatic quality checks and improvements"
  puts "✅ Cost Optimization: Use expensive models only when necessary"
  puts "✅ Collaborative Reasoning: Multiple models working together"
  puts "✅ Chain-of-Thought: Systematic reasoning for complex problems"
  puts "✅ Error Recovery: Fallbacks and regeneration for failed responses"
  puts "✅ Centralized Configuration: All routing logic in one place"
  puts "✅ Performance Monitoring: Built-in cost and quality tracking"
  puts "✅ Scalable Architecture: Easy to add new models and patterns"

  puts "\n📊 KEY PATTERN CATEGORIES:"
  puts "-" * 30
  puts "1. **Adaptive Routing**: Content complexity determines model selection"
  puts "2. **Quality Pipelines**: Multi-stage validation and improvement"
  puts "3. **Collaborative Processing**: Multiple models providing perspectives"
  puts "4. **Reasoning Workflows**: Structured thinking and analysis"
  puts "5. **Cost Optimization**: Smart model selection based on requirements"
  puts "6. **Error Resilience**: Robust fallbacks and retry mechanisms"

  puts "\n🚀 FlowRoute + LLMs = Intelligent, Cost-Effective AI Workflows!"
end