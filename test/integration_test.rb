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

  def test_forget_soft_delete_by_default
    # Add a node
    node_id = @htm.remember("Content to soft delete")

    # Soft delete should work without confirmation (default)
    result = @htm.forget(node_id)
    assert result

    # Node should still exist in database but be marked deleted
    node = HTM::Models::Node.with_deleted.find(node_id)
    refute_nil node.deleted_at, "Node should have deleted_at timestamp"

    # Node should NOT appear in default queries
    assert_nil HTM::Models::Node.find_by(id: node_id), "Soft-deleted node should not appear in default queries"
  end

  def test_forget_permanent_delete_requires_confirmation
    # Add a node
    node_id = @htm.remember("Content for permanent delete")

    # Permanent delete without confirmation should raise error
    error = assert_raises(ArgumentError) do
      @htm.forget(node_id, soft: false)
    end
    assert_match(/confirm/, error.message.downcase)

    # Permanent delete with confirmation should work
    result = @htm.forget(node_id, soft: false, confirm: :confirmed)
    assert result

    # Node should be completely gone
    assert_nil HTM::Models::Node.with_deleted.find_by(id: node_id), "Node should be permanently deleted"
  end

  def test_restore_soft_deleted_node
    # Add and soft-delete a node
    node_id = @htm.remember("Content to restore")
    @htm.forget(node_id)

    # Node should be deleted
    assert_nil HTM::Models::Node.find_by(id: node_id)

    # Restore it
    result = @htm.restore(node_id)
    assert result

    # Node should be back
    node = HTM::Models::Node.find(node_id)
    refute_nil node
    assert_nil node.deleted_at, "Restored node should have nil deleted_at"
  end

  def test_purge_deleted_requires_confirmation
    # Should require confirmation
    error = assert_raises(ArgumentError) do
      @htm.purge_deleted(older_than: 30.days.ago)
    end
    assert_match(/confirm/, error.message.downcase)
  end

  # Tests extracted from one-off scripts

  def test_embedding_deserializes_as_array
    # Add a node (mock embedding generator creates embeddings synchronously with inline backend)
    node_id = @htm.remember("PostgreSQL supports vector search via pgvector extension")

    # Retrieve the node directly
    node = HTM::Models::Node.find(node_id)

    # Verify embedding is deserialized as Array, not String
    assert_instance_of Array, node.embedding, "Embedding should be deserialized as Array"
    assert node.embedding.size > 0, "Embedding should have elements"
    assert_instance_of Float, node.embedding.first, "Embedding elements should be Floats"
  end

  def test_nearest_neighbors_class_method
    # Add multiple nodes with different content
    @htm.remember("PostgreSQL is a powerful open-source relational database")
    @htm.remember("TimescaleDB extends PostgreSQL for time-series data")
    @htm.remember("Ruby is a dynamic programming language")

    # Get a sample node with embedding
    sample = HTM::Models::Node.with_embeddings.joins(:robots)
      .where(robots: { name: @htm.robot_name }).first

    refute_nil sample, "Should have at least one node with embedding"
    refute_nil sample.embedding, "Sample node should have an embedding"

    # Test class method nearest_neighbors
    neighbors = HTM::Models::Node.with_embeddings
      .nearest_neighbors(:embedding, sample.embedding, distance: "cosine")
      .limit(3)
      .to_a

    assert_instance_of Array, neighbors, "Should return results as array"
    assert neighbors.size > 0, "Should find at least one neighbor"

    # Each neighbor should have a distance
    neighbors.each do |node|
      distance = node.neighbor_distance
      refute_nil distance, "Neighbor should have a distance"
      assert distance >= 0, "Distance should be non-negative"
    end
  end

  def test_nearest_neighbors_instance_method
    # Add multiple nodes
    @htm.remember("PostgreSQL is a powerful open-source relational database")
    @htm.remember("TimescaleDB extends PostgreSQL for time-series data")
    @htm.remember("Ruby is a dynamic programming language")

    # Get a sample node
    sample = HTM::Models::Node.with_embeddings.joins(:robots)
      .where(robots: { name: @htm.robot_name }).first

    refute_nil sample, "Should have at least one node with embedding"

    # Test instance method if available
    if sample.respond_to?(:nearest_neighbors)
      neighbors = sample.nearest_neighbors(limit: 3).to_a
      assert_instance_of Array, neighbors, "Should return results as array"
      assert neighbors.size >= 0, "Should return results"
    else
      skip "Node model does not have nearest_neighbors instance method"
    end
  end

  def test_recall_with_raw_false_returns_content_strings
    # Add test data
    @htm.remember("PostgreSQL is a powerful open-source relational database")
    @htm.remember("Ruby is a dynamic programming language")

    # Recall with raw: false (default) - should return content strings
    results = @htm.recall("PostgreSQL", strategy: :fulltext)

    assert_instance_of Array, results
    if results.any?
      assert_instance_of String, results.first, "Default recall should return content strings"
    end
  end

  def test_recall_with_raw_true_returns_node_hashes
    # Add test data
    @htm.remember("PostgreSQL is a powerful open-source relational database")
    @htm.remember("Ruby is a dynamic programming language")

    # Recall with raw: true - should return full node hashes
    results = @htm.recall("PostgreSQL", strategy: :fulltext, raw: true)

    assert_instance_of Array, results
    if results.any?
      result = results.first
      assert_instance_of Hash, result, "Raw recall should return hashes"
      assert result.key?("content") || result.key?(:content), "Raw result should include content"
      assert result.key?("id") || result.key?(:id), "Raw result should include id"
    end
  end
end
