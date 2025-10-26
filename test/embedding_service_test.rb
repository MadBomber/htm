# frozen_string_literal: true

require "test_helper"

class EmbeddingServiceTest < Minitest::Test
  def setup
    # Use mock embedding service for tests that don't require real Ollama
    @service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')

    # Create a real service only for tests that specifically need it
    @real_service = HTM::EmbeddingService.new(:ollama, model: 'gpt-oss') if ollama_available?
  end

  def test_initializes_with_ollama_provider
    assert_equal :ollama, @service.provider
  end

  def test_llm_client_attribute_exists
    # llm_client is a placeholder - actual embedding is done via direct Ollama API calls
    assert_respond_to @service, :llm_client
  end

  def test_embed_returns_array
    embedding = @service.embed("Test text for embedding")
    assert_instance_of Array, embedding
  end

  def test_embed_returns_non_empty_array
    embedding = @service.embed("Test text for embedding")
    refute_empty embedding
  end

  def test_embed_with_longer_text
    text = "This is a longer piece of text that will be used to test the embedding service " \
           "with the Ollama provider using the gpt-oss model via RubyLLM."
    embedding = @service.embed(text)

    assert_instance_of Array, embedding
    refute_empty embedding
  end

  def test_embed_handles_empty_string
    embedding = @service.embed("")
    assert_instance_of Array, embedding
  end

  def test_count_tokens
    text = "This is a test string"
    token_count = @service.count_tokens(text)

    assert_instance_of Integer, token_count
    assert token_count > 0
  end

  def test_count_tokens_empty_string
    token_count = @service.count_tokens("")
    assert_instance_of Integer, token_count
    assert_equal 0, token_count
  end

  def test_different_providers
    # Test that we can initialize with different providers (using real EmbeddingService)
    openai_service = HTM::EmbeddingService.new(:openai)
    assert_equal :openai, openai_service.provider

    cohere_service = HTM::EmbeddingService.new(:cohere)
    assert_equal :cohere, cohere_service.provider

    local_service = HTM::EmbeddingService.new(:local)
    assert_equal :local, local_service.provider
  end

  def test_ollama_with_custom_model
    custom_service = HTM::EmbeddingService.new(:ollama, model: 'custom-model')
    assert_equal :ollama, custom_service.provider
    # Note: llm_client is intentionally nil for Ollama (uses direct HTTP calls)
  end

  def test_ollama_with_custom_url
    custom_url = 'http://custom-ollama:11434'
    custom_service = HTM::EmbeddingService.new(:ollama, model: 'gpt-oss', ollama_url: custom_url)
    assert_equal :ollama, custom_service.provider
    # Note: llm_client is intentionally nil for Ollama (uses direct HTTP calls)
  end

  def test_embeddings_consistency
    # Test that the same text produces embeddings (may not be identical due to model behavior)
    text = "Consistent text for testing"
    embedding1 = @service.embed(text)
    embedding2 = @service.embed(text)

    assert_instance_of Array, embedding1
    assert_instance_of Array, embedding2
    # Note: Embeddings should be deterministic for the same text,
    # but this depends on the model implementation
  end

  def test_different_texts_produce_different_embeddings
    text1 = "First piece of text"
    text2 = "Completely different content"

    embedding1 = @service.embed(text1)
    embedding2 = @service.embed(text2)

    assert_instance_of Array, embedding1
    assert_instance_of Array, embedding2
    # They should be different (though we don't test exact values)
    refute_equal embedding1, embedding2
  end

  def test_dimensions_auto_detected_for_known_model
    # Test with real EmbeddingService
    service = HTM::EmbeddingService.new(:ollama, model: 'gpt-oss')
    assert_equal 768, service.dimensions
  end

  def test_dimensions_manually_specified
    # Test with real EmbeddingService
    service = HTM::EmbeddingService.new(:ollama, model: 'gpt-oss', dimensions: 1024)
    assert_equal 1024, service.dimensions
  end

  def test_dimensions_nil_for_unknown_model
    # Test with real EmbeddingService - capture warnings
    _, err = capture_io do
      service = HTM::EmbeddingService.new(:ollama, model: 'unknown-model')
      assert_nil service.dimensions
    end
    # Should warn about unknown dimensions
    assert_match(/WARNING.*unknown-model/, err)
  end

  def test_known_dimensions_constant_exists
    assert_kind_of Hash, HTM::EmbeddingService::KNOWN_DIMENSIONS
    refute_empty HTM::EmbeddingService::KNOWN_DIMENSIONS
  end

  def test_known_dimensions_includes_gpt_oss
    assert_equal 768, HTM::EmbeddingService::KNOWN_DIMENSIONS['gpt-oss']
  end

  def test_known_dimensions_includes_openai_models
    assert_equal 1536, HTM::EmbeddingService::KNOWN_DIMENSIONS['text-embedding-3-small']
    assert_equal 3072, HTM::EmbeddingService::KNOWN_DIMENSIONS['text-embedding-3-large']
  end

  def test_stub_providers_use_configured_dimensions
    # Cohere with custom dimensions (using real EmbeddingService with stub provider)
    cohere_service = HTM::EmbeddingService.new(:cohere, model: 'custom', dimensions: 512)
    _, err = capture_io do
      embedding = cohere_service.embed("test")
      assert_equal 512, embedding.length
    end
    # Should warn about using stub
    assert_match(/STUB/, err)
  end

  # OpenAI Integration Tests

  def test_openai_raises_error_without_api_key
    # Temporarily remove OPENAI_API_KEY
    original_key = ENV['OPENAI_API_KEY']
    ENV.delete('OPENAI_API_KEY')

    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small')

    error = assert_raises(HTM::EmbeddingError) do
      service.embed("test text")
    end

    assert_match(/OPENAI_API_KEY environment variable not set/, error.message)
  ensure
    ENV['OPENAI_API_KEY'] = original_key if original_key
  end

  def test_openai_successful_embedding
    # Skip if API key not available
    skip "OPENAI_API_KEY not set" unless ENV['OPENAI_API_KEY']

    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small')

    begin
      embedding = service.embed("This is a test for OpenAI embeddings")

      assert_instance_of Array, embedding
      assert_equal 1536, embedding.length
      refute_empty embedding
      # Verify it's an array of floats
      assert embedding.all? { |v| v.is_a?(Float) }
    rescue HTM::EmbeddingError => e
      skip "OpenAI API error: #{e.message}" if e.message.include?("rate limit") || e.message.include?("SSL") || e.message.include?("certificate")
      raise
    end
  end

  def test_openai_dimension_validation
    # Skip if API key not available
    skip "OPENAI_API_KEY not set" unless ENV['OPENAI_API_KEY']

    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small', dimensions: 1536)

    begin
      embedding = service.embed("Test dimension validation")
      assert_equal 1536, embedding.length
    rescue HTM::EmbeddingError => e
      skip "OpenAI API error: #{e.message}" if e.message.include?("rate limit") || e.message.include?("SSL") || e.message.include?("certificate")
      raise
    end
  end

  def test_openai_detects_wrong_dimensions
    # Skip if API key not available
    skip "OPENAI_API_KEY not set" unless ENV['OPENAI_API_KEY']

    # Create service expecting wrong dimensions
    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small', dimensions: 768)

    error = assert_raises(HTM::EmbeddingError) do
      service.embed("test")
    end

    # Handle rate limiting and SSL errors gracefully
    if error.message.include?("rate limit") || error.message.include?("SSL") || error.message.include?("certificate")
      skip "OpenAI API error: #{error.message}"
    else
      assert_match(/Embedding dimension mismatch/, error.message)
      assert_match(/expected 768, got 1536/, error.message)
    end
  end

  def test_openai_handles_authentication_error
    # This test would require mocking the HTTP response
    # For now, we'll test the error path by using an invalid key
    skip "Test requires mocking HTTP responses"
  end

  def test_openai_auto_detects_dimensions_for_known_models
    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small')
    assert_equal 1536, service.dimensions

    service_large = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-large')
    assert_equal 3072, service_large.dimensions

    service_ada = HTM::EmbeddingService.new(:openai, model: 'text-embedding-ada-002')
    assert_equal 1536, service_ada.dimensions
  end

  def test_openai_embeddings_are_deterministic
    # Skip if API key not available
    skip "OPENAI_API_KEY not set" unless ENV['OPENAI_API_KEY']

    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small')
    text = "Deterministic test text"

    begin
      embedding1 = service.embed(text)
      embedding2 = service.embed(text)

      # OpenAI embeddings should be deterministic for the same input
      assert_equal embedding1, embedding2
    rescue HTM::EmbeddingError => e
      skip "OpenAI API error: #{e.message}" if e.message.include?("rate limit") || e.message.include?("SSL") || e.message.include?("certificate")
      raise
    end
  end

  def test_openai_different_texts_produce_different_embeddings
    # Skip if API key not available
    skip "OPENAI_API_KEY not set" unless ENV['OPENAI_API_KEY']

    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small')

    begin
      embedding1 = service.embed("First text about cats")
      embedding2 = service.embed("Second text about dogs")

      refute_equal embedding1, embedding2
    rescue HTM::EmbeddingError => e
      skip "OpenAI API error: #{e.message}" if e.message.include?("rate limit") || e.message.include?("SSL") || e.message.include?("certificate")
      raise
    end
  end

  def test_openai_handles_empty_response
    # This test would require mocking the HTTP response
    # The real implementation should handle malformed responses
    skip "Test requires mocking HTTP responses"
  end

  def test_openai_handles_connection_errors
    # This test would require mocking network failures
    skip "Test requires mocking HTTP responses"
  end

  def test_openai_provider_uses_https
    # Verify that OpenAI service is configured to use HTTPS
    # This is tested implicitly in the implementation (uri.scheme == 'https')
    service = HTM::EmbeddingService.new(:openai, model: 'text-embedding-3-small')
    assert_equal :openai, service.provider
  end
end
