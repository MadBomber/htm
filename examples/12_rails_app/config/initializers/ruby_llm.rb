# frozen_string_literal: true

require 'ruby_llm'

RubyLLM.configure do |config|
  # Enable debug logging to see HTTP requests
  config.logger = Rails.logger
  config.log_level = Logger::DEBUG

  # Enable new acts_as API (required for acts_as_chat)
  config.use_new_acts_as = true

  # Model registry class for database storage
  config.model_registry_class = 'Model'

  # Chat model configuration (separate from HTM's tag/embedding models)
  config.default_model = ENV.fetch('CHAT_MODEL', 'gemma3:latest')

  # Provider API keys (for cloud providers)
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']

  # Ollama (local provider) - requires /v1 suffix for OpenAI-compatible API
  ollama_base = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
  config.ollama_api_base = ollama_base.end_with?('/v1') ? ollama_base : "#{ollama_base}/v1"
end

# Include ActiveRecord support directly since railtie hook doesn't always fire correctly
Rails.application.config.to_prepare do
  require 'ruby_llm/active_record/acts_as'
  ActiveRecord::Base.include RubyLLM::ActiveRecord::ActsAs unless ActiveRecord::Base.respond_to?(:acts_as_chat)
end
