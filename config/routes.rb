# frozen_string_literal: true

# FlowNodes Routes Configuration
# Similar to Rails routes.rb, this file defines the routing between nodes
# in a centralized, declarative way.

FlowNodes::FlowRoute.draw do
  # Customer Support Flow Routes
  node :intent_classifier do
    # Multiple conditions routing to same handler (DRY)
    route %i[technical billing general], to: :knowledge_base >> :response_generator

    # Single condition routes
    route :escalate, to: :escalation_handler
    route :unknown, to: :fallback_handler

    # Conditional routing (advanced feature)
    # when -> { |params| params[:priority] == 'urgent' }, to: :urgent_handler
  end

  # LLM Processing Flow Routes
  node :llm_classifier do
    route %i[content_analysis summarization], to: :content_processor >> :formatter
    route :translation, to: :translation_service
    route :error, to: :error_handler

    # Default/fallback route
    otherwise to: :general_processor
  end

  # User Management Flow Routes
  node :user_router do
    route :premium, to: :premium_handler
    route :basic, to: :basic_handler >> :usage_tracker
    route :trial, to: :trial_handler >> :conversion_tracker
  end

  # Processing Pipeline Routes
  node :document_processor do
    route :pdf, to: :pdf_extractor >> :text_analyzer >> :result_formatter
    route :image, to: :ocr_processor >> :text_analyzer >> :result_formatter
    route :text, to: :text_analyzer >> :result_formatter
  end

  # API Response Flow Routes
  node :api_router do
    route %i[success partial], to: :response_builder
    route %i[error timeout], to: :error_response_builder
    route :rate_limited, to: :rate_limit_handler
  end

  # Namespace example for complex applications
  namespace :admin do
    node :admin_classifier do
      route :user_management, to: :user_admin_handler
      route :system_config, to: :config_admin_handler
      route :analytics, to: :analytics_handler
    end
  end

  # Resource-style routing for CRUD operations
  resources :workflow_manager,
            create: :workflow_creator,
            read: :workflow_reader,
            update: :workflow_updater,
            delete: :workflow_deleter
end
