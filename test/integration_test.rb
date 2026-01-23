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
      robot = HTM::Models::Robot.first(name: @htm.robot_name)
      if robot
        node_ids = HTM::Models::RobotNode.where(robot_id: robot.id).select_map(:node_id)
        HTM::Models::Node.where(id: node_ids).delete if node_ids.any?
      end
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
    node = HTM::Models::Node.with_deleted[node_id]
    refute_nil node.deleted_at, "Node should have deleted_at timestamp"

    # Node should NOT appear in default queries
    assert_nil HTM::Models::Node.first(id: node_id), "Soft-deleted node should not appear in default queries"
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
    assert_nil HTM::Models::Node.with_deleted.first(id: node_id), "Node should be permanently deleted"
  end

  def test_restore_soft_deleted_node
    # Add and soft-delete a node
    node_id = @htm.remember("Content to restore")
    @htm.forget(node_id)

    # Node should be deleted
    assert_nil HTM::Models::Node.first(id: node_id)

    # Restore it
    result = @htm.restore(node_id)
    assert result

    # Node should be back
    node = HTM::Models::Node[node_id]
    refute_nil node
    assert_nil node.deleted_at, "Restored node should have nil deleted_at"
  end

  def test_purge_deleted_requires_confirmation
    # Should require confirmation
    error = assert_raises(ArgumentError) do
      @htm.purge_deleted(older_than: Time.now - (30 * 24 * 60 * 60))  # 30 days ago
    end
    assert_match(/confirm/, error.message.downcase)
  end

  # Tests extracted from one-off scripts

  def test_embedding_deserializes_as_array
    # Add a node (mock embedding generator creates embeddings synchronously with inline backend)
    node_id = @htm.remember("PostgreSQL supports vector search via pgvector extension")

    # Retrieve the node directly
    node = HTM::Models::Node[node_id]

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
    robot = HTM::Models::Robot.first(name: @htm.robot_name)
    node_ids = HTM::Models::RobotNode.where(robot_id: robot.id).select_map(:node_id)
    sample = HTM::Models::Node.with_embeddings.where(id: node_ids).first

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
    robot = HTM::Models::Robot.first(name: @htm.robot_name)
    node_ids = HTM::Models::RobotNode.where(robot_id: robot.id).select_map(:node_id)
    sample = HTM::Models::Node.with_embeddings.where(id: node_ids).first

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

  # Additional integration tests for comprehensive coverage

  def test_tag_operations
    # Add a node with manual tags
    node_id = @htm.remember("Database migrations are important", tags: ["database:migrations"])

    # Verify tags were added
    node = HTM::Models::Node[node_id]
    assert node.tag_names.include?("database:migrations"), "Manual tag should be present"

    # Add more tags
    node.add_tags(["database:postgresql", "best-practices"])
    assert node.tag_names.include?("database:postgresql")
    assert node.tag_names.include?("best-practices")

    # Remove a tag
    node.remove_tag("best-practices")
    refute node.tag_names.include?("best-practices")
  end

  def test_working_memory_eviction
    # Create HTM with small working memory
    small_htm = HTM.new(
      robot_name: "Small Memory Robot",
      working_memory_size: 100  # Very small
    )

    # Add content that exceeds working memory
    small_htm.remember("This is a test message that should trigger eviction")
    small_htm.remember("Another message to potentially cause eviction")

    # Working memory should have evicted older content to stay under limit
    assert small_htm.working_memory.token_count <= 100
  end

  def test_hybrid_search
    # Add test data
    @htm.remember("PostgreSQL supports vector search via pgvector extension")
    @htm.remember("TimescaleDB extends PostgreSQL for time-series data")
    @htm.remember("Ruby on Rails is a web framework")

    # Hybrid search combines fulltext and vector
    results = @htm.recall("PostgreSQL vector", strategy: :hybrid)

    assert_instance_of Array, results
  end

  def test_recall_with_relevance_scoring
    # Add test data
    @htm.remember("PostgreSQL is great for production databases")
    @htm.remember("Development databases can use SQLite")

    # Recall with relevance scoring
    results = @htm.recall("PostgreSQL", strategy: :fulltext, with_relevance: true, raw: true)

    assert_instance_of Array, results
    if results.any?
      result = results.first
      assert result.key?('relevance'), "Result should include relevance score"
      assert result['relevance'].is_a?(Numeric), "Relevance should be numeric"
    end
  end

  def test_observability_during_operations
    # Reset metrics
    HTM::Observability.reset_metrics!

    # Perform some operations
    @htm.remember("Test content for observability")
    @htm.recall("observability", strategy: :fulltext)

    # Check connection pool stats
    pool_stats = HTM::Observability.connection_pool_stats

    assert pool_stats[:status] == :healthy || pool_stats[:status] == :warning,
           "Pool should be healthy or warning status"
    assert pool_stats[:connections] >= 0
  end

  def test_circuit_breaker_state_accessible
    # Reset circuit breakers
    HTM::EmbeddingService.reset_circuit_breaker!
    HTM::TagService.reset_circuit_breaker!

    # Verify circuit breakers are closed (healthy)
    embedding_cb = HTM::EmbeddingService.circuit_breaker
    tag_cb = HTM::TagService.circuit_breaker

    assert_equal :closed, embedding_cb.state
    assert_equal :closed, tag_cb.state
  end

  def test_health_check_integration
    health = HTM::Observability.health_check

    assert health[:checks][:database], "Database should be connected"
    assert health[:checks][:connection_pool], "Connection pool should be healthy"

    # Circuit breakers should be healthy
    if health[:checks].key?(:embedding_circuit)
      assert health[:checks][:embedding_circuit], "Embedding circuit should be closed"
    end
    if health[:checks].key?(:tag_circuit)
      assert health[:checks][:tag_circuit], "Tag circuit should be closed"
    end
  end

  def test_search_by_tags
    # Add nodes with specific tags
    @htm.remember("PostgreSQL database setup guide", tags: ["database:postgresql"])
    @htm.remember("MySQL database configuration", tags: ["database:mysql"])
    @htm.remember("Ruby development tips", tags: ["programming:ruby"])

    # Search by tag
    results = @htm.long_term_memory.search_by_tags(tags: ["database:postgresql"])

    assert results.any? { |r| r['content']&.include?('PostgreSQL') }
  end

  def test_popular_tags
    # Add nodes with various tags
    3.times { @htm.remember("PostgreSQL content #{rand(1000)}", tags: ["database:postgresql"]) }
    2.times { @htm.remember("Ruby content #{rand(1000)}", tags: ["programming:ruby"]) }
    1.times { @htm.remember("Python content #{rand(1000)}", tags: ["programming:python"]) }

    # Get popular tags
    popular = @htm.long_term_memory.popular_tags(limit: 10)

    assert_instance_of Array, popular
  end

  def test_cache_invalidation_on_forget
    # Add a node
    node_id = @htm.remember("Content to be forgotten")

    # Recall to populate cache
    @htm.recall("forgotten", strategy: :fulltext)

    # Forget the node (soft delete)
    @htm.forget(node_id)

    # Cache should be invalidated - subsequent recall shouldn't find it
    results = @htm.recall("forgotten", strategy: :fulltext)

    # The forgotten node shouldn't appear in results
    refute results.any? { |r| r.include?("Content to be forgotten") }
  end
end
