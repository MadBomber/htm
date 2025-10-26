# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "htm"

require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

# Mock embedding service for tests that don't require real Ollama
class MockEmbeddingService
  attr_reader :provider, :llm_client, :dimensions

  def initialize(provider = :ollama, model: 'gpt-oss', ollama_url: nil, dimensions: nil)
    @provider = provider
    @model = model
    # Use 1536 to match existing database schema (vector(1536) in schema.sql)
    # TODO: Make database schema support variable dimensions
    @dimensions = dimensions || 1536
    @llm_client = nil
    @tokenizer = Tiktoken.encoding_for_model("gpt-3.5-turbo")
  end

  def embed(text)
    # Return deterministic mock embeddings based on text hash
    seed = text.hash.abs
    @dimensions.times.map { |i| Random.new(seed + i).rand(-1.0..1.0) }
  end

  def count_tokens(text)
    @tokenizer.encode(text.to_s).length
  rescue
    text.to_s.split.size
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
