# frozen_string_literal: true

require 'tiktoken_ruby'
require_relative 'errors'

class HTM
  # Embedding Service - Client-side embedding generation
  #
  # HTM uses client-side embedding generation via this service.
  # Embeddings are generated before inserting nodes into the database.
  #
  # Supported providers:
  # - :ollama - Ollama with configurable model (default: nomic-embed-text)
  # - :openai - OpenAI embeddings (requires OPENAI_API_KEY)
  #
  class EmbeddingService
    # Known embedding dimensions for common models
    KNOWN_DIMENSIONS = {
      # Ollama models
      'nomic-embed-text' => 768,
      'all-minilm' => 384,
      'mxbai-embed-large' => 1024,
      'embeddinggemma' => 768,
      'embeddinggemma:latest' => 768,

      # OpenAI models
      'text-embedding-3-small' => 1536,
      'text-embedding-3-large' => 3072,
      'text-embedding-ada-002' => 1536
    }.freeze

    attr_reader :provider, :model, :dimensions

    # Initialize embedding service
    #
    # @param provider [Symbol] Embedding provider (:ollama, :openai)
    # @param model [String] Model name (default: 'nomic-embed-text' for ollama)
    # @param ollama_url [String] Ollama server URL (default: http://localhost:11434)
    # @param dimensions [Integer] Expected embedding dimensions (auto-detected if not provided)
    #
    def initialize(provider = :ollama, model: nil, ollama_url: nil, dimensions: nil, db_config: nil)
      @provider = provider
      @model = model || default_model_for_provider(provider)
      @ollama_url = ollama_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
      @tokenizer = Tiktoken.encoding_for_model("gpt-3.5-turbo")

      # Auto-detect dimensions from known models, or use provided value
      @dimensions = dimensions || KNOWN_DIMENSIONS[@model]

      # Warn if we don't know the expected dimensions
      if @dimensions.nil?
        warn "WARNING: Unknown embedding dimensions for model '#{@model}'. Using default 768."
      end
    end

    # Count tokens in text
    #
    # @param text [String] Text to count
    # @return [Integer] Token count
    #
    def count_tokens(text)
      @tokenizer.encode(text.to_s).length
    rescue StandardError
      # Fallback to simple word count if tokenizer fails
      text.to_s.split.size
    end

    # Get embedding dimensions for current model
    #
    # @return [Integer] Embedding dimensions
    #
    def embedding_dimensions
      @dimensions || KNOWN_DIMENSIONS[@model] || 768
    end

    # Generate embedding for text
    #
    # Generates embeddings client-side using the configured provider.
    #
    # @param text [String] Text to embed
    # @return [Array<Float>] Embedding vector
    #
    def embed(text)
      case @provider
      when :ollama
        embed_with_ollama(text)
      when :openai
        embed_with_openai(text)
      else
        raise HTM::EmbeddingError, "Unknown provider: #{@provider}"
      end
    end

    private

    def default_model_for_provider(provider)
      case provider
      when :ollama
        'nomic-embed-text'
      when :openai
        'text-embedding-3-small'
      else
        raise HTM::EmbeddingError, "Unknown provider: #{provider}"
      end
    end

    def embed_with_ollama(text)
      require 'net/http'
      require 'json'

      uri = URI("#{@ollama_url}/api/embed")
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate({
        model: @model,
        input: text
      })

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        error_details = "#{response.code} #{response.message}"
        begin
          error_body = JSON.parse(response.body)
          error_details += " - #{error_body['error']}" if error_body['error']
        rescue
          error_details += " - #{response.body[0..200]}" unless response.body.empty?
        end
        raise HTM::EmbeddingError, "Ollama API error: #{error_details}"
      end

      result = JSON.parse(response.body)
      # Ollama returns embeddings as an array, get the first one
      result['embeddings']&.first || result['embedding']
    rescue HTM::EmbeddingError
      raise
    rescue StandardError => e
      raise HTM::EmbeddingError, "Failed to generate embedding with Ollama: #{e.message}"
    end

    def embed_with_openai(text)
      require 'net/http'
      require 'json'

      api_key = ENV['OPENAI_API_KEY']
      unless api_key
        raise HTM::EmbeddingError, "OPENAI_API_KEY environment variable not set"
      end

      uri = URI('https://api.openai.com/v1/embeddings')
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{api_key}"
      request.body = JSON.generate({
        model: @model,
        input: text
      })

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise HTM::EmbeddingError, "OpenAI API error: #{response.code} #{response.message}"
      end

      result = JSON.parse(response.body)
      result.dig('data', 0, 'embedding')
    rescue StandardError => e
      raise HTM::EmbeddingError, "Failed to generate embedding with OpenAI: #{e.message}"
    end
  end
end
