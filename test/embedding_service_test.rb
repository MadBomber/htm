# frozen_string_literal: true

require "test_helper"

class EmbeddingServiceTest < Minitest::Test
  def setup
    # Reset circuit breaker before each test
    HTM::EmbeddingService.reset_circuit_breaker!

    # Store original generator
    @original_generator = HTM.configuration.embedding_generator
  end

  def teardown
    # Restore original generator
    HTM.configuration.embedding_generator = @original_generator
    HTM::EmbeddingService.reset_circuit_breaker!
  end

  # Basic generation tests

  def test_generate_returns_valid_embedding_hash
    result = HTM::EmbeddingService.generate("test content")

    assert_kind_of Hash, result
    assert result.key?(:embedding)
    assert result.key?(:dimension)
    assert result.key?(:storage_embedding)
    assert result.key?(:storage_dimension)
  end

  def test_generate_returns_correct_dimensions
    HTM.configuration.embedding_generator = ->(text) {
      # Return 512-dimension embedding
      512.times.map { |i| Random.new(text.hash + i).rand(-1.0..1.0) }
    }

    result = HTM::EmbeddingService.generate("test content")

    assert_equal 512, result[:dimension]
    assert_equal HTM::EmbeddingService.max_dimension, result[:storage_dimension]
  end

  def test_generate_pads_embedding_to_max_dimension
    HTM.configuration.embedding_generator = ->(text) {
      [0.1, 0.2, 0.3]  # Only 3 dimensions
    }

    result = HTM::EmbeddingService.generate("test content")

    # Original dimension should be 3
    assert_equal 3, result[:dimension]
    # Storage should be padded to MAX_DIMENSION
    assert_equal HTM::EmbeddingService.max_dimension, result[:storage_dimension]
    # Storage format should contain all 2000 values
    assert_match(/^\[.*\]$/, result[:storage_embedding])
  end

  def test_generate_truncates_oversized_embeddings
    oversized = Array.new(3000) { |i| i * 0.001 }

    HTM.configuration.embedding_generator = ->(_text) { oversized }

    result = HTM::EmbeddingService.generate("test content")

    # Should truncate to MAX_DIMENSION
    assert_equal HTM::EmbeddingService.max_dimension, result[:dimension]
    assert_equal HTM::EmbeddingService.max_dimension, result[:storage_dimension]
  end

  # Validation tests

  def test_validate_embedding_rejects_non_array
    error = assert_raises(HTM::EmbeddingError) do
      HTM::EmbeddingService.validate_embedding!("not an array")
    end
    assert_match(/must be an Array/, error.message)
  end

  def test_validate_embedding_rejects_empty_array
    error = assert_raises(HTM::EmbeddingError) do
      HTM::EmbeddingService.validate_embedding!([])
    end
    assert_match(/empty/, error.message)
  end

  def test_validate_embedding_rejects_non_numeric_values
    error = assert_raises(HTM::EmbeddingError) do
      HTM::EmbeddingService.validate_embedding!([1.0, "string", 3.0])
    end
    assert_match(/numeric values/, error.message)
  end

  def test_validate_embedding_rejects_nan_values
    error = assert_raises(HTM::EmbeddingError) do
      HTM::EmbeddingService.validate_embedding!([1.0, Float::NAN, 3.0])
    end
    assert_match(/NaN or Infinity/, error.message)
  end

  def test_validate_embedding_rejects_infinity_values
    error = assert_raises(HTM::EmbeddingError) do
      HTM::EmbeddingService.validate_embedding!([1.0, Float::INFINITY, 3.0])
    end
    assert_match(/NaN or Infinity/, error.message)
  end

  def test_validate_embedding_accepts_valid_embedding
    valid_embedding = [0.1, 0.2, 0.3, -0.4, 0.5]
    # Should not raise
    HTM::EmbeddingService.validate_embedding!(valid_embedding)
  end

  def test_validate_embedding_accepts_integers
    valid_embedding = [1, 2, 3, -4, 5]
    # Should not raise - integers are Numeric
    HTM::EmbeddingService.validate_embedding!(valid_embedding)
  end

  # Storage formatting tests

  def test_format_for_storage_produces_valid_format
    embedding = [0.1, -0.2, 0.3]
    result = HTM::EmbeddingService.format_for_storage(embedding)

    assert_equal "[0.1,-0.2,0.3]", result
  end

  def test_pad_embedding_pads_short_embeddings
    short = [1.0, 2.0, 3.0]
    padded = HTM::EmbeddingService.pad_embedding(short)

    assert_equal HTM::EmbeddingService.max_dimension, padded.length
    assert_equal 1.0, padded[0]
    assert_equal 2.0, padded[1]
    assert_equal 3.0, padded[2]
    assert_equal 0.0, padded[3]
    assert_equal 0.0, padded[-1]
  end

  def test_pad_embedding_returns_original_if_already_max
    full = Array.new(HTM::EmbeddingService.max_dimension) { |i| i * 0.001 }
    padded = HTM::EmbeddingService.pad_embedding(full)

    assert_equal full, padded
  end

  # Circuit breaker tests

  def test_circuit_breaker_exists
    breaker = HTM::EmbeddingService.circuit_breaker

    assert_kind_of HTM::CircuitBreaker, breaker
    assert_equal 'embedding_service', breaker.name
  end

  def test_circuit_breaker_opens_after_failures
    failure_count = 0

    HTM.configuration.embedding_generator = ->(_text) {
      failure_count += 1
      raise StandardError, "API unavailable"
    }

    # Trigger failures up to threshold
    5.times do
      assert_raises(StandardError) do
        HTM::EmbeddingService.generate("test")
      end
    end

    # Next call should fail fast with CircuitBreakerOpenError
    assert_raises(HTM::CircuitBreakerOpenError) do
      HTM::EmbeddingService.generate("test")
    end
  end

  def test_circuit_breaker_can_be_reset
    HTM.configuration.embedding_generator = ->(_text) {
      raise StandardError, "API unavailable"
    }

    # Open the circuit
    5.times do
      assert_raises(StandardError) do
        HTM::EmbeddingService.generate("test")
      end
    end

    # Reset circuit breaker
    HTM::EmbeddingService.reset_circuit_breaker!

    # Should allow calls again (will fail but not with circuit breaker error)
    assert_raises(StandardError) do
      HTM::EmbeddingService.generate("test")
    end
  end

  # Error handling tests

  def test_generate_raises_embedding_error_on_failure
    HTM.configuration.embedding_generator = ->(_text) {
      raise RuntimeError, "Connection timeout"
    }

    # Error is wrapped in EmbeddingError
    error = assert_raises(HTM::EmbeddingError) do
      HTM::EmbeddingService.generate("test")
    end
    assert_match(/Connection timeout/, error.message)
  end

  def test_generate_raises_embedding_error_for_invalid_response
    HTM.configuration.embedding_generator = ->(_text) { "invalid" }

    error = assert_raises(HTM::EmbeddingError) do
      HTM::EmbeddingService.generate("test")
    end
    assert_match(/must be an Array/, error.message)
  end
end
