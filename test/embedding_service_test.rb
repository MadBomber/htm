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
    # OpenAI with custom dimensions (using real EmbeddingService with stub provider)
    openai_service = HTM::EmbeddingService.new(:openai, model: 'custom', dimensions: 512)
    _, err = capture_io do
      embedding = openai_service.embed("test")
      assert_equal 512, embedding.length
    end
    # Should warn about using stub
    assert_match(/STUB/, err)
  end
end
