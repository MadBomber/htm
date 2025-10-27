# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "htm"

require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# Mock embedding service for tests that don't require real Ollama
class MockEmbeddingService
  attr_reader :provider, :llm_client, :dimensions

  def initialize(provider = :ollama, model: 'gpt-oss', ollama_url: nil, dimensions: nil, cache_size: 1000)
    @provider = provider
    @model = model
    @ollama_url = ollama_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
    # Default to 1536 for most common embedding models
    # Database now supports up to 3072 dimensions (will auto-pad)
    # Respect HTM_EMBEDDINGS_DIMENSION if set
    @dimensions = dimensions || ENV['HTM_EMBEDDINGS_DIMENSION']&.to_i || 1536
    # Mock client object
    @llm_client = Object.new
    @tokenizer = Tiktoken.encoding_for_model("gpt-3.5-turbo")

    # Initialize embedding cache (same as real EmbeddingService)
    if cache_size > 0
      require 'lru_redux'
      require 'digest'
      @embedding_cache = LruRedux::Cache.new(cache_size)
      @cache_stats = { hits: 0, misses: 0 }
    end
  end

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

  def count_tokens(text)
    @tokenizer.encode(text.to_s).length
  rescue
    text.to_s.split.size
  end

  private

  def embed_uncached(text)
    # Return deterministic mock embeddings based on text hash
    seed = text.hash.abs
    @dimensions.times.map { |i| Random.new(seed + i).rand(-1.0..1.0) }
  end
end

# Helper to check if Ollama is available
def ollama_available?
  return @ollama_available if defined?(@ollama_available)

  begin
    require 'net/http'
    uri = URI.parse(ENV['OLLAMA_URL'] || 'http://localhost:11434')
    response = Net::HTTP.get_response(uri)
    @ollama_available = response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPOK)
  rescue
    @ollama_available = false
  end

  @ollama_available
end
