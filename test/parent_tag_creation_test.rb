# frozen_string_literal: true

require "test_helper"

class ParentTagCreationTest < Minitest::Test
  def setup
    skip_without_database

    # Reset circuit breaker
    HTM::TagService.reset_circuit_breaker!

    # Configure HTM with mocks
    configure_htm_with_mocks

    # Clean up old test tags first (before creating new HTM instance)
    cleanup_old_test_tags

    # Create HTM instance for tests
    @robot_name = "parent_tag_test_robot_#{Time.now.to_i}_#{rand(10000)}"
    @htm = HTM.new(robot_name: @robot_name)
  end

  def teardown
    cleanup_current_test_data if defined?(@htm) && @htm
    reset_htm_configuration
  end

  # ==========================================================================
  # Tag.expand_hierarchy tests
  # ==========================================================================

  def test_expand_hierarchy_single_level
    result = HTM::Models::Tag.expand_hierarchy("database")

    assert_equal ["database"], result
  end

  def test_expand_hierarchy_two_levels
    result = HTM::Models::Tag.expand_hierarchy("database:postgresql")

    assert_equal ["database", "database:postgresql"], result
  end

  def test_expand_hierarchy_three_levels
    result = HTM::Models::Tag.expand_hierarchy("database:postgresql:extensions")

    assert_equal [
      "database",
      "database:postgresql",
      "database:postgresql:extensions"
    ], result
  end

  def test_expand_hierarchy_four_levels
    result = HTM::Models::Tag.expand_hierarchy("database:postgresql:extensions:pgvector")

    assert_equal [
      "database",
      "database:postgresql",
      "database:postgresql:extensions",
      "database:postgresql:extensions:pgvector"
    ], result
  end

  def test_expand_hierarchy_empty_string
    result = HTM::Models::Tag.expand_hierarchy("")

    assert_equal [], result
  end

  def test_expand_hierarchy_nil
    result = HTM::Models::Tag.expand_hierarchy(nil)

    assert_equal [], result
  end

  # ==========================================================================
  # Tag.find_or_create_with_ancestors tests
  # ==========================================================================

  def test_find_or_create_with_ancestors_creates_all_levels
    # Ensure no tags exist
    tag_names = ["ai", "ai:llm", "ai:llm:embeddings"]
    tag_names.each { |name| HTM::Models::Tag.where(name: name).destroy_all }

    tags = HTM::Models::Tag.find_or_create_with_ancestors("ai:llm:embeddings")

    assert_equal 3, tags.length
    assert_equal ["ai", "ai:llm", "ai:llm:embeddings"], tags.map(&:name)

    # Verify they exist in database
    tag_names.each do |name|
      assert HTM::Models::Tag.exists?(name: name), "Tag '#{name}' should exist"
    end
  end

  def test_find_or_create_with_ancestors_reuses_existing_tags
    # Create parent tag first
    existing = HTM::Models::Tag.create!(name: "web")

    tags = HTM::Models::Tag.find_or_create_with_ancestors("web:frontend:react")

    assert_equal 3, tags.length
    assert_equal existing.id, tags.first.id  # Should reuse existing tag
    assert_equal ["web", "web:frontend", "web:frontend:react"], tags.map(&:name)
  end

  def test_find_or_create_with_ancestors_single_level
    tags = HTM::Models::Tag.find_or_create_with_ancestors("security")

    assert_equal 1, tags.length
    assert_equal ["security"], tags.map(&:name)
  end

  # ==========================================================================
  # Node#add_tags tests
  # ==========================================================================

  def test_node_add_tags_creates_parent_tags
    node = create_test_node("Test content for tagging")

    node.add_tags("devops:kubernetes:pods")

    tag_names = node.tags.pluck(:name).sort

    assert_includes tag_names, "devops"
    assert_includes tag_names, "devops:kubernetes"
    assert_includes tag_names, "devops:kubernetes:pods"
    assert_equal 3, tag_names.length
  end

  def test_node_add_tags_with_multiple_hierarchical_tags
    node = create_test_node("Test content with multiple tags")

    node.add_tags(["api:rest:json", "database:sql"])

    tag_names = node.tags.pluck(:name).sort

    # api:rest:json should create: api, api:rest, api:rest:json
    assert_includes tag_names, "api"
    assert_includes tag_names, "api:rest"
    assert_includes tag_names, "api:rest:json"

    # database:sql should create: database, database:sql
    assert_includes tag_names, "database"
    assert_includes tag_names, "database:sql"

    assert_equal 5, tag_names.length
  end

  def test_node_add_tags_doesnt_duplicate_shared_parents
    node = create_test_node("Test content with shared parents")

    node.add_tags(["database:postgresql", "database:mysql"])

    tag_names = node.tags.pluck(:name).sort

    # "database" should only appear once
    assert_equal 1, tag_names.count("database")
    assert_equal ["database", "database:mysql", "database:postgresql"], tag_names
  end

  def test_node_add_tags_single_level_tag
    node = create_test_node("Simple tag test")

    node.add_tags("testing")

    tag_names = node.tags.pluck(:name)

    assert_equal ["testing"], tag_names
  end

  # ==========================================================================
  # LongTermMemory#add_tag tests
  # ==========================================================================

  def test_ltm_add_tag_creates_parent_tags
    node = create_test_node("LTM tag test content")
    ltm = @htm.long_term_memory

    ltm.add_tag(node_id: node.id, tag: "cloud:aws:lambda")

    tag_names = HTM::Models::Tag
      .joins(:node_tags)
      .where(node_tags: { node_id: node.id })
      .pluck(:name)
      .sort

    assert_includes tag_names, "cloud"
    assert_includes tag_names, "cloud:aws"
    assert_includes tag_names, "cloud:aws:lambda"
    assert_equal 3, tag_names.length
  end

  def test_ltm_add_tag_handles_duplicates_gracefully
    node = create_test_node("Duplicate tag test")
    ltm = @htm.long_term_memory

    # Add same tag twice
    ltm.add_tag(node_id: node.id, tag: "testing:unit")
    ltm.add_tag(node_id: node.id, tag: "testing:unit")

    tag_names = HTM::Models::Tag
      .joins(:node_tags)
      .where(node_tags: { node_id: node.id })
      .pluck(:name)
      .sort

    # Should not have duplicates
    assert_equal ["testing", "testing:unit"], tag_names
  end

  # ==========================================================================
  # Integration tests - full remember flow
  # ==========================================================================

  def test_remember_with_manual_tags_creates_parents
    node_id = @htm.remember(
      "PostgreSQL is an excellent database",
      tags: ["database:postgresql:extensions"]
    )

    node = HTM::Models::Node.find(node_id)
    tag_names = node.tags.pluck(:name).sort

    # Should include all parent tags
    assert_includes tag_names, "database"
    assert_includes tag_names, "database:postgresql"
    assert_includes tag_names, "database:postgresql:extensions"
  end

  def test_nodes_by_topic_finds_nodes_via_parent_tag
    # Create a node with a deep tag
    node_id = @htm.remember(
      "pgvector enables vector similarity search in PostgreSQL",
      tags: ["database:postgresql:extensions:pgvector"]
    )

    ltm = @htm.long_term_memory

    # Search by parent tag "database" - should find the node
    results = ltm.nodes_by_topic("database", exact: true)

    node_ids = results.map { |r| r["id"] }
    assert_includes node_ids, node_id, "Node should be found via parent tag 'database'"

    # Search by intermediate parent "database:postgresql"
    results = ltm.nodes_by_topic("database:postgresql", exact: true)

    node_ids = results.map { |r| r["id"] }
    assert_includes node_ids, node_id, "Node should be found via parent tag 'database:postgresql'"
  end

  def test_popular_tags_includes_parent_tags
    # Create nodes with deep tags
    @htm.remember("Content about AI", tags: ["ai:machine-learning:deep-learning"])
    @htm.remember("More AI content", tags: ["ai:machine-learning:neural-networks"])
    @htm.remember("Even more AI", tags: ["ai:nlp:transformers"])

    ltm = @htm.long_term_memory
    popular = ltm.popular_tags(limit: 10)
    popular_names = popular.map { |t| t[:name] }

    # "ai" should be highly popular (appears in all three)
    assert_includes popular_names, "ai"

    # Find the "ai" tag's usage count
    ai_tag = popular.find { |t| t[:name] == "ai" }
    assert ai_tag, "ai tag should be in popular tags"
    assert_equal 3, ai_tag[:usage_count], "ai tag should have usage_count of 3"
  end

  private

  def create_test_node(content)
    # Make content unique by appending timestamp and random number
    unique_content = "#{content} [test:#{Time.now.to_f}:#{rand(100000)}]"
    token_count = HTM.count_tokens(unique_content)
    node = HTM::Models::Node.create!(
      content: unique_content,
      token_count: token_count,
      content_hash: Digest::SHA256.hexdigest(unique_content)
    )

    # Associate with robot
    HTM::Models::RobotNode.create!(
      robot_id: @htm.robot_id,
      node_id: node.id
    )

    node
  end

  # Clean up old test tags from previous test runs (safe to run before HTM instance exists)
  def cleanup_old_test_tags
    test_prefixes = %w[ai api cloud database devops security testing web]
    test_prefixes.each do |prefix|
      # Only delete orphaned tags (not associated with any nodes)
      HTM::Models::Tag.where("name LIKE ?", "#{prefix}%").orphaned.destroy_all
    end
  rescue ActiveRecord::ActiveRecordError
    # Ignore cleanup errors
  end

  # Clean up data from the current test
  def cleanup_current_test_data
    return unless @htm

    robot_id = @htm.robot_id

    # Get all node IDs for this robot
    node_ids = HTM::Models::RobotNode.where(robot_id: robot_id).pluck(:node_id)

    if node_ids.any?
      # Delete node_tags for these nodes
      HTM::Models::NodeTag.where(node_id: node_ids).delete_all

      # Delete robot_nodes
      HTM::Models::RobotNode.where(robot_id: robot_id).delete_all

      # Delete nodes
      HTM::Models::Node.where(id: node_ids).delete_all
    end

    # Clean up test tags we created
    test_prefixes = %w[ai api cloud database devops security testing web]
    test_prefixes.each do |prefix|
      # Use orphaned scope to only delete tags not used by other tests
      HTM::Models::Tag.where("name LIKE ?", "#{prefix}%").orphaned.destroy_all
    end

    # Delete the test robot
    HTM::Models::Robot.where(id: robot_id).delete_all
  rescue ActiveRecord::ActiveRecordError
    # Ignore cleanup errors
  end
end
