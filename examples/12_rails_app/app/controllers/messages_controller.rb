# frozen_string_literal: true

class MessagesController < ApplicationController
  def create
    @chat = Chat.find(params[:chat_id])
    user_content = params[:content]

    # Configure RubyLLM for the chat's provider
    configure_provider(@chat.model&.provider || 'ollama')

    # 1. Retrieve context from HTM (RAG)
    # Use fulltext search since not all nodes have embeddings for vector search
    context_results = begin
      results = htm.recall(user_content, limit: 5, strategy: :fulltext)
      Rails.logger.info "HTM recall returned #{results.size} results for: #{user_content[0..50]}"
      Rails.logger.debug "HTM result types: #{results.map { |r| r.class.name }.join(', ')}"
      results.each_with_index do |r, i|
        preview = r.respond_to?(:content) ? r.content.to_s[0..100] : r.to_s[0..100]
        Rails.logger.debug "HTM result[#{i}]: #{preview}..."
      end
      results
    rescue StandardError => e
      Rails.logger.warn "HTM recall failed: #{e.class}: #{e.message}"
      Rails.logger.warn e.backtrace.first(5).join("\n")
      []
    end
    context_text = format_context(context_results)
    Rails.logger.info "Built context (#{context_text.length} chars): #{context_text[0..200]}..."

    # 2. Build system prompt with HTM context
    system_prompt = build_system_prompt(context_text)

    # 3. Use RubyLLM's acts_as_chat to handle the conversation
    # Ensure chat has a valid Model record
    ensure_model_record(@chat)

    # For cloud providers, bypass model registry lookup since it may not be populated
    # This allows using any model supported by the provider's API
    @chat.assume_model_exists = true

    @chat.with_instructions(system_prompt, replace: true)

    begin
      @chat.ask(user_content)
    rescue RubyLLM::Error => e
      # Create a user message so the conversation shows what was asked
      @chat.messages.create!(role: 'user', content: user_content)
      # Create an assistant message showing the error
      @chat.messages.create!(
        role: 'assistant',
        content: "**Error from #{@chat.model&.provider || 'provider'}:** #{e.message}"
      )
      Rails.logger.error "LLM Error: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
    end

    redirect_to chat_path(@chat)
  end

  private

  def format_context(results)
    return 'No relevant context found.' if results.empty?

    results.map.with_index do |r, i|
      # Handle different result formats from HTM
      # fulltext search returns Node objects, vector search may return hashes
      content = if r.is_a?(String)
                  r
                elsif r.is_a?(Hash)
                  r[:content] || r['content']
                elsif r.respond_to?(:content)
                  r.content
                else
                  r.to_s
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
    # Get the stored model_id (could be a string name or an integer ID)
    stored_value = chat[:model_id]

    # Check if it's already a valid Model record ID
    if stored_value.to_s =~ /^\d+$/
      model = Model.find_by(id: stored_value)
      return if model.present?
    end

    # It's a model name string - find or create the Model record
    model_name = stored_value.presence || ENV.fetch('CHAT_MODEL', 'gemma3:latest')
    model = Model.find_or_create_by!(model_id: model_name, provider: 'ollama') do |m|
      m.name = model_name
    end

    # Update the chat to use the Model record ID
    chat.update_column(:model_id, model.id)
    chat.reload
  end

  def configure_provider(provider)
    Rails.logger.info "=== configure_provider called with: #{provider} ==="
    Rails.logger.info "  ENV check - OPENAI_API_KEY set: #{ENV['OPENAI_API_KEY'].present?}"
    Rails.logger.info "  ENV check - XAI_API_KEY set: #{ENV['XAI_API_KEY'].present?}"
    Rails.logger.info "  ENV check - OLLAMA_URL: #{ENV['OLLAMA_URL']}"
    Rails.logger.info "  ENV check - LMSTUDIO_URL: #{ENV['LMSTUDIO_URL']}"

    # Clear potentially conflicting OpenAI config when switching to local providers
    # This prevents LM Studio config from affecting Ollama and vice versa
    if %w[ollama lmstudio gpustack].include?(provider)
      # Reset OpenAI settings that might interfere with local providers
      if provider != 'lmstudio'
        # Only clear OpenAI config if NOT switching to LM Studio
        # (since LM Studio uses OpenAI-compatible API)
        Rails.logger.info "  Clearing OpenAI config for local provider: #{provider}"
        RubyLLM.config.openai_api_base = nil
        RubyLLM.config.openai_api_key = ENV['OPENAI_API_KEY'] # Restore from env
      end
    end

    # Special handling for local providers that need URL configuration
    case provider
    when 'ollama'
      # Ollama's OpenAI-compatible API requires /v1 suffix
      base_url = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
      base_url = "#{base_url}/v1" unless base_url.end_with?('/v1')
      RubyLLM.config.ollama_api_base = base_url
      Rails.logger.info "Configured Ollama API base: #{RubyLLM.config.ollama_api_base}"
    when 'gpustack'
      base_url = ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:8080')
      RubyLLM.config.gpustack_api_base = base_url
      Rails.logger.info "Configured GPUStack API base: #{base_url}"
    when 'lmstudio'
      # LM Studio uses OpenAI-compatible API - configure as OpenAI with custom base URL
      # IMPORTANT: Must override any existing OpenAI config to route to LM Studio
      base_url = ENV.fetch('LMSTUDIO_URL', 'http://localhost:1234')
      base_url = "#{base_url}/v1" unless base_url.end_with?('/v1')
      RubyLLM.config.openai_api_base = base_url
      RubyLLM.config.openai_api_key = 'lm-studio' # LM Studio doesn't require a real key
      Rails.logger.info "Configured LM Studio: api_base=#{RubyLLM.config.openai_api_base}, api_key=#{RubyLLM.config.openai_api_key}"
    else
      # Cloud providers: dynamically configure from env vars based on RubyLLM's requirements
      provider_class = RubyLLM.providers.find { |p| p.name.split('::').last.downcase == provider }
      return unless provider_class

      provider_class.configuration_requirements.each do |config_key|
        env_var = config_key.to_s.upcase
        if ENV[env_var].present?
          RubyLLM.config.send("#{config_key}=", ENV[env_var])
        end
      end
    end
  end
end
