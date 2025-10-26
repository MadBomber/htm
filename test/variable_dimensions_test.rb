# frozen_string_literal: true

require "test_helper"

class VariableDimensionsTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['HTM_DBURL']
      skip "Database not configured. Set HTM_DBURL to run variable dimensions tests."
    end
  end

  def test_database_max_dimension_constant
    assert_equal 2000, HTM::LongTermMemory::MAX_VECTOR_DIMENSION
  end

  def test_store_768_dimension_embedding
    # Test storing a 768-dimension embedding (Ollama gpt-oss)
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss', dimensions: 768)
    htm = HTM.new(
      robot_name: "768D Test Robot",
      embedding_service: mock_service
    )

    node_id = htm.add_node(
      "test_768d_001",
      "Testing 768-dimensional embeddings",
      type: :fact,
      importance: 5.0
    )

    assert_instance_of Integer, node_id

    # Retrieve and verify
    node = htm.retrieve("test_768d_001")
    assert_equal "test_768d_001", node['key']
    assert_equal 768, node['embedding_dimension'].to_i

    # Cleanup
    htm.forget("test_768d_001", confirm: :confirmed)
    htm.shutdown
  end

  def test_store_1024_dimension_embedding
    # Test storing a 1024-dimension embedding (Cohere)
    mock_service = MockEmbeddingService.new(:cohere, model: 'embed-english-v3.0', dimensions: 1024)
    htm = HTM.new(
      robot_name: "1024D Test Robot",
      embedding_service: mock_service
    )

    node_id = htm.add_node(
      "test_1024d_001",
      "Testing 1024-dimensional embeddings",
      type: :fact,
      importance: 5.0
    )

    assert_instance_of Integer, node_id

    # Retrieve and verify
    node = htm.retrieve("test_1024d_001")
    assert_equal 1024, node['embedding_dimension'].to_i

    # Cleanup
    htm.forget("test_1024d_001", confirm: :confirmed)
    htm.shutdown
  end

  def test_store_1536_dimension_embedding
    # Test storing a 1536-dimension embedding (OpenAI text-embedding-3-small)
    mock_service = MockEmbeddingService.new(:openai, model: 'text-embedding-3-small', dimensions: 1536)
    htm = HTM.new(
      robot_name: "1536D Test Robot",
      embedding_service: mock_service
    )

    node_id = htm.add_node(
      "test_1536d_001",
      "Testing 1536-dimensional embeddings",
      type: :fact,
      importance: 5.0
    )

    assert_instance_of Integer, node_id

    # Retrieve and verify
    node = htm.retrieve("test_1536d_001")
    assert_equal 1536, node['embedding_dimension'].to_i

    # Cleanup
    htm.forget("test_1536d_001", confirm: :confirmed)
    htm.shutdown
  end

  def test_store_1920_dimension_embedding
    # Test storing a 1920-dimension embedding (near max limit)
    mock_service = MockEmbeddingService.new(:local, model: 'large-model', dimensions: 1920)
    htm = HTM.new(
      robot_name: "1920D Test Robot",
      embedding_service: mock_service
    )

    node_id = htm.add_node(
      "test_1920d_001",
      "Testing 1920-dimensional embeddings",
      type: :fact,
      importance: 5.0
    )

    assert_instance_of Integer, node_id

    # Retrieve and verify
    node = htm.retrieve("test_1920d_001")
    assert_equal 1920, node['embedding_dimension'].to_i

    # Cleanup
    htm.forget("test_1920d_001", confirm: :confirmed)
    htm.shutdown
  end

  def test_reject_oversized_embedding
    # Test that embeddings larger than MAX_VECTOR_DIMENSION are rejected
    mock_service = MockEmbeddingService.new(:local, model: 'huge-model', dimensions: 2100)
    htm = HTM.new(
      robot_name: "Oversized Test Robot",
      embedding_service: mock_service
    )

    # Should raise ValidationError for embedding larger than 2000
    assert_raises(HTM::ValidationError) do
      htm.add_node(
        "test_oversized_001",
        "This should fail",
        type: :fact,
        importance: 5.0
      )
    end

    htm.shutdown
  end

  def test_mixed_dimension_storage
    # Test that we can store nodes with different dimensions in the same database
    mock_768 = MockEmbeddingService.new(:ollama, model: 'gpt-oss', dimensions: 768)
    mock_1536 = MockEmbeddingService.new(:openai, model: 'text-embedding-3-small', dimensions: 1536)

    htm_768 = HTM.new(
      robot_name: "Mixed 768 Robot",
      embedding_service: mock_768
    )

    htm_1536 = HTM.new(
      robot_name: "Mixed 1536 Robot",
      embedding_service: mock_1536
    )

    # Add nodes with different dimensions
    htm_768.add_node("mixed_768", "768 dimensions", type: :fact, importance: 5.0)
    htm_1536.add_node("mixed_1536", "1536 dimensions", type: :fact, importance: 5.0)

    # Verify dimensions are stored correctly
    node_768 = htm_768.retrieve("mixed_768")
    node_1536 = htm_1536.retrieve("mixed_1536")

    assert_equal 768, node_768['embedding_dimension'].to_i
    assert_equal 1536, node_1536['embedding_dimension'].to_i

    # Cleanup
    htm_768.forget("mixed_768", confirm: :confirmed)
    htm_1536.forget("mixed_1536", confirm: :confirmed)
    htm_768.shutdown
    htm_1536.shutdown
  end

  def test_dimension_metadata_in_stats
    mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss', dimensions: 768)
    htm = HTM.new(
      robot_name: "Stats Test Robot",
      embedding_service: mock_service
    )

    # Add a node
    htm.add_node("stats_test_001", "Test for stats", type: :fact, importance: 5.0)

    # Get stats - verify database config is present
    stats = htm.memory_stats
    assert stats.key?(:database)

    # Cleanup
    htm.forget("stats_test_001", confirm: :confirmed)
    htm.shutdown
  end
end
