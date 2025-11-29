# frozen_string_literal: true

require "test_helper"

class TagServiceTest < Minitest::Test
  def setup
    # Reset circuit breaker before each test
    HTM::TagService.reset_circuit_breaker!

    # Store original extractor
    @original_extractor = HTM.configuration.tag_extractor

    # Configure HTM with mock tag extractor for tests
    HTM.configure do |config|
      config.job_backend = :inline
      config.tag_extractor = ->(text, ontology) {
        # Simple mock that extracts "tags" based on keywords
        tags = []
        tags << "database:postgresql" if text.to_s.downcase.include?("postgresql")
        tags << "database:sql" if text.to_s.downcase.include?("sql")
        tags << "programming:ruby" if text.to_s.downcase.include?("ruby")
        tags << "ai:llm" if text.to_s.downcase.include?("llm")
        tags
      }
    end
  end

  def teardown
    HTM.configuration.tag_extractor = @original_extractor
    HTM::TagService.reset_circuit_breaker!
    reset_htm_configuration
  end

  # Tests for valid_tag?
  def test_valid_tag_format
    assert HTM::TagService.valid_tag?("database")
    assert HTM::TagService.valid_tag?("database:postgresql")
    assert HTM::TagService.valid_tag?("ai:llm:embeddings")
    assert HTM::TagService.valid_tag?("web-development:frontend:react")
  end

  def test_invalid_tag_format_uppercase
    refute HTM::TagService.valid_tag?("Database")
  end

  def test_invalid_tag_format_space
    refute HTM::TagService.valid_tag?("data base")
  end

  def test_invalid_tag_format_underscore
    refute HTM::TagService.valid_tag?("database_sql")
  end

  def test_invalid_tag_format_empty
    refute HTM::TagService.valid_tag?("")
  end

  def test_invalid_tag_format_nil
    refute HTM::TagService.valid_tag?(nil)
  end

  def test_tag_with_numbers
    assert HTM::TagService.valid_tag?("web3")
    assert HTM::TagService.valid_tag?("html5:canvas")
    assert HTM::TagService.valid_tag?("es2015:modules")
  end

  def test_tag_with_hyphens
    assert HTM::TagService.valid_tag?("machine-learning")
    assert HTM::TagService.valid_tag?("natural-language-processing:nlp")
  end

  def test_max_depth_validation
    # Max depth is 4 levels (3 colons)
    assert HTM::TagService.valid_tag?("a:b:c:d")  # 4 levels - valid (3 colons)
    refute HTM::TagService.valid_tag?("a:b:c:d:e")  # 5 levels - invalid (4 colons)
  end

  def test_self_containment_rejected
    # Root == Leaf is rejected
    refute HTM::TagService.valid_tag?("database:sql:database")
  end

  def test_duplicate_segments_rejected
    # Duplicate segments in path are rejected
    refute HTM::TagService.valid_tag?("a:b:a")
    refute HTM::TagService.valid_tag?("sql:query:sql")
  end

  # Tests for extract
  def test_extract_returns_array
    tags = HTM::TagService.extract("PostgreSQL is a great database")

    assert_kind_of Array, tags
  end

  def test_extract_with_matching_content
    tags = HTM::TagService.extract("I love using PostgreSQL and Ruby together")

    assert_includes tags, "database:postgresql"
    assert_includes tags, "programming:ruby"
  end

  def test_extract_with_empty_content
    # Configure to return empty array for empty content
    HTM.configure do |config|
      config.job_backend = :inline
      config.tag_extractor = ->(text, ontology) { [] }
    end

    tags = HTM::TagService.extract("")

    assert_kind_of Array, tags
    assert_empty tags
  end

  def test_extract_with_existing_ontology
    existing = ["database:postgresql", "database:mysql"]
    tags = HTM::TagService.extract("PostgreSQL query optimization", existing_ontology: existing)

    assert_kind_of Array, tags
  end

  # Tests for parse_tags
  def test_parse_tags_from_array
    result = HTM::TagService.parse_tags(["database", "programming:ruby"])

    assert_equal ["database", "programming:ruby"], result
  end

  def test_parse_tags_from_string
    result = HTM::TagService.parse_tags("database\nprogramming:ruby")

    assert_equal ["database", "programming:ruby"], result
  end

  def test_parse_tags_strips_whitespace
    result = HTM::TagService.parse_tags(["  database  ", "  ruby  "])

    assert_equal ["database", "ruby"], result
  end

  def test_parse_tags_rejects_empty_strings
    result = HTM::TagService.parse_tags(["database", "", "ruby"])

    assert_equal ["database", "ruby"], result
  end

  def test_parse_tags_raises_on_invalid_type
    assert_raises(HTM::TagError) do
      HTM::TagService.parse_tags(12345)
    end
  end

  # Tests for validate_and_filter_tags
  def test_validate_and_filter_tags_accepts_valid
    result = HTM::TagService.validate_and_filter_tags(["database", "ai:llm"])

    assert_equal ["database", "ai:llm"], result
  end

  def test_validate_and_filter_tags_rejects_invalid_format
    result = HTM::TagService.validate_and_filter_tags(["Database", "valid-tag"])

    assert_equal ["valid-tag"], result
  end

  def test_validate_and_filter_tags_rejects_too_deep
    result = HTM::TagService.validate_and_filter_tags(["a:b:c:d:e", "valid"])

    assert_equal ["valid"], result
  end

  def test_validate_and_filter_tags_removes_duplicates
    result = HTM::TagService.validate_and_filter_tags(["database", "database", "ruby"])

    assert_equal ["database", "ruby"], result
  end

  # Tests for parse_hierarchy
  def test_parse_hierarchy_single_level
    result = HTM::TagService.parse_hierarchy("database")

    assert_equal "database", result[:full]
    assert_equal "database", result[:root]
    assert_nil result[:parent]
    assert_equal ["database"], result[:levels]
    assert_equal 1, result[:depth]
  end

  def test_parse_hierarchy_two_levels
    result = HTM::TagService.parse_hierarchy("database:postgresql")

    assert_equal "database:postgresql", result[:full]
    assert_equal "database", result[:root]
    assert_equal "database", result[:parent]
    assert_equal ["database", "postgresql"], result[:levels]
    assert_equal 2, result[:depth]
  end

  def test_parse_hierarchy_three_levels
    result = HTM::TagService.parse_hierarchy("ai:llm:embeddings")

    assert_equal "ai:llm:embeddings", result[:full]
    assert_equal "ai", result[:root]
    assert_equal "ai:llm", result[:parent]
    assert_equal ["ai", "llm", "embeddings"], result[:levels]
    assert_equal 3, result[:depth]
  end

  # Test constants
  def test_max_depth_constant
    assert_equal 4, HTM::TagService::MAX_DEPTH
  end

  def test_tag_format_constant
    assert HTM::TagService::TAG_FORMAT.is_a?(Regexp)
    assert "valid-tag".match?(HTM::TagService::TAG_FORMAT)
    assert "a:b:c".match?(HTM::TagService::TAG_FORMAT)
    refute "Invalid".match?(HTM::TagService::TAG_FORMAT)
  end

  # Circuit breaker tests

  def test_circuit_breaker_exists
    breaker = HTM::TagService.circuit_breaker

    assert_kind_of HTM::CircuitBreaker, breaker
    assert_equal 'tag_service', breaker.name
  end

  def test_circuit_breaker_opens_after_failures
    HTM.configure do |config|
      config.job_backend = :inline
      config.tag_extractor = ->(_text, _ontology) {
        raise StandardError, "API unavailable"
      }
    end

    # Trigger failures up to threshold (errors wrapped in TagError)
    5.times do
      assert_raises(HTM::TagError) do
        HTM::TagService.extract("test content")
      end
    end

    # Next call should fail fast with CircuitBreakerOpenError
    assert_raises(HTM::CircuitBreakerOpenError) do
      HTM::TagService.extract("test content")
    end
  end

  def test_circuit_breaker_can_be_reset
    HTM.configure do |config|
      config.job_backend = :inline
      config.tag_extractor = ->(_text, _ontology) {
        raise StandardError, "API unavailable"
      }
    end

    # Open the circuit (errors wrapped in TagError)
    5.times do
      assert_raises(HTM::TagError) do
        HTM::TagService.extract("test")
      end
    end

    # Reset circuit breaker
    HTM::TagService.reset_circuit_breaker!

    # Should allow calls again (will fail but not with circuit breaker error)
    assert_raises(HTM::TagError) do
      HTM::TagService.extract("test")
    end
  end

  def test_extract_raises_tag_error_for_invalid_response_type
    HTM.configure do |config|
      config.job_backend = :inline
      config.tag_extractor = ->(_text, _ontology) { 12345 }
    end

    error = assert_raises(HTM::TagError) do
      HTM::TagService.extract("test content")
    end
    assert_match(/Array or String/, error.message)
  end
end
