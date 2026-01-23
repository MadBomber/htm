# frozen_string_literal: true

require "test_helper"

class OntologyTest < Minitest::Test
  def setup
    # Skip entire test class if database not available
    skip_without_database
    return if skipped?

    # Configure HTM with mocks to prevent real LLM calls
    # This ensures tests don't generate auto-tags from content
    configure_htm_with_mocks

    @htm = HTM.new(robot_name: "Ontology Test Robot")
  end

  def teardown
    return unless @htm

    # Clean up test data
    begin
      robot = HTM::Models::Robot.first(name: @htm.robot_name)
      if robot
        node_ids = HTM::Models::RobotNode.where(robot_id: robot.id).select_map(:node_id)
        HTM::Models::Node.where(id: node_ids).delete if node_ids.any?
      end
    rescue => e
      # Ignore errors during cleanup
    end

    # Reset configuration for other tests
    reset_htm_configuration
  end

  def test_manual_topic_assignment
    # Add a node with manual hierarchical tags
    node_id = @htm.remember(
      "PostgreSQL with TimescaleDB provides efficient time-series data storage using hypertables and compression policies",
      tags: ["database:postgresql:timescaledb", "storage:time-series", "performance:optimization"]
    )

    assert_instance_of Integer, node_id

    # Query the tags table for assigned topics
    topics = get_node_topics(node_id)

    # Verify topics were assigned
    refute_empty topics, "Topics should have been assigned manually"

    # Verify hierarchical structure (should contain colons)
    hierarchical_topics = topics.select { |t| t.include?(':') }
    refute_empty hierarchical_topics, "Should have hierarchical topics with colon separators"

    # Verify expected topics
    assert_includes topics, "database:postgresql:timescaledb"
    assert_includes topics, "storage:time-series"
    assert_includes topics, "performance:optimization"

    # Clean up
    delete_node(node_id)
  end

  def test_topic_format_validation
    # Add a node with properly formatted hierarchical tags
    node_id = @htm.remember(
      "Ruby on Rails is a web framework for building database-backed applications",
      tags: ["web:frameworks:rails", "programming:ruby", "database:orm"]
    )

    topics = get_node_topics(node_id)

    # Verify all topics match the expected format: lowercase, hyphens, colons
    topics.each do |topic|
      assert_match(/^[a-z0-9\-]+(:[a-z0-9\-]+)*$/, topic,
        "Topic '#{topic}' should match format: root:level1:level2")
    end

    # Clean up
    delete_node(node_id)
  end

  def test_multiple_classification_paths
    # Add a node with tags from multiple perspectives
    node_id = @htm.remember(
      "Machine learning models for database query optimization can improve performance by 30-50%",
      tags: ["ai:machine-learning:optimization", "database:performance:query-optimization", "performance:improvement"]
    )

    topics = get_node_topics(node_id)

    # Verify multiple topic hierarchies exist
    root_topics = topics.map { |t| t.split(':').first }.uniq

    # Should have topics from multiple domains
    assert root_topics.length >= 2,
      "Should have multiple classification paths (got: #{root_topics.join(', ')})"

    # Clean up
    delete_node(node_id)
  end

  def test_manual_tag_updates
    # Add a node with initial tags
    node_id = @htm.remember(
      "Initial content about Ruby programming",
      tags: ["programming:ruby", "language:interpreted"]
    )

    initial_topics = get_node_topics(node_id)
    assert_includes initial_topics, "programming:ruby"

    # Manually update tags by deleting old ones and adding new ones
    delete_node_tags(node_id)
    add_node_tags(node_id, ["database:postgresql:performance", "optimization:query"])

    updated_topics = get_node_topics(node_id)

    # Topics should have changed
    refute_equal initial_topics.sort, updated_topics.sort,
      "Topics should change when manually updated"

    # New topics should be present
    assert_includes updated_topics, "database:postgresql:performance"
    assert_includes updated_topics, "optimization:query"

    # Old topics should be gone
    refute_includes updated_topics, "programming:ruby"

    # Clean up
    delete_node(node_id)
  end

  def test_topic_uniqueness_per_node
    # Add a node with tags (database enforces uniqueness via UNIQUE constraint)
    node_id = @htm.remember(
      "Ruby programming language",
      tags: ["programming:ruby", "language:interpreted", "programming:ruby"]  # Duplicate intentionally
    )

    topics = get_node_topics(node_id)
    unique_topics = topics.uniq

    # Verify no duplicate topics for this node (database enforces this)
    assert_equal topics.length, unique_topics.length,
      "Should not have duplicate topics for a single node"

    # Clean up
    delete_node(node_id)
  end

  def test_node_creation_without_tags
    # Verify that node creation succeeds even without tags
    node_id = @htm.remember(
      "Test content without tags"
    )

    # Node should be created successfully
    assert_instance_of Integer, node_id

    topics = get_node_topics(node_id)
    assert_empty topics, "Should have no topics when none provided"

    # Clean up
    delete_node(node_id)
  end

  def test_topic_depth_limit
    # Add a node with deep hierarchy tags
    node_id = @htm.remember(
      "TimescaleDB continuous aggregates with real-time materialization for time-series analytics",
      tags: [
        "database:timescaledb:features:continuous-aggregates",
        "analytics:time-series:real-time"
      ]
    )

    topics = get_node_topics(node_id)

    # Verify topics don't exceed reasonable depth (max 5 levels)
    topics.each do |topic|
      levels = topic.split(':').length
      assert levels <= 5, "Topic '#{topic}' exceeds maximum depth of 5 (has #{levels} levels)"
    end

    # Clean up
    delete_node(node_id)
  end

  def test_empty_tag_array_no_topics
    # Add a node with empty tags array
    node_id = @htm.remember(
      "Content with empty tags array",
      tags: []
    )

    topics = get_node_topics(node_id)

    # Should have no topics
    assert_empty topics, "Should have no topics with empty tags array"

    # Clean up
    delete_node(node_id)
  end

  private

  # Helper method to get topics for a node
  def get_node_topics(node_id)
    HTM::Models::NodeTag
      .join(:tags, id: :tag_id)
      .where(node_id: node_id)
      .select_map(Sequel[:tags][:name])
      .sort
  end

  # Helper method to delete a node by ID
  def delete_node(node_id)
    HTM::Models::Node[node_id].destroy
  end

  # Helper method to delete all tags for a node
  def delete_node_tags(node_id)
    HTM::Models::NodeTag.where(node_id: node_id).delete
  end

  # Helper method to add tags to a node
  def add_node_tags(node_id, tags)
    tags.each do |tag_name|
      tag = HTM::Models::Tag.find_or_create(name: tag_name)
      HTM::Models::NodeTag.find_or_create(node_id: node_id, tag_id: tag.id)
    end
  end
end
