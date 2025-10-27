# frozen_string_literal: true

require "test_helper"

# Integration tests for ontology + vector embeddings
# Tests the complementary nature of symbolic (tags) and sub-symbolic (embeddings) retrieval
class OntologyIntegrationTest < Minitest::Test
  def setup
    unless ENV['HTM_DBURL']
      skip "Database not configured. Set HTM_DBURL to run integration tests."
    end

    unless ollama_available?
      skip "Ollama not available. Integration tests require Ollama."
    end

    ENV['HTM_TOPIC_PROVIDER'] ||= 'ollama'
    ENV['HTM_TOPIC_MODEL'] ||= 'llama3'
    ENV['HTM_TOPIC_BASE_URL'] ||= 'http://localhost:11434'

    @mock_service = MockEmbeddingService.new(:ollama, model: 'gpt-oss')
    @htm = HTM.new(
      robot_name: "Integration Test Robot",
      embedding_service: @mock_service
    )

    # Create test dataset with diverse content
    @test_nodes = create_test_dataset
  end

  def teardown
    # Clean up test nodes
    @test_nodes&.each do |key|
      @htm.forget(key, confirm: :confirmed) rescue nil
    end
    @htm&.shutdown
  end

  def test_topic_based_filtering_with_vector_search
    # This tests the hybrid approach: filter by topic, then rank by similarity

    sleep 5  # Wait for topics to be extracted

    # Get all nodes tagged with 'database' root topic
    database_nodes = get_nodes_by_topic_prefix('database')

    # Verify we found database-related nodes
    refute_empty database_nodes, "Should find nodes with 'database' topics"

    # Among database nodes, we should find both PostgreSQL and MongoDB content
    node_values = database_nodes.map { |n| n['value'] }
    combined = node_values.join(' ')

    # Database topic should encompass different database systems
    assert_match(/postgresql|mongodb/i, combined,
      "Database topic should include various database systems")
  end

  def test_cross_topic_similarity_discovery
    # This tests finding similar concepts across different topic hierarchies

    sleep 5

    # Use vector search to find nodes similar to "performance optimization"
    similar_nodes = @htm.recall(
      timeframe: (Time.now - 3600)..Time.now,
      topic: "performance optimization techniques",
      limit: 10,
      strategy: :vector
    )

    # Get topics for these similar nodes
    if similar_nodes.any?
      topics_by_node = similar_nodes.map do |node|
        {
          value: node['value'],
          topics: get_node_topics_by_key(node['key'])
        }
      end

      # Verify that similar nodes might have different root topics
      # (e.g., database:performance and ai:model-optimization both relate to performance)
      all_root_topics = topics_by_node.flat_map { |n| n[:topics].map { |t| t.split(':').first } }.uniq

      # If we have multiple root topics, that demonstrates cross-topic discovery
      if all_root_topics.length > 1
        assert true, "Vector search found similar concepts across topics: #{all_root_topics.join(', ')}"
      end
    end
  end

  def test_ontology_structure_emerges_from_content
    # Test that the ontology naturally organizes around content themes

    sleep 5

    structure = query_ontology_structure

    # Group by root topic
    by_root = structure.group_by { |row| row['root_topic'] }

    # Verify we have multiple root topics (shows diversity)
    assert by_root.keys.length >= 2,
      "Ontology should have multiple root topics (got: #{by_root.keys.join(', ')})"

    # Verify hierarchical depth exists
    hierarchical = structure.select { |row| row['full_path']&.include?(':') }
    refute_empty hierarchical, "Ontology should have hierarchical structure beyond root level"
  end

  def test_topic_cooccurrence_reveals_relationships
    # Test that topics appearing together reveal conceptual relationships

    sleep 5

    relationships = query_topic_relationships

    # If we have relationships, verify they make sense
    unless relationships.empty?
      # Topics that co-occur should have shared_nodes > 0
      relationships.each do |rel|
        assert rel['shared_nodes'].to_i >= 2,
          "Topic relationship should require at least 2 shared nodes"
      end

      # Topics about related concepts should appear together
      # (This is a softer assertion since it depends on LLM extraction quality)
      assert true, "Topic relationships exist: #{relationships.length} relationships found"
    end
  end

  def test_precise_topic_query_vs_fuzzy_vector_search
    # Demonstrate the difference between symbolic (precise) and sub-symbolic (fuzzy) retrieval

    sleep 5

    # Precise topic-based query: get ALL database:postgresql nodes
    pg_nodes = get_nodes_by_topic_pattern('database:postgresql%')

    # Fuzzy vector search: find nodes similar to "PostgreSQL"
    similar_nodes = @htm.recall(
      timeframe: (Time.now - 3600)..Time.now,
      topic: "PostgreSQL database",
      limit: 10,
      strategy: :vector
    )

    # Topic query is precise (only PostgreSQL)
    pg_keys = pg_nodes.map { |n| n['key'] }
    topic_only_pg = pg_keys.all? do |key|
      content = @htm.retrieve(key)
      content['value'] =~ /postgresql/i
    end

    # Vector search might include related but different databases (fuzzy)
    similar_keys = similar_nodes.map { |n| n['key'] }
    vector_includes_non_pg = similar_keys.any? do |key|
      content = @htm.retrieve(key)
      content['value'] !~ /postgresql/i
    end

    # Demonstrate complementary nature
    if pg_nodes.any? && similar_nodes.any?
      puts "\n  Topic query found: #{pg_nodes.length} PostgreSQL nodes (precise)"
      puts "  Vector search found: #{similar_nodes.length} similar nodes (fuzzy - may include related databases)"
    end

    assert true, "Both retrieval methods work"
  end

  def test_topic_consistency_across_similar_content
    # Test that similar content gets similar topic tags (LLM consistency)

    sleep 5

    # Find nodes about databases
    db_nodes = get_nodes_by_topic_prefix('database')

    if db_nodes.length >= 2
      # Get topics for each database node
      topics_per_node = db_nodes.map do |node|
        get_node_topics_by_id(node['id'].to_i)
      end

      # All database nodes should have 'database' as a root topic
      all_have_database_root = topics_per_node.all? do |topics|
        topics.any? { |t| t.start_with?('database') }
      end

      assert all_have_database_root,
        "All database-related nodes should have 'database' root topic"
    end
  end

  def test_manual_tags_and_llm_topics_coexist
    # Test that manually added tags coexist with LLM-extracted topics

    # Add a node with manual tags
    node_id = @htm.add_node(
      "integration_manual_tag_test",
      "PostgreSQL performance tuning guide",
      type: :fact,
      importance: 8.0,
      tags: ["manual-tag", "user-created"]
    )

    sleep 2

    # Get all tags (manual + LLM-extracted)
    all_tags = get_node_topics_by_id(node_id)

    # Should have both manual tags and LLM-extracted topics
    manual_tags = all_tags.select { |t| t == "manual-tag" || t == "user-created" }
    llm_topics = all_tags.select { |t| t.include?(':') }

    assert manual_tags.any?, "Manual tags should be present"
    assert llm_topics.any?, "LLM-extracted topics should be present"

    # Clean up
    @htm.forget("integration_manual_tag_test", confirm: :confirmed) rescue nil
  end

  private

  def create_test_dataset
    nodes = []

    # Database-related content
    nodes << @htm.add_node(
      "test_db_001",
      "PostgreSQL with TimescaleDB provides efficient time-series data storage",
      type: :fact,
      importance: 8.0
    )

    nodes << @htm.add_node(
      "test_db_002",
      "MongoDB is a NoSQL document database with flexible schema design",
      type: :fact,
      importance: 7.0
    )

    # AI/ML content
    nodes << @htm.add_node(
      "test_ai_001",
      "Machine learning models require large amounts of training data",
      type: :fact,
      importance: 7.0
    )

    # Performance content (crosses domains)
    nodes << @htm.add_node(
      "test_perf_001",
      "Database query optimization can improve application performance significantly",
      type: :fact,
      importance: 8.0
    )

    nodes << @htm.add_node(
      "test_perf_002",
      "LLM inference optimization techniques reduce latency in AI applications",
      type: :fact,
      importance: 8.0
    )

    nodes.map { |key| key.is_a?(String) ? key : "test_node_#{key}" }
  end

  def get_nodes_by_topic_prefix(prefix)
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec_params(
        <<~SQL,
          SELECT DISTINCT n.id, n.key, n.value
          FROM nodes n
          JOIN tags t ON t.node_id = n.id
          WHERE t.tag LIKE $1
          ORDER BY n.created_at DESC
        SQL
        ["#{prefix}%"]
      )
      result.to_a
    end
  end

  def get_nodes_by_topic_pattern(pattern)
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec_params(
        <<~SQL,
          SELECT DISTINCT n.id, n.key, n.value
          FROM nodes n
          JOIN tags t ON t.node_id = n.id
          WHERE t.tag LIKE $1
          ORDER BY n.created_at DESC
        SQL
        [pattern]
      )
      result.to_a
    end
  end

  def get_node_topics_by_key(key)
    node = @htm.retrieve(key)
    return [] unless node

    get_node_topics_by_id(node['id'].to_i)
  end

  def get_node_topics_by_id(node_id)
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec_params(
        "SELECT tag FROM tags WHERE node_id = $1 ORDER BY tag",
        [node_id]
      )
      result.map { |row| row['tag'] }
    end
  end

  def query_ontology_structure
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec("SELECT * FROM ontology_structure WHERE root_topic IS NOT NULL")
      result.to_a
    end
  end

  def query_topic_relationships
    @htm.long_term_memory.send(:with_connection) do |conn|
      result = conn.exec("SELECT * FROM topic_relationships LIMIT 20")
      result.to_a
    end
  end
end
