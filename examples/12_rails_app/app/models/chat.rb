# frozen_string_literal: true

class Chat < ApplicationRecord
  acts_as_chat

  # Override to_llm to pass assume_model_exists for cloud providers
  # This allows using models that may not be in RubyLLM's local registry
  def to_llm
    model_record = model_association
    api_provider = map_provider_for_api(model_record.provider)

    Rails.logger.info "Chat#to_llm: provider=#{model_record.provider} -> #{api_provider}, model=#{model_record.model_id}"

    # Create fresh chat object each request to respect current provider config
    @chat = (context || RubyLLM).chat(
      model: model_record.model_id,
      provider: api_provider,
      assume_model_exists: true
    )

    @chat.reset_messages!
    messages_association.each { |msg| @chat.add_message(msg.to_llm) }
    setup_persistence_callbacks
  end

  private

  # Map display providers to RubyLLM API providers
  # LM Studio uses OpenAI-compatible API
  def map_provider_for_api(provider)
    case provider.to_s
    when 'lmstudio' then :openai
    else provider.to_sym
    end
  end
end
