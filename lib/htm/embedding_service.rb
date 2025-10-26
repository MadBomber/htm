# frozen_string_literal: true

require 'tiktoken_ruby'
require 'ruby_llm'
require_relative 'errors'

class HTM
  # Embedding Service - Generate vector embeddings for semantic search
  #
  # Supports multiple embedding providers:
  # - :ollama - Ollama with gpt-oss model (default, via RubyLLM)
  # - :openai - OpenAI text-embedding-3-small
  # - :cohere - Cohere embeddings
  # - :local - Local sentence transformers
  #
  class EmbeddingService
    # Known embedding dimensions for common models
    KNOWN_DIMENSIONS = {
      # Ollama models
      'gpt-oss' => 768,
      'nomic-embed-text' => 768,
      'all-minilm' => 384,
      'mxbai-embed-large' => 1024,

      # OpenAI models
      'text-embedding-3-small' => 1536,
      'text-embedding-3-large' => 3072,
      'text-embedding-ada-002' => 1536,

      # Cohere models
      'embed-english-v3.0' => 1024,
      'embed-multilingual-v3.0' => 1024,

      # Local models (sentence-transformers)
      'all-MiniLM-L6-v2' => 384,
      'all-mpnet-base-v2' => 768
    }.freeze

    attr_reader :provider, :llm_client, :dimensions

    # Initialize embedding service
    #
    # @param provider [Symbol] Embedding provider (:ollama, :openai, :cohere, :local)
    # @param model [String] Model name (default: 'gpt-oss' for ollama)
    # @param ollama_url [String] Ollama server URL (default: http://localhost:11434)
    # @param dimensions [Integer] Expected embedding dimensions (auto-detected from KNOWN_DIMENSIONS if not provided)
    #
    def initialize(provider = :ollama, model: 'gpt-oss', ollama_url: nil, dimensions: nil)
      @provider = provider
      @model = model
      @ollama_url = ollama_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
      @tokenizer = Tiktoken.encoding_for_model("gpt-3.5-turbo")

      # Auto-detect dimensions from known models, or use provided value
      @dimensions = dimensions || KNOWN_DIMENSIONS[@model]

      # Warn if we don't know the expected dimensions
      if @dimensions.nil?
        warn "WARNING: Unknown embedding dimensions for model '#{@model}'. Dimension validation disabled."
      end

      # Note: RubyLLM is used via direct Ollama API calls for embeddings
      # We don't need to initialize RubyLLM::Client here since we're making
      # direct HTTP requests to the Ollama embeddings endpoint
      @llm_client = nil  # Placeholder for compatibility
    end

    # Generate embedding for text
    #
    # @param text [String] Text to embed
    # @return [Array<Float>] Embedding vector (dimensions vary by model)
    #
    def embed(text)
      case @provider
      when :ollama
        embed_ollama(text)
      when :openai
        embed_openai(text)
      when :cohere
        embed_cohere(text)
      when :local
        embed_local(text)
      else
        raise "Unknown embedding provider: #{@provider}"
      end
    end

    # Count tokens in text
    #
    # @param text [String] Text to count
    # @return [Integer] Token count
    #
    def count_tokens(text)
      @tokenizer.encode(text.to_s).length
    rescue
      # Fallback to simple word count if tokenizer fails
      text.to_s.split.size
    end

    private

    def embed_ollama(text)
      # Use Ollama to generate embeddings via direct API call
      # This approach works with RubyLLM by making direct HTTP requests to Ollama's API
      begin
        require 'net/http'
        require 'json'
        require 'uri'

        uri = URI.parse("#{@ollama_url}/api/embeddings")

        request = Net::HTTP::Post.new(uri)
        request.content_type = 'application/json'
        request.body = {
          model: @model,
          prompt: text
        }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          embedding = result['embedding']

          unless embedding.is_a?(Array) && !embedding.empty?
            raise HTM::EmbeddingError, "Invalid embedding received from Ollama API for model '#{@model}'"
          end

          # Validate dimensions if known
          if @dimensions && embedding.length != @dimensions
            raise HTM::EmbeddingError, "Embedding dimension mismatch for model '#{@model}': expected #{@dimensions}, got #{embedding.length}"
          end

          embedding
        else
          raise HTM::EmbeddingError, "Ollama API error: #{response.code} #{response.message}. Ensure Ollama is running and model '#{@model}' is available."
        end
      rescue JSON::ParserError => e
        raise HTM::EmbeddingError, "Failed to parse Ollama response: #{e.message}"
      rescue Errno::ECONNREFUSED
        raise HTM::EmbeddingError, "Cannot connect to Ollama at #{@ollama_url}. Ensure Ollama is running."
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise HTM::EmbeddingError, "Timeout connecting to Ollama: #{e.message}"
      rescue HTM::EmbeddingError
        # Re-raise our own errors without wrapping
        raise
      rescue StandardError => e
        raise HTM::EmbeddingError, "Unexpected error generating embedding: #{e.class} - #{e.message}"
      end
    end

    def embed_openai(text)
      # TODO: Implement actual OpenAI API call
      # For now, return a stub embedding with configured dimensions
      # This should be replaced with:
      # require 'openai'
      # client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
      # response = client.embeddings(
      #   parameters: {
      #     model: @model,
      #     input: text
      #   }
      # )
      # response.dig("data", 0, "embedding")

      dim = @dimensions || 1536
      warn "STUB: Using random #{dim}-dimensional embeddings. Implement OpenAI API integration for production."
      Array.new(dim) { rand(-1.0..1.0) }
    end

    def embed_cohere(text)
      # TODO: Implement Cohere API call
      dim = @dimensions || 1024
      warn "STUB: Cohere embedding not yet implemented. Using random #{dim}-dimensional embeddings."
      Array.new(dim) { rand(-1.0..1.0) }
    end

    def embed_local(text)
      # TODO: Implement local sentence transformers
      dim = @dimensions || 384
      warn "STUB: Local embedding not yet implemented. Using random #{dim}-dimensional embeddings."
      Array.new(dim) { rand(-1.0..1.0) }
    end
  end
end
