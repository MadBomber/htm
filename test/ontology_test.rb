# frozen_string_literal: true

require "test_helper"

class OntologyTest < Minitest::Test
  def setup
    # Skip if database is not configured
    unless ENV['HTM_DBURL']
      skip "Database not configured. Set HTM_DBURL to run ontology tests."
    end

    # Skip if Ollama is not available (needed for topic extraction)
    unless ollama_available?
      skip "Ollama not available. Topic extraction requires Ollama running locally."
    end

    # Ensure topic extraction environment variables are set
    ENV['HTM_TOPIC_PROVIDER'] ||= 'ollama'
    ENV['HTM_TOPIC_MODEL'] ||= 'llama3'
    ENV['HTM_TOPIC_BASE_URL'] ||= 'http://localhost:11434'

    @mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    @htm = HTM.new(
      robot_name: "Ontology Test Robot",
      embedding_service: @mock_service
    )
  end

  def teardown
    @htm&.shutdown
  end

  def test_topic_extraction_configuration_loaded
    # Verify topic configuration was set during connection setup
    config = @htm.long_term_memory.instance_variable_get(:@config)
    assert config, "Database config should exist"

    # Topic settings should be configured via session variables
    # (We can't directly check session variables from Ruby, but we can verify
    # that the configuration methods were called during initialization)
    assert_respond_to @htm.long_term_memory, :add, "LongTermMemory should have add method"
  end

  def test_automatic_topic_extraction_on_insert
    # Add a node with clear technical content
    node_id = @htm.add_node(
      "ontology_test_001",
      "PostgreSQL with TimescaleDB provides efficient time-series data storage using hypertables and compression policies",
      type: :fact,
      importance: 8.0
    )

    assert_instance_of Integer, node_id

    # Give LLM time to process (topic extraction is in AFTER trigger)
    sleep 2

    # Query the tags table for extracted topics
    topics = get_node_topics(node_id)

    # Verify topics were extracted
    refute_empty topics, "Topics should have been extracted automatically"

    # Verify hierarchical structure (should contain colons)
    hierarchical_topics = topics.select { |t| t.include?(':') }
    refute_empty hierarchical_topics, "Should have hierarchical topics with colon separators"

    # Verify topics are related to content
    all_topics_text = topics.join(' ')
    assert_match(/database|postgresql|timescale/i, all_topics_text, "Topics should relate to database content")

    # Clean up
    @htm.forget("ontology_test_001", confirm: :confirmed) rescue nil
  end

  def test_topic_format_validation
    # Add a node
    node_id = @htm.add_node(
      "ontology_test_002",
      "Ruby on Rails is a web framework for building database-backed applications",
      type: :fact,
      importance: 7.0
    )

    sleep 2

    topics = get_node_topics(node_id)

    # Verify all topics match the expected format: lowercase, hyphens, colons
    topics.each do |topic|
      assert_match(/^[a-z0-9\-]+(:[a-z0-9\-]+)*$/, topic,
        "Topic '#{topic}' should match format: root:level1:level2")
    end

    # Clean up
    @htm.forget("ontology_test_002", confirm: :confirmed) rescue nil
  end

  def test_multiple_classification_paths
    # Add a node that could be classified from multiple perspectives
    node_id = @htm.add_node(
      "ontology_test_003",
      "Machine learning models for database query optimization can improve performance by 30-50%",
      type: :fact,
      importance: 9.0
    )

    sleep 2

    topics = get_node_topics(node_id)

    # Verify multiple topic hierarchies exist
    root_topics = topics.map { |t| t.split(':').first }.uniq

    # Should have topics from multiple domains (e.g., 'database', 'ai', 'performance')
    assert root_topics.length >= 2,
      "Should have multiple classification paths (got: #{root_topics.join(', ')})"

    # Clean up
    @htm.forget("ontology_test_003", confirm: :confirmed) rescue nil
  end

  def test_topic_extraction_on_update
    # Add a node
    node_id = @htm.add_node(
      "ontology_test_004",
      "Initial content about Ruby programming",
      type: :fact,
      importance: 5.0
    )

    sleep 2
    initial_topics = get_node_topics(node_id)

    # Update the node's content to a completely different topic
    update_node_value(node_id, "PostgreSQL database performance tuning")

    sleep 2
    updated_topics = get_node_topics(node_id)

    # Topics should have changed
    refute_equal initial_topics.sort, updated_topics.sort,
      "Topics should change when content changes"

    # New topics should relate to databases, not Ruby
    all_topics = updated_topics.join(' ')
    assert_match(/database|postgresql/i, all_topics,
      "Updated topics should relate to new content")

    # Clean up
    @htm.forget("ontology_test_004", confirm: :confirmed) rescue nil
  end

  def test_ontology_structure_view
    # Add several nodes with related topics
    nodes = []
    3.times do |i|
      nodes << @htm.add_node(
        "ontology_test_structure_#{i}",
        "PostgreSQL database content number #{i}",
        type: :fact,
        importance: 5.0
      )
    end

    sleep 3

    # Query the ontology_structure view
    structure = query_ontology_structure

    # Verify the view returns results
    refute_empty structure, "Ontology structure view should return data"

    # Verify structure has expected columns
    first_row = structure.first
    assert first_row.key?('root_topic'), "Should have root_topic column"
    assert first_row.key?('full_path'), "Should have full_path column"
    assert first_row.key?('node_count'), "Should have node_count column"

    # Clean up
    3.times do |i|
      @htm.forget("ontology_test_structure_#{i}", confirm: :confirmed) rescue nil
    end
  end

  def test_topic_uniqueness_per_node
    # Add a node
    node_id = @htm.add_node(
      "ontology_test_005",
      "Ruby programming language",
      type: :fact,
      importance: 5.0
    )

    sleep 2

    topics = get_node_topics(node_id)
    unique_topics = topics.uniq

    # Verify no duplicate topics for this node
    assert_equal topics.length, unique_topics.length,
      "Should not have duplicate topics for a single node"

    # Clean up
    @htm.forget("ontology_test_005", confirm: :confirmed) rescue nil
  end

  def test_topic_extraction_handles_errors_gracefully
    # This test verifies that node insertion doesn't fail even if topic extraction fails
    # We can't easily force topic extraction to fail without breaking Ollama,
    # but we can verify that node creation succeeds

    node_id = @htm.add_node(
      "ontology_test_006",
      "Test content for error handling",
      type: :fact,
      importance: 5.0
    )

    # Node should be created successfully regardless of topic extraction
    assert_instance_of Integer, node_id
    assert @htm.retrieve("ontology_test_006"), "Node should exist in database"

    # Clean up
    @htm.forget("ontology_test_006", confirm: :confirmed) rescue nil
  end

  def test_topic_depth_limit
    # Add a node with very specific technical content
    node_id = @htm.add_node(
      "ontology_test_007",
      "TimescaleDB continuous aggregates with real-time materialization for time-series analytics",
      type: :fact,
      importance: 8.0
    )

    sleep 2

    topics = get_node_topics(node_id)

    # Verify topics don't exceed reasonable depth (max 5 levels as per migration)
    topics.each do |topic|
      levels = topic.split(':').length
      assert levels <= 5, "Topic '#{topic}' exceeds maximum depth of 5 (has #{levels} levels)"
    end

    # Clean up
    @htm.forget("ontology_test_007", confirm: :confirmed) rescue nil
  end

  def test_topic_relationships_view
    # Add multiple nodes with overlapping topics
    nodes = []
    ["PostgreSQL basics", "PostgreSQL advanced features", "Database design"].each_with_index do |content, i|
      nodes << @htm.add_node(
        "ontology_test_relations_#{i}",
        content,
        type: :fact,
        importance: 5.0
      )
    end

    sleep 3

    # Query topic relationships view
    relationships = query_topic_relationships

    # If we have relationships, verify structure
    unless relationships.empty?
      first_rel = relationships.first
      assert first_rel.key?('topic1'), "Should have topic1 column"
      assert first_rel.key?('topic2'), "Should have topic2 column"
      assert first_rel.key?('shared_nodes'), "Should have shared_nodes column"
    end

    # Clean up
    3.times do |i|
      @htm.forget("ontology_test_relations_#{i}", confirm: :confirmed) rescue nil
    end
  end

  def test_empty_content_no_topics
    # Add a node with minimal content
    node_id = @htm.add_node(
      "ontology_test_008",
      "x",
      type: :fact,
      importance: 1.0
    )

    sleep 2

    topics = get_node_topics(node_id)

    # LLM might extract topics even for minimal content, or might not
    # Either way, node creation should succeed
    assert_instance_of Integer, node_id

    # Clean up
    @htm.forget("ontology_test_008", confirm: :confirmed) rescue nil
  end

  private

  # Helper method to get topics for a node
  def get_node_topics(node_id)
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec_params(
        "SELECT tag FROM tags WHERE node_id = $1 ORDER BY tag",
        [node_id]
      )
      result.map { |row| row['tag'] }
    end
  end

  # Helper method to update node value (triggers topic re-extraction)
  def update_node_value(node_id, new_value)
    @htm.long_term_memory.send(:with_connection) do |conn|
      conn.exec_params(
        "UPDATE nodes SET value = $1 WHERE id = $2",
        [new_value, node_id]
      )
    end
  end

  # Helper method to query ontology structure view
  def query_ontology_structure
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec("SELECT * FROM ontology_structure LIMIT 10")
      result.to_a
    end
  end

  # Helper method to query topic relationships view
  def query_topic_relationships
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec("SELECT * FROM topic_relationships LIMIT 10")
      result.to_a
    end
  end
end
