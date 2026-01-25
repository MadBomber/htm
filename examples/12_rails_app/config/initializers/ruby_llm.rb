# frozen_string_literal: true

require 'ruby_llm'

RubyLLM.configure do |config|
  # Logging - use INFO level in production, DEBUG for troubleshooting
  config.logger = Rails.logger
  config.log_level = Rails.env.development? ? Logger::INFO : Logger::WARN

  # Enable new acts_as API (required for acts_as_chat)
  config.use_new_acts_as = true

  # Model registry class for database storage
  config.model_registry_class = 'Model'

  # Default chat model
  config.default_model = ENV.fetch('CHAT_MODEL', 'gemma3:latest')

  # Cloud provider API keys
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.xai_api_key = ENV['XAI_API_KEY']

  # Ollama (local provider) - requires /v1 suffix for OpenAI-compatible API
  ollama_base = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
  config.ollama_api_base = ollama_base.end_with?('/v1') ? ollama_base : "#{ollama_base}/v1"
end

# Include ActiveRecord support directly since railtie hook doesn't always fire correctly
Rails.application.config.to_prepare do
  require 'ruby_llm/active_record/acts_as'
  ActiveRecord::Base.include RubyLLM::ActiveRecord::ActsAs unless ActiveRecord::Base.respond_to?(:acts_as_chat)
end
