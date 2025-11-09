# frozen_string_literal: true

require "test_helper"

class InputValidationTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['HTM_DBURL']
      skip "Database not configured. Set HTM_DBURL to run input validation tests."
    end

    # Use mock embedding service for tests
        @htm = HTM.new(
      robot_name: "Validation Test Robot")
  end

    def teardown
    return unless @htm

    # Clean up test data - delete all nodes created by this test robot
    begin
      HTM::Models::Node.joins(:robot).where(robots: { name: @htm.robot_name }).destroy_all
    rescue => e
      # Ignore errors during cleanup
      puts "Cleanup warning: #{e.message}"
    end
  end


  # Category validation tests


  # Importance validation tests




  # Array validation tests




  # Recall method validation tests
  def test_recall_rejects_invalid_timeframe
    error = assert_raises(HTM::ValidationError) do
      @htm.recall("test", timeframe: 123)
    end
    assert_match(/Timeframe must be a Range or String/, error.message)
  end


  def test_recall_rejects_invalid_limit
    error = assert_raises(HTM::ValidationError) do
      @htm.recall("test", timeframe: "last week", limit: -5)
    end
    assert_match(/limit must be a positive Integer/, error.message)
  end

  def test_recall_rejects_non_integer_limit
    error = assert_raises(HTM::ValidationError) do
      @htm.recall("test", timeframe: "last week", limit: "ten")
    end
    assert_match(/limit must be a positive Integer/, error.message)
  end

  def test_recall_rejects_invalid_strategy
    error = assert_raises(HTM::ValidationError) do
      @htm.recall("test", timeframe: "last week", strategy: :invalid)
    end
    assert_match(/Invalid strategy/, error.message)
  end

  def test_recall_accepts_valid_strategies
    # Clean up any existing test node first
    # Cleanup handled in teardown rescue nil

    # Add a test node
    @htm.remember("test content", source: "test")

    HTM::VALID_RECALL_STRATEGIES.each do |strategy|
      result = @htm.recall("test", timeframe: "last week", strategy: strategy)
      assert_instance_of Array, result
    end

    # Cleanup handled in teardown
  end

  # Create context validation tests




  # Forget method validation tests


  # Retrieve method validation tests



  # Integration test: valid node creation
end
