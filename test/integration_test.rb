# frozen_string_literal: true

require "test_helper"

class IntegrationTest < Minitest::Test
  def setup
    # Skip entire test class if database not available
    skip_without_database
    return if skipped?

    # Initialize HTM with mock embedding service
    @htm = HTM.new(
      robot_name: "Test Robot",
      working_memory_size: 128_000
    )
  end

  def teardown
    return unless @htm

    begin
      # Clean up test data
      HTM::Models::Node.joins(:robots).where(robots: { name: @htm.robot_name }).destroy_all
    rescue => e
      # Ignore errors during cleanup
    end
  end

  def test_htm_initializes_with_ollama
    assert_instance_of HTM, @htm
    refute_nil @htm.robot_id
    assert_equal "Test Robot", @htm.robot_name
  end

  def test_working_memory_tracking
    # Add a node and check working memory
    @htm.remember("Working memory test with Ollama embeddings")

    # Check working memory stats
    assert @htm.working_memory.node_count > 0
    assert @htm.working_memory.token_count > 0
    assert @htm.working_memory.utilization_percentage >= 0
  end

  def test_remember_and_recall
    # Add a node
    node_id = @htm.remember("Test content for integration")
    assert_instance_of Integer, node_id

    # Recall should find it
    results = @htm.recall("integration", timeframe: "last week", strategy: :fulltext)
    assert_instance_of Array, results
  end

  def test_forget_with_confirmation
    # Add a node
    node_id = @htm.remember("Content to forget")

    # Should require confirmation
    error = assert_raises(ArgumentError) do
      @htm.forget(node_id)
    end
    assert_match(/confirm/, error.message.downcase)

    # Should work with confirmation
    result = @htm.forget(node_id, confirm: :confirmed)
    assert result
  end
end
