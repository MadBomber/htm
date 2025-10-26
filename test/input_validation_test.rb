# frozen_string_literal: true

require "test_helper"

class InputValidationTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['TIGER_DBURL']
      skip "Database not configured. Set TIGER_DBURL to run input validation tests."
    end

    # Use mock embedding service for tests
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss', dimensions: 768)

    @htm = HTM.new(
      robot_name: "Validation Test Robot",
      embedding_service: mock_service
    )
  end

  def teardown
    return unless @htm
    @htm.shutdown
  end

  # Test validation constants
  def test_validation_constants_exist
    assert_equal 255, HTM::MAX_KEY_LENGTH
    assert_equal 1_000_000, HTM::MAX_VALUE_LENGTH
    assert_equal 1000, HTM::MAX_ARRAY_SIZE
    assert_equal 6, HTM::VALID_TYPES.size
    assert_equal 0.0..10.0, HTM::IMPORTANCE_RANGE
  end

  # Key validation tests
  def test_add_node_rejects_nil_key
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node(nil, "value")
    end
    assert_match(/Key cannot be nil/, error.message)
  end

  def test_add_node_rejects_empty_key
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("", "value")
    end
    assert_match(/Key cannot be empty/, error.message)
  end

  def test_add_node_rejects_long_key
    long_key = "x" * 300
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node(long_key, "value")
    end
    assert_match(/Key too long/, error.message)
  end

  def test_add_node_rejects_non_string_key
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node(123, "value")
    end
    assert_match(/Key must be a String/, error.message)
  end

  def test_add_node_rejects_key_with_invalid_characters
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key/with/slashes", "value")
    end
    assert_match(/Key contains invalid characters/, error.message)
  end

  # Value validation tests
  def test_add_node_rejects_nil_value
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", nil)
    end
    assert_match(/Value cannot be nil/, error.message)
  end

  def test_add_node_rejects_empty_value
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "")
    end
    assert_match(/Value cannot be empty/, error.message)
  end

  def test_add_node_rejects_huge_value
    huge_value = "x" * 2_000_000
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", huge_value)
    end
    assert_match(/Value too long/, error.message)
  end

  def test_add_node_rejects_non_string_value
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", 12345)
    end
    assert_match(/Value must be a String/, error.message)
  end

  # Type validation tests
  def test_add_node_rejects_invalid_type
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", type: :invalid_type)
    end
    assert_match(/Invalid type/, error.message)
  end

  def test_add_node_accepts_valid_types
    HTM::VALID_TYPES.each do |type|
      key = "test_#{type}_#{rand(10000)}"
      assert @htm.add_node(key, "value", type: type)
      @htm.forget(key, confirm: :confirmed)
    end
  end

  def test_add_node_rejects_non_symbol_type
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", type: "fact")
    end
    assert_match(/Type must be a Symbol/, error.message)
  end

  # Category validation tests
  def test_add_node_rejects_non_string_category
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", category: 123)
    end
    assert_match(/Category must be a String/, error.message)
  end

  def test_add_node_rejects_long_category
    long_category = "x" * 150
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", category: long_category)
    end
    assert_match(/Category too long/, error.message)
  end

  # Importance validation tests
  def test_add_node_rejects_negative_importance
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", importance: -1.0)
    end
    assert_match(/Importance must be between/, error.message)
  end

  def test_add_node_rejects_too_high_importance
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", importance: 11.0)
    end
    assert_match(/Importance must be between/, error.message)
  end

  def test_add_node_rejects_non_numeric_importance
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", importance: "high")
    end
    assert_match(/Importance must be a Numeric/, error.message)
  end

  def test_add_node_accepts_valid_importance_range
    [0.0, 5.0, 10.0].each do |importance|
      key = "test_importance_#{importance}_#{rand(10000)}"
      assert @htm.add_node(key, "value", importance: importance)
      @htm.forget(key, confirm: :confirmed)
    end
  end

  # Array validation tests
  def test_add_node_rejects_non_array_related_to
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", related_to: "not_an_array")
    end
    assert_match(/related_to must be an Array/, error.message)
  end

  def test_add_node_rejects_huge_related_to_array
    huge_array = Array.new(2000, "key")
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", related_to: huge_array)
    end
    assert_match(/related_to too large/, error.message)
  end

  def test_add_node_rejects_non_array_tags
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", tags: "not_an_array")
    end
    assert_match(/tags must be an Array/, error.message)
  end

  def test_add_node_rejects_huge_tags_array
    huge_array = Array.new(2000, "tag")
    error = assert_raises(HTM::ValidationError) do
      @htm.add_node("key", "value", tags: huge_array)
    end
    assert_match(/tags too large/, error.message)
  end

  # Recall method validation tests
  def test_recall_rejects_invalid_timeframe
    error = assert_raises(HTM::ValidationError) do
      @htm.recall(timeframe: 123, topic: "test")
    end
    assert_match(/Timeframe must be a Range or String/, error.message)
  end

  def test_recall_rejects_empty_topic
    error = assert_raises(HTM::ValidationError) do
      @htm.recall(timeframe: "last week", topic: "")
    end
    assert_match(/Value cannot be empty/, error.message)
  end

  def test_recall_rejects_invalid_limit
    error = assert_raises(HTM::ValidationError) do
      @htm.recall(timeframe: "last week", topic: "test", limit: -5)
    end
    assert_match(/limit must be a positive Integer/, error.message)
  end

  def test_recall_rejects_non_integer_limit
    error = assert_raises(HTM::ValidationError) do
      @htm.recall(timeframe: "last week", topic: "test", limit: "ten")
    end
    assert_match(/limit must be a positive Integer/, error.message)
  end

  def test_recall_rejects_invalid_strategy
    error = assert_raises(HTM::ValidationError) do
      @htm.recall(timeframe: "last week", topic: "test", strategy: :invalid)
    end
    assert_match(/Invalid strategy/, error.message)
  end

  def test_recall_accepts_valid_strategies
    # Clean up any existing test node first
    @htm.forget("recall_test", confirm: :confirmed) rescue nil

    # Add a test node
    @htm.add_node("recall_test", "test content", type: :fact)

    HTM::VALID_RECALL_STRATEGIES.each do |strategy|
      result = @htm.recall(timeframe: "last week", topic: "test", strategy: strategy)
      assert_instance_of Array, result
    end

    @htm.forget("recall_test", confirm: :confirmed)
  end

  # Create context validation tests
  def test_create_context_rejects_invalid_strategy
    error = assert_raises(HTM::ValidationError) do
      @htm.create_context(strategy: :invalid)
    end
    assert_match(/Invalid strategy/, error.message)
  end

  def test_create_context_rejects_non_integer_max_tokens
    error = assert_raises(HTM::ValidationError) do
      @htm.create_context(max_tokens: "thousand")
    end
    assert_match(/max_tokens must be a positive Integer/, error.message)
  end

  def test_create_context_rejects_negative_max_tokens
    error = assert_raises(HTM::ValidationError) do
      @htm.create_context(max_tokens: -100)
    end
    assert_match(/max_tokens must be a positive Integer/, error.message)
  end

  def test_create_context_accepts_valid_strategies
    HTM::VALID_CONTEXT_STRATEGIES.each do |strategy|
      context = @htm.create_context(strategy: strategy)
      assert_instance_of String, context
    end
  end

  # Forget method validation tests
  def test_forget_rejects_nil_key
    error = assert_raises(HTM::ValidationError) do
      @htm.forget(nil, confirm: :confirmed)
    end
    assert_match(/Key cannot be nil/, error.message)
  end

  def test_forget_rejects_empty_key
    error = assert_raises(HTM::ValidationError) do
      @htm.forget("", confirm: :confirmed)
    end
    assert_match(/Key cannot be empty/, error.message)
  end

  # Retrieve method validation tests
  def test_retrieve_rejects_nil_key
    error = assert_raises(HTM::ValidationError) do
      @htm.retrieve(nil)
    end
    assert_match(/Key cannot be nil/, error.message)
  end

  def test_retrieve_rejects_empty_key
    error = assert_raises(HTM::ValidationError) do
      @htm.retrieve("")
    end
    assert_match(/Key cannot be empty/, error.message)
  end

  def test_retrieve_rejects_long_key
    long_key = "x" * 300
    error = assert_raises(HTM::ValidationError) do
      @htm.retrieve(long_key)
    end
    assert_match(/Key too long/, error.message)
  end

  # Integration test: valid node creation
  def test_valid_node_creation_passes_all_validation
    node_id = @htm.add_node(
      "valid_test_#{rand(10000)}",
      "This is a valid test node",
      type: :fact,
      category: "testing",
      importance: 5.0,
      tags: ["test", "validation"],
      related_to: []
    )

    assert_instance_of Integer, node_id
  end
end
