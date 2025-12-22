# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Ensure test environment is set BEFORE loading HTM
# This is critical because HTM::Config reads environment at load time
ENV['HTM_ENV'] = 'test'

# Safety check: Refuse to run tests against non-test databases
# Database name must end with _test (e.g., htm_test, myapp_test)
if ENV['HTM_DATABASE__URL'] && !ENV['HTM_DATABASE__URL'].include?('_test')
  service_name = ENV['HTM_SERVICE__NAME'] || 'htm'
  abort <<~ERROR
    SAFETY CHECK FAILED: Tests must run against a test database!

    HTM_DATABASE__URL is set to: #{ENV['HTM_DATABASE__URL']}

    This does not appear to be a test database (must contain '_test').
    Running tests against development or production databases can corrupt data.

    To fix, either:
      1. Run tests via: rake test (recommended)
      2. Set: export HTM_DATABASE__URL="postgresql://#{ENV['USER']}@localhost:5432/#{service_name}_test"
      3. Unset HTM_DATABASE__URL and let defaults.yml handle it

  ERROR
end

require "htm"

require "minitest/autorun"
require "minitest/reporters"
require "tiktoken_ruby"

# Use SpecReporter with failure summary at end
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# Collect failures and errors to display summary at end
module Minitest
  class << self
    attr_accessor :failure_details
  end
  self.failure_details = []
end

# Hook to collect failure details
module FailureCollector
  def record(result)
    super
    if result.failure
      Minitest.failure_details << result
    end
  end
end

Minitest::Reporters::SpecReporter.prepend(FailureCollector)

# Print failure summary after all tests complete
Minitest.after_run do
  if Minitest.failure_details.any?
    puts "\n"
    puts "=" * 70
    puts "FAILURE SUMMARY (#{Minitest.failure_details.size} failures/errors)"
    puts "=" * 70

    Minitest.failure_details.each_with_index do |result, idx|
      puts "\n#{idx + 1}) #{result.class}##{result.name}"
      puts "-" * 70

      failure = result.failure
      case failure
      when Minitest::UnexpectedError
        puts "Error: #{failure.error.class}: #{failure.error.message}"
        puts failure.error.backtrace.first(10).map { |line| "  #{line}" }.join("\n")
      else
        puts "Failure: #{failure.message}"
        puts "Location: #{failure.location}"
      end
    end

    puts "\n" + "=" * 70
  end
end

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

# Configure HTM with mock services for testing
#
# @param dimensions [Integer] Embedding dimensions (default: 768)
# @return [MockEmbeddingService] The mock service instance
#
def configure_htm_with_mocks(dimensions: 768)
  mock_service = MockEmbeddingService.new(dimensions: dimensions)

  HTM.configure do |config|
    # Use inline backend for synchronous test execution
    config.job.backend = :inline

    # Mock embedding generator
    config.embedding_generator = ->(text) {
      seed = text.hash.abs
      dimensions.times.map { |i| Random.new(seed + i).rand(-1.0..1.0) }
    }

    # Mock tag extractor (returns empty tags to speed up tests)
    config.tag_extractor = ->(text, ontology) { [] }

    # Mock proposition extractor (returns empty propositions to speed up tests)
    config.proposition_extractor = ->(text) { [] }

    # Disable proposition extraction by default in tests
    config.proposition.enabled = false

    # Mock token counter
    config.token_counter = ->(text) {
      begin
        Tiktoken.encoding_for_model("gpt-3.5-turbo").encode(text.to_s).length
      rescue
        text.to_s.split.size
      end
    }

    # Set embedding dimensions
    config.embedding.dimensions = dimensions
  end

  mock_service
end

# Reset HTM configuration to defaults
def reset_htm_configuration
  HTM.reset_configuration!
  # Set inline backend for tests
  HTM.configuration.job.backend = :inline
end

# Check if database is available for integration tests
# Returns true if database is configured (via URL or individual settings) and we can connect
def database_available?
  return @database_available if defined?(@database_available)

  begin
    # Check if connection is already established and working
    if HTM::ActiveRecordConfig.connected?
      @database_available = true
      return true
    end

    # Check if database is configured via the config system
    # This works with HTM_DATABASE__URL env var OR individual settings
    # from defaults.yml (e.g., htm_test for test environment)
    unless HTM.config.database_configured?
      @database_available = false
      return false
    end

    # Establish connection using HTM's config
    HTM::ActiveRecordConfig.establish_connection!
    @database_available = HTM::ActiveRecordConfig.connected?
  rescue => e
    @database_available = false
  end

  @database_available
end

# Helper method for tests that require database
# Use in setup: `skip_without_database` (returns early if DB not available)
def skip_without_database
  unless database_available?
    skip "Database not configured or unavailable. Set HTM_DATABASE__URL or ensure defaults.yml database settings are correct."
  end
end

# Setup default test configuration
configure_htm_with_mocks
