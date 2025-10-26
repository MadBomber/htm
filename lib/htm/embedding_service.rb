# frozen_string_literal: true

require 'tiktoken_ruby'
require 'ruby_llm'
require 'lru_redux'
require 'digest'
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
    DEFAULT_CACHE_SIZE = 1000  # Number of embeddings to cache

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
    # @param cache_size [Integer] Number of embeddings to cache (default: 1000, use 0 to disable)
    #
    def initialize(provider = :ollama, model: 'gpt-oss', ollama_url: nil, dimensions: nil, cache_size: DEFAULT_CACHE_SIZE)
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

      # Initialize embedding cache (disable with cache_size: 0)
      if cache_size > 0
        @embedding_cache = LruRedux::Cache.new(cache_size)
        @cache_stats = { hits: 0, misses: 0 }
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
      # Return uncached if cache disabled
      return embed_uncached(text) unless @embedding_cache

      # Generate cache key from text
      cache_key = Digest::SHA256.hexdigest(text)

      # Try to get from cache
      cached = @embedding_cache[cache_key]
      if cached
        @cache_stats[:hits] += 1
        return cached
      end

      # Cache miss - generate embedding
      @cache_stats[:misses] += 1
      embedding = embed_uncached(text)

      # Store in cache
      @embedding_cache[cache_key] = embedding
      embedding
    end

    # Get cache statistics
    #
    # @return [Hash, nil] Cache stats or nil if cache disabled
    #
    def cache_stats
      return nil unless @embedding_cache

      total = @cache_stats[:hits] + @cache_stats[:misses]
      hit_rate = total > 0 ? (@cache_stats[:hits].to_f / total * 100).round(2) : 0.0

      {
        hits: @cache_stats[:hits],
        misses: @cache_stats[:misses],
        hit_rate: hit_rate,
        size: @embedding_cache.count
      }
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

    # Generate embedding without caching
    #
    # @param text [String] Text to embed
    # @return [Array<Float>] Embedding vector
    #
    def embed_uncached(text)
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
      # OpenAI API implementation
      require 'net/http'
      require 'json'
      require 'uri'

      api_key = ENV['OPENAI_API_KEY']
      unless api_key
        raise HTM::EmbeddingError, "OPENAI_API_KEY environment variable not set. Set it to use OpenAI embeddings."
      end

      uri = URI.parse('https://api.openai.com/v1/embeddings')
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{api_key}"
      request['Content-Type'] = 'application/json'
      request.body = {
        model: @model,
        input: text
      }.to_json

      begin
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          embedding = result.dig('data', 0, 'embedding')

          unless embedding.is_a?(Array) && !embedding.empty?
            raise HTM::EmbeddingError, "Invalid embedding received from OpenAI API for model '#{@model}'"
          end

          # Validate dimensions if known
          if @dimensions && embedding.length != @dimensions
            raise HTM::EmbeddingError, "Embedding dimension mismatch for model '#{@model}': expected #{@dimensions}, got #{embedding.length}"
          end

          embedding
        elsif response.code == '401'
          raise HTM::EmbeddingError, "OpenAI API authentication failed. Check your OPENAI_API_KEY."
        elsif response.code == '429'
          raise HTM::EmbeddingError, "OpenAI API rate limit exceeded. Please try again later."
        elsif response.code.start_with?('4')
          error_msg = JSON.parse(response.body).dig('error', 'message') rescue response.message
          raise HTM::EmbeddingError, "OpenAI API client error: #{error_msg}"
        elsif response.code.start_with?('5')
          raise HTM::EmbeddingError, "OpenAI API server error: #{response.code} #{response.message}"
        else
          raise HTM::EmbeddingError, "OpenAI API error: #{response.code} #{response.message}"
        end
      rescue JSON::ParserError => e
        raise HTM::EmbeddingError, "Failed to parse OpenAI response: #{e.message}"
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
        raise HTM::EmbeddingError, "Cannot connect to OpenAI API: #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise HTM::EmbeddingError, "Timeout connecting to OpenAI API: #{e.message}"
      rescue HTM::EmbeddingError
        # Re-raise our own errors without wrapping
        raise
      rescue StandardError => e
        raise HTM::EmbeddingError, "Unexpected error calling OpenAI API: #{e.class} - #{e.message}"
      end
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
