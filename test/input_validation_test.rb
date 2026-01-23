# frozen_string_literal: true

require "test_helper"

class InputValidationTest < Minitest::Test
  def setup
    # Skip entire test class if database not available
    skip_without_database
    return if skipped?

    # Use mock embedding service for tests
    @htm = HTM.new(robot_name: "Validation Test Robot")
  end

  def teardown
    return unless @htm

    # Clean up test data - delete all nodes created by this test robot
    begin
      robot = HTM::Models::Robot.first(name: @htm.robot_name)
      if robot
        node_ids = HTM::Models::RobotNode.where(robot_id: robot.id).select_map(:node_id)
        HTM::Models::Node.where(id: node_ids).delete if node_ids.any?
      end
    rescue => e
      # Ignore errors during cleanup
    end
  end

  # Recall method validation tests
  def test_recall_rejects_invalid_timeframe
    error = assert_raises(HTM::ValidationError) do
      @htm.recall("test", timeframe: 123)
    end
    assert_match(/Invalid timeframe type/, error.message)
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
    # Add a test node
    @htm.remember("test content")

    HTM::VALID_RECALL_STRATEGIES.each do |strategy|
      result = @htm.recall("test", timeframe: "last week", strategy: strategy)
      assert_instance_of Array, result
    end
  end
end
