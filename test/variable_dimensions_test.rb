# frozen_string_literal: true

require "test_helper"

class VariableDimensionsTest < Minitest::Test
  def setup
    # Most tests don't require database, just constants
  end

  def test_database_max_dimension_constant
    assert_equal 2000, HTM::LongTermMemory::MAX_VECTOR_DIMENSION
  end

  def test_supported_providers_constant
    assert_instance_of Array, HTM::Config::SUPPORTED_PROVIDERS
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :openai
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :ollama
    assert_includes HTM::Config::SUPPORTED_PROVIDERS, :anthropic
  end

  def test_default_dimensions_by_provider
    defaults = HTM::Config::DEFAULT_DIMENSIONS
    assert_instance_of Hash, defaults
    assert_equal 1536, defaults[:openai]
    assert_equal 768, defaults[:ollama]
  end

  def test_embedding_service_validates_dimensions
    service = HTM::EmbeddingService

    # Valid embedding should not raise
    valid_embedding = Array.new(768) { rand(-1.0..1.0) }
    service.validate_embedding!(valid_embedding)  # Should not raise
    pass  # Explicitly pass if we get here

    # Empty embedding should raise
    assert_raises(HTM::EmbeddingError) do
      service.validate_embedding!([])
    end

    # Non-array should raise
    assert_raises(HTM::EmbeddingError) do
      service.validate_embedding!("not an array")
    end
  end

  def test_embedding_service_pads_to_max_dimensions
    service = HTM::EmbeddingService

    # Small embedding should be padded
    small_embedding = Array.new(100) { rand(-1.0..1.0) }
    padded = service.pad_embedding(small_embedding)

    assert_equal HTM::EmbeddingService.max_dimension, padded.length
    assert_equal small_embedding, padded[0...100]
    assert_equal Array.new(1900, 0.0), padded[100..]
  end

  def test_tag_service_validates_format
    service = HTM::TagService

    # Valid tags
    assert service.valid_tag?("database:postgresql")
    assert service.valid_tag?("ai:llm:embeddings")
    assert service.valid_tag?("simple-tag")
    assert service.valid_tag?("with-hyphens:and-numbers1")

    # Invalid tags
    refute service.valid_tag?("UPPERCASE")
    refute service.valid_tag?("spaces not allowed")
    refute service.valid_tag?("")
    refute service.valid_tag?(nil)
  end

  def test_tag_service_filters_invalid_tags
    service = HTM::TagService

    # Mixed tags with some invalid
    mixed_tags = ["valid:tag", "INVALID", "also:valid", "too:many:levels:here:a:b"]
    filtered = service.validate_and_filter_tags(mixed_tags)

    assert_includes filtered, "valid:tag"
    assert_includes filtered, "also:valid"
    refute_includes filtered, "INVALID"
    refute_includes filtered, "too:many:levels:here:a:b"  # Too deep
  end

  def test_tag_service_max_depth
    service = HTM::TagService

    # Valid depth (4 colons = 5 levels is the limit)
    assert service.valid_tag?("a:b:c:d")  # 3 colons = depth 4, ok

    # Too deep (5+ colons)
    refute service.valid_tag?("a:b:c:d:e:f")  # 5 colons = depth 6, too deep
  end

  def test_tag_service_parses_hierarchy
    service = HTM::TagService

    hierarchy = service.parse_hierarchy("ai:llm:embedding")

    assert_equal "ai:llm:embedding", hierarchy[:full]
    assert_equal "ai", hierarchy[:root]
    assert_equal "ai:llm", hierarchy[:parent]
    assert_equal ["ai", "llm", "embedding"], hierarchy[:levels]
    assert_equal 3, hierarchy[:depth]
  end
end
