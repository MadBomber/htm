# frozen_string_literal: true

require "test_helper"

class DatabaseFeaturesTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['HTM_DBURL']
      skip "Database not configured. Set HTM_DBURL to run database feature tests."
    end
  end

  def test_connection_pooling_configuration
    # Create HTM with custom pool size
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    htm = HTM.new(
      robot_name: "Pool Test Robot",
      embedding_service: mock_service,
      db_pool_size: 3
    )

    # Verify pool size is set correctly
    assert_equal 3, htm.long_term_memory.pool_size

    # Clean up
    htm.shutdown
  end

  def test_query_timeout_configuration
    # Create HTM with custom timeout
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    htm = HTM.new(
      robot_name: "Timeout Test Robot",
      embedding_service: mock_service,
      db_query_timeout: 5000  # 5 seconds
    )

    # Verify timeout is set correctly
    assert_equal 5000, htm.long_term_memory.query_timeout

    # Clean up
    htm.shutdown
  end

  def test_memory_stats_includes_database_config
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    htm = HTM.new(
      robot_name: "Stats Test Robot",
      embedding_service: mock_service,
      db_pool_size: 10,
      db_query_timeout: 15000
    )

    stats = htm.memory_stats

    # Verify database stats are included
    assert stats.key?(:database)
    assert_equal 10, stats[:database][:pool_size]
    assert_equal 15000, stats[:database][:query_timeout_ms]

    # Clean up
    htm.shutdown
  end

  def test_shutdown_releases_connections
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    htm = HTM.new(
      robot_name: "Shutdown Test Robot",
      embedding_service: mock_service
    )

    # Add a test node to ensure pool is initialized
    htm.add_node(
      "shutdown_test_001",
      "Testing shutdown functionality",
      type: :fact,
      importance: 5.0
    )

    # Shutdown should complete without error
    assert_nil htm.shutdown

    # Clean up the test node (create new instance since we shut down)
    cleanup_htm = HTM.new(
      robot_name: "Cleanup Robot",
      embedding_service: mock_service
    )
    cleanup_htm.forget("shutdown_test_001", confirm: :confirmed) rescue nil
    cleanup_htm.shutdown
  end

  def test_concurrent_connections_use_pool
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    htm = HTM.new(
      robot_name: "Concurrent Test Robot",
      embedding_service: mock_service,
      db_pool_size: 2
    )

    # Create multiple nodes concurrently (simulated)
    # This tests that the pool can handle multiple operations
    nodes = []
    5.times do |i|
      nodes << htm.add_node(
        "concurrent_test_#{i}",
        "Concurrent test node #{i}",
        type: :fact,
        importance: 5.0
      )
    end

    # Verify all nodes were created
    assert_equal 5, nodes.length
    nodes.each { |node_id| assert_instance_of Integer, node_id }

    # Clean up
    5.times do |i|
      htm.forget("concurrent_test_#{i}", confirm: :confirmed) rescue nil
    end
    htm.shutdown
  end

  def test_default_pool_and_timeout_values
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    htm = HTM.new(
      robot_name: "Default Values Test Robot",
      embedding_service: mock_service
    )

    # Verify defaults match LongTermMemory constants
    assert_equal HTM::LongTermMemory::DEFAULT_POOL_SIZE, htm.long_term_memory.pool_size
    assert_equal HTM::LongTermMemory::DEFAULT_QUERY_TIMEOUT, htm.long_term_memory.query_timeout

    # Clean up
    htm.shutdown
  end
end
