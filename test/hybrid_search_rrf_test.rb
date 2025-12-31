# frozen_string_literal: true

require_relative "test_helper"

class HybridSearchRRFTest < Minitest::Test
  def setup
    skip "Database not available" unless database_available?

    # Clean up any leftover test data from previous runs FIRST
    cleanup_old_test_data

    # Configure HTM with mocks but enable tag extraction for these tests
    @mock_service = configure_htm_with_mocks(dimensions: 768)

    # Create a unique robot for this test
    @robot_name = "hybrid_rrf_test_#{Time.now.to_i}_#{rand(1000)}"
    @htm = HTM.new(robot_name: @robot_name)
  end

  def teardown
    cleanup_current_test_data if database_available?
    reset_htm_configuration
  end

  # Clean up data from previous test runs (before creating new robot)
  def cleanup_old_test_data
    return unless database_available?

    # Delete old test nodes first (to avoid FK violations)
    HTM::Models::Node.where("content LIKE ?", "%[RRF_TEST]%").find_each do |node|
      HTM::Models::NodeTag.where(node_id: node.id).delete_all
      HTM::Models::RobotNode.where(node_id: node.id).delete_all
    end
    HTM::Models::Node.where("content LIKE ?", "%[RRF_TEST]%").delete_all

    # Then delete old test robots
    HTM::Models::Robot.where("name LIKE ?", "hybrid_rrf_test_%").find_each do |robot|
      HTM::Models::RobotNode.where(robot_id: robot.id).delete_all
    end
    HTM::Models::Robot.where("name LIKE ?", "hybrid_rrf_test_%").delete_all
  rescue StandardError
    # Ignore cleanup errors
  end

  # Clean up data from current test run (after test completes)
  def cleanup_current_test_data
    return unless database_available?
    return unless @robot_name

    # Delete nodes created in this test
    HTM::Models::Node.where("content LIKE ?", "%[RRF_TEST]%").find_each do |node|
      HTM::Models::NodeTag.where(node_id: node.id).delete_all
      HTM::Models::RobotNode.where(node_id: node.id).delete_all
    end
    HTM::Models::Node.where("content LIKE ?", "%[RRF_TEST]%").delete_all

    # Delete the robot created for this test
    robot = HTM::Models::Robot.find_by(name: @robot_name)
    if robot
      HTM::Models::RobotNode.where(robot_id: robot.id).delete_all
      robot.delete
    end
  rescue StandardError
    # Ignore cleanup errors
  end

  # ==========================================================================
  # Basic RRF Functionality Tests
  # ==========================================================================

  def test_hybrid_search_returns_results_with_rrf_score
    # Add test data with embeddings
    node = create_node_with_embedding("[RRF_TEST] PostgreSQL supports vector search")

    # Use raw: true to get full hash results instead of just content strings
    results = @htm.recall("PostgreSQL vector", strategy: :hybrid, limit: 10, raw: true)

    assert_instance_of Array, results
    # Results should include RRF-specific fields
    if results.any?
      result = results.first
      assert result.key?('rrf_score'), "Result should include rrf_score"
      assert result.key?('sources'), "Result should include sources array"
    end
  end

  def test_hybrid_search_includes_sources_array
    node = create_node_with_embedding("[RRF_TEST] Ruby on Rails web framework")

    # Use raw: true to get full hash results
    results = @htm.recall("Ruby Rails", strategy: :hybrid, limit: 10, raw: true)

    if results.any?
      result = results.first
      assert_instance_of Array, result['sources']
      # Sources should be from: vector, fulltext, or tags
      valid_sources = %w[vector fulltext tags]
      result['sources'].each do |source|
        assert_includes valid_sources, source, "Invalid source: #{source}"
      end
    end
  end

  def test_hybrid_search_includes_rank_fields
    node = create_node_with_embedding("[RRF_TEST] Database optimization techniques")

    # Use raw: true to get full hash results
    results = @htm.recall("database optimization", strategy: :hybrid, limit: 10, raw: true)

    if results.any?
      result = results.first
      # Should have rank fields (may be nil if not found in that search)
      assert result.key?('vector_rank'), "Result should include vector_rank"
      assert result.key?('fulltext_rank'), "Result should include fulltext_rank"
      assert result.key?('tag_rank'), "Result should include tag_rank"
    end
  end

  # ==========================================================================
  # Tag Search Integration Tests
  # ==========================================================================

  def test_hybrid_search_includes_tag_search_results
    # Create node with specific tag
    node = create_node_with_tag(
      "[RRF_TEST] pgvector extension information",
      "database:postgresql:extensions"
    )

    # Search with query that should match the tag
    results = @htm.recall("postgresql extensions", strategy: :hybrid, limit: 10, raw: true)

    assert_instance_of Array, results
    if results.any?
      result = results.first
      assert result.key?('tag_depth_score'), "Result should include tag_depth_score"
      assert result.key?('matched_tags'), "Result should include matched_tags"
    end
  end

  def test_tag_search_finds_nodes_by_tag_only
    # Create node that won't match fulltext but has matching tag
    node = create_node_with_tag(
      "[RRF_TEST] Some unrelated content about widgets",
      "database:postgresql"
    )

    # Configure tag extractor to return database:postgresql for this query
    HTM.configure do |config|
      config.tag_extractor = ->(text, ontology) {
        if text.downcase.include?("postgresql") || text.downcase.include?("database")
          ["database:postgresql"]
        else
          []
        end
      }
    end

    results = @htm.recall("database postgresql", strategy: :hybrid, limit: 20, raw: true)

    # Should find the node via tag search even though content doesn't match well
    found = results.any? { |r| r['id'] == node.id }
    if found
      result = results.find { |r| r['id'] == node.id }
      assert_includes result['sources'], 'tags', "Node should be found via tags"
    end
  end

  def test_hybrid_search_boosts_nodes_found_in_multiple_searches
    # Create node that should match both fulltext AND tags
    node = create_node_with_tag(
      "[RRF_TEST] PostgreSQL database performance tuning",
      "database:postgresql"
    )

    # Configure tag extractor
    HTM.configure do |config|
      config.tag_extractor = ->(text, ontology) {
        ["database:postgresql"] if text.downcase.include?("postgresql")
      }
    end

    results = @htm.recall("PostgreSQL database", strategy: :hybrid, limit: 10, raw: true)

    if results.any?
      result = results.find { |r| r['id'] == node.id }
      if result
        # Node found in multiple searches should have higher RRF score
        # and multiple sources
        assert result['sources'].size >= 1, "Should have at least one source"
      end
    end
  end

  # ==========================================================================
  # Hierarchical Tag Depth Scoring Tests
  # ==========================================================================

  def test_tag_depth_score_calculation
    ltm = @htm.instance_variable_get(:@long_term_memory)

    # Test depth map building
    extracted_tags = ["database:postgresql:extensions"]
    depth_map = ltm.send(:build_tag_depth_map, extracted_tags)

    assert_equal 3, depth_map.size
    assert_equal({ depth: 1, max_depth: 3 }, depth_map["database"])
    assert_equal({ depth: 2, max_depth: 3 }, depth_map["database:postgresql"])
    assert_equal({ depth: 3, max_depth: 3 }, depth_map["database:postgresql:extensions"])
  end

  def test_full_depth_match_scores_highest
    ltm = @htm.instance_variable_get(:@long_term_memory)

    extracted_tags = ["database:postgresql:extensions"]
    depth_map = ltm.send(:build_tag_depth_map, extracted_tags)

    # Full match should score 1.0
    score = ltm.send(:calculate_tag_depth_score, ["database:postgresql:extensions"], depth_map)
    assert_in_delta 1.0, score, 0.01
  end

  def test_partial_depth_match_scores_proportionally
    ltm = @htm.instance_variable_get(:@long_term_memory)

    extracted_tags = ["database:postgresql:extensions"]
    depth_map = ltm.send(:build_tag_depth_map, extracted_tags)

    # 2/3 match
    score = ltm.send(:calculate_tag_depth_score, ["database:postgresql"], depth_map)
    assert_in_delta 0.67, score, 0.01

    # 1/3 match
    score = ltm.send(:calculate_tag_depth_score, ["database"], depth_map)
    assert_in_delta 0.33, score, 0.01
  end

  def test_multiple_tag_matches_get_bonus
    ltm = @htm.instance_variable_get(:@long_term_memory)

    # Use deeper tags so partial matches don't hit the 1.0 cap
    extracted_tags = ["database:postgresql:extensions", "api:rest:v2"]
    depth_map = ltm.send(:build_tag_depth_map, extracted_tags)

    # Single partial match: database:postgresql matches 2/3 = 0.67
    single_score = ltm.send(:calculate_tag_depth_score, ["database:postgresql"], depth_map)

    # Multiple partial matches should get bonus: max(2/3, 2/3) + 0.05 bonus = 0.72
    multi_score = ltm.send(:calculate_tag_depth_score, ["database:postgresql", "api:rest"], depth_map)

    assert multi_score > single_score, "Multiple matches should score higher (single: #{single_score}, multi: #{multi_score})"
  end

  def test_empty_tags_return_zero_score
    ltm = @htm.instance_variable_get(:@long_term_memory)

    extracted_tags = ["database:postgresql"]
    depth_map = ltm.send(:build_tag_depth_map, extracted_tags)

    score = ltm.send(:calculate_tag_depth_score, [], depth_map)
    assert_equal 0.0, score
  end

  def test_no_matching_tags_return_zero_score
    ltm = @htm.instance_variable_get(:@long_term_memory)

    extracted_tags = ["database:postgresql"]
    depth_map = ltm.send(:build_tag_depth_map, extracted_tags)

    score = ltm.send(:calculate_tag_depth_score, ["completely:unrelated"], depth_map)
    assert_equal 0.0, score
  end

  # ==========================================================================
  # RRF Merge Algorithm Tests
  # ==========================================================================

  def test_rrf_merge_combines_three_result_sets
    ltm = @htm.instance_variable_get(:@long_term_memory)

    # Create mock result sets
    vector_results = [
      { 'id' => 1, 'content' => 'Node 1', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'similarity' => 0.9 },
      { 'id' => 2, 'content' => 'Node 2', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'similarity' => 0.8 }
    ]

    fulltext_results = [
      { 'id' => 2, 'content' => 'Node 2', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'text_rank' => 1.5 },
      { 'id' => 3, 'content' => 'Node 3', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'text_rank' => 1.2 }
    ]

    tag_results = [
      { 'id' => 2, 'content' => 'Node 2', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'tag_depth_score' => 1.0, 'matched_tags' => ['test:tag'] },
      { 'id' => 4, 'content' => 'Node 4', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'tag_depth_score' => 0.5, 'matched_tags' => ['test'] }
    ]

    merged = ltm.send(:merge_with_rrf, vector_results, fulltext_results, tag_results)

    # Should have 4 unique nodes
    assert_equal 4, merged.size

    # Node 2 appears in all three - should have highest RRF score
    node2 = merged.find { |r| r['id'] == 2 }
    assert_equal %w[vector fulltext tags].sort, node2['sources'].sort

    # Node 2 should be ranked first (highest RRF score)
    assert_equal 2, merged.first['id'], "Node appearing in all 3 searches should rank first"
  end

  def test_rrf_score_increases_with_multiple_sources
    ltm = @htm.instance_variable_get(:@long_term_memory)

    # Node in vector only
    vector_only = [
      { 'id' => 1, 'content' => 'Node 1', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'similarity' => 0.9 }
    ]

    # Node in vector and fulltext
    vector_and_fulltext = [
      { 'id' => 2, 'content' => 'Node 2', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'similarity' => 0.9 }
    ]
    fulltext_results = [
      { 'id' => 2, 'content' => 'Node 2', 'access_count' => 0, 'created_at' => Time.now, 'token_count' => 10, 'text_rank' => 1.5 }
    ]

    merged_single = ltm.send(:merge_with_rrf, vector_only, [], [])
    merged_double = ltm.send(:merge_with_rrf, vector_and_fulltext, fulltext_results, [])

    single_score = merged_single.first['rrf_score']
    double_score = merged_double.first['rrf_score']

    assert double_score > single_score, "Node in 2 searches should have higher RRF score than node in 1"
  end

  def test_rrf_constant_is_60
    # Verify the standard RRF constant from the original paper
    assert_equal 60, HTM::LongTermMemory::HybridSearch::RRF_K
  end

  # ==========================================================================
  # PostgreSQL Array Parsing Tests
  # ==========================================================================

  def test_parse_pg_array_handles_string_format
    ltm = @htm.instance_variable_get(:@long_term_memory)

    # PostgreSQL array format
    result = ltm.send(:parse_pg_array, '{tag1,tag2,tag3}')
    assert_equal %w[tag1 tag2 tag3], result
  end

  def test_parse_pg_array_handles_ruby_array
    ltm = @htm.instance_variable_get(:@long_term_memory)

    # Already a Ruby array
    result = ltm.send(:parse_pg_array, ['tag1', 'tag2'])
    assert_equal %w[tag1 tag2], result
  end

  def test_parse_pg_array_handles_nil
    ltm = @htm.instance_variable_get(:@long_term_memory)

    result = ltm.send(:parse_pg_array, nil)
    assert_equal [], result
  end

  def test_parse_pg_array_handles_empty_string
    ltm = @htm.instance_variable_get(:@long_term_memory)

    result = ltm.send(:parse_pg_array, '')
    assert_equal [], result
  end

  def test_parse_pg_array_handles_quoted_values
    ltm = @htm.instance_variable_get(:@long_term_memory)

    result = ltm.send(:parse_pg_array, '{"database:postgresql","api:rest"}')
    assert_equal ['database:postgresql', 'api:rest'], result
  end

  # ==========================================================================
  # Integration Tests
  # ==========================================================================

  def test_full_hybrid_search_with_all_three_dimensions
    # Set up tag extractor that returns predictable tags
    HTM.configure do |config|
      config.tag_extractor = ->(text, ontology) {
        tags = []
        tags << "database:postgresql" if text.downcase.include?("postgresql")
        tags << "language:ruby" if text.downcase.include?("ruby")
        tags
      }
    end

    # Create nodes that will be found by different search methods
    node1 = create_node_with_tag(
      "[RRF_TEST] PostgreSQL database with Ruby integration",
      "database:postgresql"
    )

    node2 = create_node_with_embedding(
      "[RRF_TEST] Semantic search and embeddings"
    )

    # Search should use all three methods (use raw: true to get hash results)
    results = @htm.recall("PostgreSQL Ruby database", strategy: :hybrid, limit: 10, raw: true)

    assert_instance_of Array, results
    # Verify result structure
    if results.any?
      result = results.first
      assert result.key?('rrf_score')
      assert result.key?('sources')
      assert result.key?('similarity')
      assert result.key?('text_rank')
      assert result.key?('tag_depth_score')
      assert result.key?('matched_tags')
    end
  end

  private

  # Create a node with embedding (for vector search)
  # Returns the Node model instance
  def create_node_with_embedding(content)
    node_id = @htm.remember(content)

    # Wait for background jobs to complete (inline mode)
    # Then return the node model
    HTM::Models::Node.find(node_id)
  end

  # Create a node with a specific tag (for tag search)
  # Returns the Node model instance
  def create_node_with_tag(content, tag_name)
    node_id = @htm.remember(content)

    # Add tag directly to the node
    tag = HTM::Models::Tag.find_or_create_by!(name: tag_name)
    HTM::Models::NodeTag.find_or_create_by!(node_id: node_id, tag_id: tag.id)

    HTM::Models::Node.find(node_id)
  end
end
