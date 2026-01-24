# frozen_string_literal: true

class Chat < ApplicationRecord
  acts_as_chat

  # Override to_llm to pass assume_model_exists for cloud providers
  # This allows using models that may not be in RubyLLM's local registry
  def to_llm
    model_record = model_association
    # Map custom providers to their RubyLLM equivalents
    api_provider = map_provider_for_api(model_record.provider)

    # Debug logging - show all relevant config
    Rails.logger.info "=== Chat#to_llm Debug ==="
    Rails.logger.info "  DB provider: #{model_record.provider}"
    Rails.logger.info "  API provider: #{api_provider}"
    Rails.logger.info "  Model ID: #{model_record.model_id}"
    Rails.logger.info "  --- RubyLLM Config ---"
    Rails.logger.info "  ollama_api_base: #{RubyLLM.config.ollama_api_base}"
    Rails.logger.info "  openai_api_base: #{RubyLLM.config.openai_api_base}"
    Rails.logger.info "  openai_api_key: #{RubyLLM.config.openai_api_key&.first(10)}..."
    Rails.logger.info "  xai_api_key set: #{RubyLLM.config.xai_api_key.present?}"
    Rails.logger.info "  default_model: #{RubyLLM.config.default_model}"

    # Don't memoize - create fresh connection each time to respect current config
    # This is important when switching between providers like LM Studio and cloud APIs
    @chat = (context || RubyLLM).chat(
      model: model_record.model_id,
      provider: api_provider,
      assume_model_exists: true
    )

    # Log the actual provider being used
    provider_instance = @chat.instance_variable_get(:@provider)
    Rails.logger.info "  Actual provider class: #{provider_instance.class}"
    Rails.logger.info "  Provider api_base: #{provider_instance.api_base}"
    Rails.logger.info "  Provider headers: #{provider_instance.headers.keys.join(', ')}"
    Rails.logger.info "==========================="

    @chat.reset_messages!

    messages_association.each do |msg|
      @chat.add_message(msg.to_llm)
    end

    setup_persistence_callbacks
  end

  private

  # Map display providers to RubyLLM API providers
  # Some local servers use OpenAI-compatible APIs
  def map_provider_for_api(provider)
    case provider.to_s
    when 'lmstudio'
      :openai # LM Studio uses OpenAI-compatible API
    else
      provider.to_sym
    end
  end
end
