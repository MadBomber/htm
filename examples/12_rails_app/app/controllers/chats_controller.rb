# frozen_string_literal: true

require 'net/http'
require 'json'

class ChatsController < ApplicationController
  def index
    @chats = Chat.order(updated_at: :desc).limit(20)
    @current_chat = Chat.find_by(id: session[:chat_id])
  end

  def show
    @chat = Chat.find(params[:id])
    @messages = @chat.messages.order(:created_at)
    @available_providers = detect_available_providers
    current_provider = @chat.model&.provider || 'ollama'
    @available_models = fetch_models_for_provider(current_provider)
    session[:chat_id] = @chat.id
  end

  def create
    # Ensure Ollama is configured with /v1 suffix for OpenAI-compatible API
    RubyLLM.config.ollama_api_base ||= ENV.fetch('OLLAMA_URL', 'http://localhost:11434') + '/v1'

    @chat = Chat.new
    @chat.assume_model_exists = true
    @chat.model = ENV.fetch('CHAT_MODEL', 'gemma3:latest')
    @chat.provider = 'ollama'
    @chat.save!
    session[:chat_id] = @chat.id
    redirect_to chat_path(@chat)
  end

  def update
    @chat = Chat.find(params[:id])

    # Handle provider change
    if params[:provider].present?
      new_provider = params[:provider]
      # Get default model for the new provider
      models = fetch_models_for_provider(new_provider)
      default_model = models.first || "#{new_provider}-default"

      model = Model.find_or_create_by!(model_id: default_model, provider: new_provider) do |m|
        m.name = default_model
      end
      @chat.update_column(:model_id, model.id)
    # Handle model change
    elsif params[:model_id].present?
      current_provider = @chat.model&.provider || 'ollama'
      model = Model.find_or_create_by!(model_id: params[:model_id], provider: current_provider) do |m|
        m.name = params[:model_id]
      end
      @chat.update_column(:model_id, model.id)
    end

    redirect_to chat_path(@chat)
  end

  # API endpoint to get models for a provider (used by JavaScript)
  def models
    provider = params[:provider] || 'ollama'
    models = fetch_models_for_provider(provider)
    render json: models
  end

  def destroy
    Chat.find(params[:id]).destroy
    session.delete(:chat_id) if session[:chat_id] == params[:id].to_i
    redirect_to app_root_path, notice: 'Chat deleted'
  end

  private

  def detect_available_providers
    providers = []

    # Use RubyLLM's provider registry to dynamically detect available providers
    RubyLLM.providers.each do |provider_class|
      provider_id = provider_class.name.split('::').last.downcase
      display_name = provider_display_name(provider_id)

      if provider_class.local?
        # Local providers: check if service is reachable
        providers << { id: provider_id, name: "#{display_name} (Local)" } if local_provider_available?(provider_id)
      else
        # Cloud providers: check if required API key env var is set
        providers << { id: provider_id, name: display_name } if cloud_provider_configured?(provider_class)
      end
    end

    # Add custom local providers not in RubyLLM registry (use OpenAI-compatible API)
    providers << { id: 'lmstudio', name: 'LM Studio (Local)' } if lmstudio_available?

    providers
  end

  def provider_display_name(provider_id)
    {
      'openai' => 'OpenAI',
      'anthropic' => 'Anthropic',
      'gemini' => 'Google Gemini',
      'deepseek' => 'DeepSeek',
      'openrouter' => 'OpenRouter',
      'ollama' => 'Ollama',
      'gpustack' => 'GPUStack',
      'bedrock' => 'AWS Bedrock',
      'vertexai' => 'Google Vertex AI',
      'mistral' => 'Mistral',
      'perplexity' => 'Perplexity',
      'xai' => 'xAI',
      'lmstudio' => 'LM Studio'
    }[provider_id] || provider_id.titleize
  end

  def cloud_provider_configured?(provider_class)
    # Check if all required configuration keys have corresponding env vars set
    provider_class.configuration_requirements.all? do |config_key|
      # Convert config key like :anthropic_api_key to env var ANTHROPIC_API_KEY
      env_var = config_key.to_s.upcase
      ENV[env_var].present?
    end
  end

  def local_provider_available?(provider_id)
    case provider_id
    when 'ollama'
      ollama_available?
    when 'gpustack'
      gpustack_available?
    else
      false
    end
  end

  def ollama_available?
    ollama_url = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
    uri = URI("#{ollama_url}/api/tags")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  def gpustack_available?
    gpustack_url = ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:8080')
    uri = URI("#{gpustack_url}/v1/models")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  def lmstudio_available?
    lmstudio_url = ENV.fetch('LMSTUDIO_URL', 'http://localhost:1234')
    uri = URI("#{lmstudio_url}/v1/models")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  def fetch_models_for_provider(provider)
    case provider
    when 'ollama'
      fetch_ollama_models
    when 'gpustack'
      fetch_gpustack_models
    when 'lmstudio'
      fetch_lmstudio_models
    else
      fetch_models_from_registry(provider)
    end
  end

  # Use RubyLLM's model registry for cloud providers
  def fetch_models_from_registry(provider)
    # Get chat models for this provider from RubyLLM registry
    models = RubyLLM.models.by_provider(provider).chat_models
    model_ids = models.map(&:id).sort

    if model_ids.empty?
      Rails.logger.warn "No models found in RubyLLM registry for provider: #{provider}"
      # Return fallback models for common providers
      fallback_models_for(provider)
    else
      model_ids
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to fetch models from registry for #{provider}: #{e.message}"
    fallback_models_for(provider)
  end

  # Fallback models when registry is empty (e.g., not refreshed)
  def fallback_models_for(provider)
    case provider
    when 'openai'
      %w[gpt-4o gpt-4o-mini gpt-4-turbo gpt-4 gpt-3.5-turbo]
    when 'anthropic'
      %w[claude-sonnet-4-20250514 claude-3-5-sonnet-20241022 claude-3-5-haiku-20241022 claude-3-opus-20240229]
    when 'gemini'
      %w[gemini-2.0-flash gemini-1.5-pro gemini-1.5-flash]
    when 'deepseek'
      %w[deepseek-chat deepseek-coder]
    when 'openrouter'
      %w[openai/gpt-4o anthropic/claude-3.5-sonnet meta-llama/llama-3-70b-instruct]
    else
      []
    end
  end

  def fetch_ollama_models
    ollama_url = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
    response = Net::HTTP.get(URI("#{ollama_url}/api/tags"))
    data = JSON.parse(response)
    data['models'].map { |m| m['name'] }.sort
  rescue StandardError => e
    Rails.logger.warn "Failed to fetch Ollama models: #{e.message}"
    []
  end

  def fetch_gpustack_models
    gpustack_url = ENV.fetch('GPUSTACK_API_BASE', 'http://localhost:8080')
    response = Net::HTTP.get(URI("#{gpustack_url}/v1/models"))
    data = JSON.parse(response)
    data['data'].map { |m| m['id'] }.sort
  rescue StandardError => e
    Rails.logger.warn "Failed to fetch GPUStack models: #{e.message}"
    []
  end

  def fetch_lmstudio_models
    lmstudio_url = ENV.fetch('LMSTUDIO_URL', 'http://localhost:1234')
    response = Net::HTTP.get(URI("#{lmstudio_url}/v1/models"))
    data = JSON.parse(response)
    data['data'].map { |m| m['id'] }.sort
  rescue StandardError => e
    Rails.logger.warn "Failed to fetch LM Studio models: #{e.message}"
    []
  end
end
