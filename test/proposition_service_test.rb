# frozen_string_literal: true

require "test_helper"

class PropositionServiceTest < Minitest::Test
  def setup
    # Reset circuit breaker before each test
    HTM::PropositionService.reset_circuit_breaker!

    # Store original extractor
    @original_extractor = HTM.configuration.proposition_extractor

    # Configure HTM with mock proposition extractor for tests
    HTM.configure do |config|
      config.job.backend = :inline
      config.proposition_extractor = ->(text) {
        # Simple mock that returns propositions based on content
        if text.to_s.downcase.include?("neil armstrong")
          [
            "Neil Armstrong was an astronaut.",
            "Neil Armstrong walked on the Moon in 1969.",
            "Neil Armstrong was the first person to walk on the Moon."
          ]
        elsif text.to_s.downcase.include?("postgresql")
          [
            "PostgreSQL is a database.",
            "PostgreSQL supports vector search."
          ]
        else
          []
        end
      }
    end
  end

  def teardown
    HTM.configuration.proposition_extractor = @original_extractor
    HTM::PropositionService.reset_circuit_breaker!
    reset_htm_configuration
  end

  # Tests for extract
  def test_extract_returns_array
    propositions = HTM::PropositionService.extract("Neil Armstrong walked on the Moon.")

    assert_kind_of Array, propositions
  end

  def test_extract_with_matching_content
    propositions = HTM::PropositionService.extract("Neil Armstrong became the first person to walk on the Moon.")

    assert_includes propositions, "Neil Armstrong was an astronaut."
    assert_includes propositions, "Neil Armstrong walked on the Moon in 1969."
    assert_includes propositions, "Neil Armstrong was the first person to walk on the Moon."
  end

  def test_extract_with_no_propositions
    # Configure to return empty array
    HTM.configure do |config|
      config.job.backend = :inline
      config.proposition_extractor = ->(text) { [] }
    end

    propositions = HTM::PropositionService.extract("Some random text")

    assert_kind_of Array, propositions
    assert_empty propositions
  end

  # Tests for parse_propositions
  def test_parse_propositions_from_array
    result = HTM::PropositionService.parse_propositions([
      "Neil Armstrong was an astronaut.",
      "The Moon is Earth's only natural satellite."
    ])

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Moon is Earth's only natural satellite."
    ], result
  end

  def test_parse_propositions_from_string
    result = HTM::PropositionService.parse_propositions(
      "Neil Armstrong was an astronaut.\nThe Moon is Earth's satellite."
    )

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Moon is Earth's satellite."
    ], result
  end

  def test_parse_propositions_removes_bullet_points
    result = HTM::PropositionService.parse_propositions(
      "- Neil Armstrong was an astronaut.\n- The Moon is far away."
    )

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Moon is far away."
    ], result
  end

  def test_parse_propositions_removes_numbered_lists
    result = HTM::PropositionService.parse_propositions(
      "1. Neil Armstrong was an astronaut.\n2. The Moon is far away."
    )

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Moon is far away."
    ], result
  end

  def test_parse_propositions_strips_whitespace
    result = HTM::PropositionService.parse_propositions([
      "  Neil Armstrong was an astronaut.  ",
      "  The Moon is Earth's satellite.  "
    ])

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Moon is Earth's satellite."
    ], result
  end

  def test_parse_propositions_rejects_empty_strings
    result = HTM::PropositionService.parse_propositions([
      "Neil Armstrong was an astronaut.",
      "",
      "The Moon is far away."
    ])

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Moon is far away."
    ], result
  end

  def test_parse_propositions_raises_on_invalid_type
    assert_raises(HTM::PropositionError) do
      HTM::PropositionService.parse_propositions(12345)
    end
  end

  # Tests for validate_and_filter_propositions
  def test_validate_and_filter_propositions_accepts_valid
    result = HTM::PropositionService.validate_and_filter_propositions([
      "Neil Armstrong was an astronaut.",
      "The Apollo 11 mission occurred in 1969."
    ])

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Apollo 11 mission occurred in 1969."
    ], result
  end

  def test_validate_and_filter_propositions_rejects_too_short
    result = HTM::PropositionService.validate_and_filter_propositions([
      "Hi",  # Too short (< 10 chars)
      "Neil Armstrong was an astronaut."
    ])

    assert_equal ["Neil Armstrong was an astronaut."], result
  end

  def test_validate_and_filter_propositions_rejects_no_content
    result = HTM::PropositionService.validate_and_filter_propositions([
      "123 456 789",  # No alphabetic content
      "Neil Armstrong was an astronaut."
    ])

    assert_equal ["Neil Armstrong was an astronaut."], result
  end

  def test_validate_and_filter_propositions_removes_duplicates
    result = HTM::PropositionService.validate_and_filter_propositions([
      "Neil Armstrong was an astronaut.",
      "Neil Armstrong was an astronaut.",
      "The Moon is far away."
    ])

    assert_equal [
      "Neil Armstrong was an astronaut.",
      "The Moon is far away."
    ], result
  end

  # Tests for valid_proposition?
  def test_valid_proposition_accepts_normal_text
    assert HTM::PropositionService.valid_proposition?("Neil Armstrong was an astronaut.")
    assert HTM::PropositionService.valid_proposition?("PostgreSQL supports vector search via pgvector.")
  end

  def test_valid_proposition_rejects_nil
    refute HTM::PropositionService.valid_proposition?(nil)
  end

  def test_valid_proposition_rejects_empty
    refute HTM::PropositionService.valid_proposition?("")
  end

  def test_valid_proposition_rejects_too_short
    refute HTM::PropositionService.valid_proposition?("Hi")
  end

  def test_valid_proposition_rejects_no_letters
    refute HTM::PropositionService.valid_proposition?("123 456 789 000")
  end

  # Test config-based length accessors
  def test_min_length_from_config
    assert_equal 10, HTM::PropositionService.min_length
  end

  def test_max_length_from_config
    assert_equal 1000, HTM::PropositionService.max_length
  end

  def test_min_words_from_config
    assert_equal 5, HTM::PropositionService.min_words
  end

  # Circuit breaker tests
  def test_circuit_breaker_exists
    breaker = HTM::PropositionService.circuit_breaker

    assert_kind_of HTM::CircuitBreaker, breaker
    assert_equal 'proposition_service', breaker.name
  end

  def test_circuit_breaker_opens_after_failures
    HTM.configure do |config|
      config.job.backend = :inline
      config.proposition_extractor = ->(_text) {
        raise StandardError, "API unavailable"
      }
    end

    # Trigger failures up to threshold (errors wrapped in PropositionError)
    5.times do
      assert_raises(HTM::PropositionError) do
        HTM::PropositionService.extract("test content")
      end
    end

    # Next call should fail fast with CircuitBreakerOpenError
    assert_raises(HTM::CircuitBreakerOpenError) do
      HTM::PropositionService.extract("test content")
    end
  end

  def test_circuit_breaker_can_be_reset
    HTM.configure do |config|
      config.job.backend = :inline
      config.proposition_extractor = ->(_text) {
        raise StandardError, "API unavailable"
      }
    end

    # Open the circuit (errors wrapped in PropositionError)
    5.times do
      assert_raises(HTM::PropositionError) do
        HTM::PropositionService.extract("test")
      end
    end

    # Reset circuit breaker
    HTM::PropositionService.reset_circuit_breaker!

    # Should allow calls again (will fail but not with circuit breaker error)
    assert_raises(HTM::PropositionError) do
      HTM::PropositionService.extract("test")
    end
  end

  def test_extract_raises_proposition_error_for_invalid_response_type
    HTM.configure do |config|
      config.job.backend = :inline
      config.proposition_extractor = ->(_text) { 12345 }
    end

    error = assert_raises(HTM::PropositionError) do
      HTM::PropositionService.extract("test content")
    end
    assert_match(/Array or String/, error.message)
  end
end
