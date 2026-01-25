# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @chat = Chat.find(params[:chat_id])
    user_content = params[:content]
    provider = @chat.model&.provider || 'ollama'

    # Configure provider once at request start (clean slate)
    configure_provider_cleanly(provider)

    # Retrieve context from HTM (RAG)
    context_results = fetch_htm_context(user_content)
    context_text = format_context(context_results)
    Rails.logger.info "Built context (#{context_text.length} chars): #{context_text[0..200]}..."

    # Build system prompt with HTM context
    system_prompt = build_system_prompt(context_text)

    # Ensure chat has a valid Model record
    ensure_model_record(@chat)

    # Use acts_as_chat - the chat object handles its own LLM configuration
    @chat.assume_model_exists = true
    @chat.with_instructions(system_prompt, replace: true)

    begin
      @chat.ask(user_content)
    rescue RubyLLM::Error => e
      handle_llm_error(@chat, user_content, e)
    end

    redirect_to chat_path(@chat)
  end

  private

  def fetch_htm_context(query)
    results = htm.recall(query, limit: 5, strategy: :fulltext)
    Rails.logger.info "HTM recall returned #{results.size} results for: #{query[0..50]}"
    results
  rescue StandardError => e
    Rails.logger.warn "HTM recall failed: #{e.class}: #{e.message}"
    []
  end

  def format_context(results)
    return 'No relevant context found.' if results.empty?

    results.map.with_index do |r, i|
      content = case r
                when String then r
                when Hash then r[:content] || r['content']
                else r.respond_to?(:content) ? r.content : r.to_s
                end
      "[#{i + 1}] #{content&.truncate(500)}"
    end.join("\n\n")
  end

  def build_system_prompt(context)
    <<~PROMPT
      You are a helpful assistant with access to a knowledge base.

      Use the following context from the knowledge base to answer questions.
      If the context doesn't contain relevant information, acknowledge that
      and provide your best answer based on your training.

      === Knowledge Base Context ===
      #{context}
      === End Context ===
    PROMPT
  end

  def ensure_model_record(chat)
    stored_value = chat[:model_id]

    # Already a valid Model record ID
    if stored_value.to_s =~ /^\d+$/
      return if Model.exists?(id: stored_value)
    end

    # Create Model record from string name
    model_name = stored_value.presence || ENV.fetch('CHAT_MODEL', 'gemma3:latest')
    model = Model.find_or_create_by!(model_id: model_name, provider: 'ollama') do |m|
      m.name = model_name
    end

    chat.update_column(:model_id, model.id)
    chat.reload
  end

  def handle_llm_error(chat, user_content, error)
    chat.messages.create!(role: 'user', content: user_content)
    chat.messages.create!(
      role: 'assistant',
      content: "**Error from #{chat.model&.provider || 'provider'}:** #{error.message}"
    )
    Rails.logger.error "LLM Error: #{error.class}: #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n")
  end

  # Configure provider with a clean slate - no residual config from previous requests
  def configure_provider_cleanly(provider)
    Rails.logger.info "=== Configuring provider: #{provider} ==="

    # Reset OpenAI config to prevent cross-contamination between providers
    # (LM Studio uses openai_api_base which affects other providers)
    reset_openai_config unless provider == 'lmstudio'

    case provider
    when 'ollama'
      configure_ollama
    when 'lmstudio'
      configure_lmstudio
    when 'gpustack'
      configure_gpustack
    else
      configure_cloud_provider(provider)
    end
  end

  def reset_openai_config
    RubyLLM.config.openai_api_base = nil
    RubyLLM.config.openai_api_key = ENV['OPENAI_API_KEY']
  end

  def configure_ollama
    base_url = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
    base_url = "#{base_url}/v1" unless base_url.end_with?('/v1')
    RubyLLM.config.ollama_api_base = base_url
    Rails.logger.info "  Ollama API: #{base_url}"
  end

  def configure_lmstudio
    base_url = ENV.fetch('LMSTUDIO_URL', 'http://localhost:1234')
    base_url = "#{base_url}/v1" unless base_url.end_with?('/v1')
    RubyLLM.config.openai_api_base = base_url
    RubyLLM.config.openai_api_key = 'lm-studio'
    Rails.logger.info "  LM Studio API: #{base_url}"
  end

  def configure_gpustack
    base_url = ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:8080')
    RubyLLM.config.gpustack_api_base = base_url
    Rails.logger.info "  GPUStack API: #{base_url}"
  end

  def configure_cloud_provider(provider)
    provider_class = RubyLLM.providers.find { |p| p.name.split('::').last.downcase == provider }
    return unless provider_class

    provider_class.configuration_requirements.each do |config_key|
      env_var = config_key.to_s.upcase
      if ENV[env_var].present?
        RubyLLM.config.send("#{config_key}=", ENV[env_var])
        Rails.logger.info "  Set #{config_key} from #{env_var}"
      end
    end
  end
end
