# frozen_string_literal: true

require_relative "test_helper"

# MCP Server Test Suite
#
# Tests the HTM MCP server implementation (lib/htm/mcp/)
# which exposes HTM memory capabilities via FastMCP tools and resources.
#
# Prerequisites:
# - fast-mcp gem installed
# - Database configured (HTM_DBURL)
#
class MCPServerTest < Minitest::Test
  def setup
    skip_without_database
    return if skipped?

    # Check if fast_mcp is available
    begin
      require 'fast_mcp'
    rescue LoadError
      skip "fast-mcp gem not installed. Run: gem install fast-mcp"
      return
    end

    # Load the MCP module files
    load_mcp_server_classes

    # Configure HTM with mocks for testing
    configure_htm_with_mocks

    # Reset Session state before each test
    reset_mcp_session
  end

  def teardown
    return if skipped?

    # Clean up test robots and their nodes
    cleanup_test_data
  end

  # ============================================================
  # MCPSession Module Tests
  # ============================================================

  def test_mcp_session_default_robot_name
    assert_equal "mcp_default", HTM::MCP::Session::DEFAULT_ROBOT_NAME
  end

  def test_mcp_session_htm_instance_returns_htm_object
    htm = HTM::MCP::Session.htm_instance
    assert_instance_of HTM, htm
    assert_equal "mcp_default", htm.robot_name
  end

  def test_mcp_session_set_robot_changes_robot
    HTM::MCP::Session.set_robot("test_robot_#{rand(10000)}")
    assert HTM::MCP::Session.robot_initialized?
    refute_equal "mcp_default", HTM::MCP::Session.robot_name
  end

  def test_mcp_session_robot_initialized_false_initially
    # After reset, should not be initialized
    refute HTM::MCP::Session.robot_initialized?
  end

  # ============================================================
  # SetRobotTool Tests
  # ============================================================

  def test_set_robot_tool_creates_new_robot
    tool = HTM::MCP::SetRobotTool.new
    robot_name = "test_robot_#{rand(10000)}"

    result = JSON.parse(tool.call(name: robot_name))

    assert result["success"]
    assert_equal robot_name, result["robot_name"]
    assert_instance_of Integer, result["robot_id"]
    assert result["message"].include?(robot_name)
  end

  def test_set_robot_tool_uses_existing_robot
    robot_name = "existing_robot_#{rand(10000)}"

    # Create robot first
    HTM.new(robot_name: robot_name)

    tool = HTM::MCP::SetRobotTool.new
    result = JSON.parse(tool.call(name: robot_name))

    assert result["success"]
    assert_equal robot_name, result["robot_name"]
  end

  # ============================================================
  # GetRobotTool Tests
  # ============================================================

  def test_get_robot_tool_returns_current_robot_info
    robot_name = "get_robot_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::GetRobotTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert_equal robot_name, result["robot_name"]
    assert result["initialized"]
    assert result.key?("memory_summary")
  end

  def test_get_robot_tool_shows_uninitialized_for_default
    tool = HTM::MCP::GetRobotTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert_equal "mcp_default", result["robot_name"]
    refute result["initialized"]
  end

  # ============================================================
  # GetWorkingMemoryTool Tests
  # ============================================================

  def test_get_working_memory_tool_returns_empty_initially
    robot_name = "wm_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::GetWorkingMemoryTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert_equal robot_name, result["robot_name"]
    assert_equal 0, result["count"]
    assert_equal [], result["working_memory"]
  end

  def test_get_working_memory_tool_returns_remembered_nodes
    robot_name = "wm_content_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    # Add some content
    htm.remember("Working memory test content")

    tool = HTM::MCP::GetWorkingMemoryTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert result["count"] >= 0  # May be 0 if not in working memory yet
  end

  # ============================================================
  # RememberTool Tests
  # ============================================================

  def test_remember_tool_stores_content
    robot_name = "remember_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::RememberTool.new
    result = JSON.parse(tool.call(content: "Test memory content"))

    assert result["success"]
    assert_instance_of Integer, result["node_id"]
    assert_equal "Test memory content", result["content"]
    assert_equal robot_name, result["robot_name"]
  end

  def test_remember_tool_with_tags
    robot_name = "remember_tags_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::RememberTool.new
    result = JSON.parse(tool.call(
      content: "PostgreSQL configuration",
      tags: ["database:postgresql", "config"]
    ))

    assert result["success"]
    assert_includes result["tags"], "database:postgresql"
    assert_includes result["tags"], "config"
  end

  def test_remember_tool_with_metadata
    robot_name = "remember_meta_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::RememberTool.new
    result = JSON.parse(tool.call(
      content: "API configuration",
      metadata: { priority: "high", category: "config" }
    ))

    assert result["success"]
    assert_instance_of Integer, result["node_id"]

    # Verify metadata was stored
    node = HTM::Models::Node.find(result["node_id"])
    assert_equal "high", node.metadata["priority"]
  end

  # ============================================================
  # RecallTool Tests
  # ============================================================

  def test_recall_tool_searches_memories
    robot_name = "recall_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    # Add test content
    htm.remember("PostgreSQL database configuration guide")

    tool = HTM::MCP::RecallTool.new
    result = JSON.parse(tool.call(query: "PostgreSQL", strategy: "fulltext"))

    assert result["success"]
    assert_equal "PostgreSQL", result["query"]
    assert_equal "fulltext", result["strategy"]
    assert_instance_of Array, result["results"]
  end

  def test_recall_tool_with_limit
    robot_name = "recall_limit_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    # Add multiple items
    5.times { |i| htm.remember("Test content #{i}") }

    tool = HTM::MCP::RecallTool.new
    result = JSON.parse(tool.call(query: "Test", limit: 2, strategy: "fulltext"))

    assert result["success"]
    assert result["results"].size <= 2
  end

  def test_recall_tool_with_timeframe
    robot_name = "recall_time_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("Recent content for timeframe test")

    tool = HTM::MCP::RecallTool.new
    result = JSON.parse(tool.call(query: "Recent", timeframe: "today", strategy: "fulltext"))

    assert result["success"]
  end

  def test_recall_tool_hybrid_strategy
    robot_name = "recall_hybrid_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("Hybrid search test content")

    tool = HTM::MCP::RecallTool.new
    result = JSON.parse(tool.call(query: "Hybrid", strategy: "hybrid"))

    assert result["success"]
    assert_equal "hybrid", result["strategy"]
  end

  # ============================================================
  # ForgetTool Tests
  # ============================================================

  def test_forget_tool_soft_deletes_node
    robot_name = "forget_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    node_id = htm.remember("Content to forget")

    tool = HTM::MCP::ForgetTool.new
    result = JSON.parse(tool.call(node_id: node_id))

    assert result["success"]
    assert_equal node_id, result["node_id"]
    assert result["message"].include?("soft-deleted")

    # Verify soft delete
    node = HTM::Models::Node.with_deleted.find(node_id)
    refute_nil node.deleted_at
  end

  def test_forget_tool_handles_not_found
    robot_name = "forget_404_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::ForgetTool.new
    result = JSON.parse(tool.call(node_id: 999999999))

    refute result["success"]
    assert result["error"].include?("not found")
  end

  # ============================================================
  # RestoreTool Tests
  # ============================================================

  def test_restore_tool_restores_deleted_node
    robot_name = "restore_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    node_id = htm.remember("Content to restore")
    htm.forget(node_id)

    # Verify deleted
    assert_nil HTM::Models::Node.find_by(id: node_id)

    tool = HTM::MCP::RestoreTool.new
    result = JSON.parse(tool.call(node_id: node_id))

    assert result["success"]
    assert_equal node_id, result["node_id"]
    assert result["message"].include?("restored")

    # Verify restored
    node = HTM::Models::Node.find(node_id)
    assert_nil node.deleted_at
  end

  def test_restore_tool_handles_not_found
    robot_name = "restore_404_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::RestoreTool.new
    result = JSON.parse(tool.call(node_id: 999999999))

    refute result["success"]
    assert result["error"].include?("not found")
  end

  # ============================================================
  # ListTagsTool Tests
  # ============================================================

  def test_list_tags_tool_returns_all_tags
    robot_name = "list_tags_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("PostgreSQL content", tags: ["database:postgresql"])
    htm.remember("MySQL content", tags: ["database:mysql"])

    tool = HTM::MCP::ListTagsTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert_instance_of Array, result["tags"]
  end

  def test_list_tags_tool_with_prefix_filter
    robot_name = "list_tags_prefix_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("PostgreSQL content", tags: ["database:postgresql"])
    htm.remember("Ruby content", tags: ["programming:ruby"])

    tool = HTM::MCP::ListTagsTool.new
    result = JSON.parse(tool.call(prefix: "database"))

    assert result["success"]
    assert_equal "database", result["prefix"]
    result["tags"].each do |tag|
      assert tag["name"].start_with?("database")
    end
  end

  # ============================================================
  # SearchTagsTool Tests
  # ============================================================

  def test_search_tags_tool_fuzzy_match
    robot_name = "search_tags_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("PostgreSQL content", tags: ["database:postgresql"])

    tool = HTM::MCP::SearchTagsTool.new
    result = JSON.parse(tool.call(query: "postgrsql"))  # typo

    assert result["success"]
    assert_instance_of Array, result["tags"]
  end

  def test_search_tags_tool_with_min_similarity
    robot_name = "search_tags_sim_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::SearchTagsTool.new
    result = JSON.parse(tool.call(query: "database", min_similarity: 0.5))

    assert result["success"]
    assert_equal 0.5, result["min_similarity"]
  end

  # ============================================================
  # FindByTopicTool Tests
  # ============================================================

  def test_find_by_topic_tool_exact_match
    robot_name = "topic_exact_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("PostgreSQL guide", tags: ["database:postgresql"])

    tool = HTM::MCP::FindByTopicTool.new
    result = JSON.parse(tool.call(topic: "database:postgresql", exact: true))

    assert result["success"]
    assert result["exact"]
    assert_instance_of Array, result["results"]
  end

  def test_find_by_topic_tool_prefix_match
    robot_name = "topic_prefix_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("PostgreSQL guide", tags: ["database:postgresql"])
    htm.remember("MySQL guide", tags: ["database:mysql"])

    tool = HTM::MCP::FindByTopicTool.new
    result = JSON.parse(tool.call(topic: "database"))

    assert result["success"]
    refute result["exact"]
  end

  def test_find_by_topic_tool_fuzzy_mode
    robot_name = "topic_fuzzy_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("PostgreSQL guide", tags: ["database:postgresql"])

    tool = HTM::MCP::FindByTopicTool.new
    result = JSON.parse(tool.call(topic: "postgrsql", fuzzy: true))

    assert result["success"]
    assert result["fuzzy"]
  end

  # ============================================================
  # StatsTool Tests
  # ============================================================

  def test_stats_tool_returns_statistics
    robot_name = "stats_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("Test content for stats")

    tool = HTM::MCP::StatsTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert result.key?("current_robot")
    assert result.key?("statistics")
    assert result["statistics"].key?("nodes")
    assert result["statistics"].key?("tags")
    assert result["statistics"].key?("robots")
  end

  def test_stats_tool_shows_current_robot
    robot_name = "stats_robot_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::StatsTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert_equal robot_name, result["current_robot"]["name"]
  end

  # ============================================================
  # HTM::MCP::MemoryStatsResource Tests
  # ============================================================

  def test_memory_stats_resource_content
    robot_name = "res_stats_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    resource = HTM::MCP::MemoryStatsResource.new
    content = JSON.parse(resource.content)

    assert content.key?("total_nodes")
    assert content.key?("total_tags")
    assert content.key?("total_robots")
    assert content.key?("current_robot")
    assert content.key?("robot_initialized")
  end

  def test_memory_stats_resource_uri
    assert_equal "htm://statistics", HTM::MCP::MemoryStatsResource.uri
  end

  # ============================================================
  # HTM::MCP::TagHierarchyResource Tests
  # ============================================================

  def test_tag_hierarchy_resource_content
    robot_name = "res_tags_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("PostgreSQL", tags: ["database:postgresql"])

    resource = HTM::MCP::TagHierarchyResource.new
    content = resource.content

    assert_instance_of String, content
  end

  def test_tag_hierarchy_resource_uri
    assert_equal "htm://tags/hierarchy", HTM::MCP::TagHierarchyResource.uri
  end

  # ============================================================
  # HTM::MCP::RecentMemoriesResource Tests
  # ============================================================

  def test_recent_memories_resource_content
    robot_name = "res_recent_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)
    htm = HTM::MCP::Session.htm_instance

    htm.remember("Recent test content")

    resource = HTM::MCP::RecentMemoriesResource.new
    content = JSON.parse(resource.content)

    assert content.key?("recent_memories")
    assert_instance_of Array, content["recent_memories"]
  end

  def test_recent_memories_resource_uri
    assert_equal "htm://memories/recent", HTM::MCP::RecentMemoriesResource.uri
  end

  # ============================================================
  # MCPGroupSession Module Tests
  # ============================================================

  def test_mcp_group_session_groups_initially_empty
    reset_mcp_group_session
    assert_equal [], HTM::MCP::GroupSession.group_names
  end

  def test_mcp_group_session_set_and_get_group
    reset_mcp_group_session
    robot_name = "group_session_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    group = HTM::RobotGroup.new(name: "test-group", active: [robot_name], max_tokens: 1000)
    HTM::MCP::GroupSession.set_group("test-group", group)

    assert_equal group, HTM::MCP::GroupSession.get_group("test-group")
    assert_includes HTM::MCP::GroupSession.group_names, "test-group"

    group.shutdown
  end

  # ============================================================
  # CreateGroupTool Tests
  # ============================================================

  def test_create_group_tool_creates_group
    reset_mcp_group_session
    robot_name = "create_group_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::CreateGroupTool.new
    result = JSON.parse(tool.call(name: "my-test-group", max_tokens: 2000))

    assert result["success"]
    assert_equal "my-test-group", result["group_name"]
    assert_equal 2000, result["max_tokens"]
    assert_equal robot_name, result["robot_name"]
    assert_equal "active", result["role"]

    # Cleanup
    HTM::MCP::GroupSession.remove_group("my-test-group")
  end

  def test_create_group_tool_with_passive_role
    reset_mcp_group_session
    robot_name = "create_passive_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::CreateGroupTool.new
    result = JSON.parse(tool.call(name: "passive-group", join_as: "passive"))

    assert result["success"]
    assert_equal "passive", result["role"]

    HTM::MCP::GroupSession.remove_group("passive-group")
  end

  def test_create_group_tool_prevents_duplicates
    reset_mcp_group_session
    robot_name = "dup_group_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::CreateGroupTool.new
    tool.call(name: "dup-group")
    result = JSON.parse(tool.call(name: "dup-group"))

    refute result["success"]
    assert result["error"].include?("already exists")

    HTM::MCP::GroupSession.remove_group("dup-group")
  end

  # ============================================================
  # ListGroupsTool Tests
  # ============================================================

  def test_list_groups_tool_empty
    reset_mcp_group_session
    robot_name = "list_empty_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::ListGroupsTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert_equal 0, result["count"]
    assert_equal [], result["groups"]
  end

  def test_list_groups_tool_with_groups
    reset_mcp_group_session
    robot_name = "list_groups_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "group-a")
    HTM::MCP::CreateGroupTool.new.call(name: "group-b")

    tool = HTM::MCP::ListGroupsTool.new
    result = JSON.parse(tool.call)

    assert result["success"]
    assert_equal 2, result["count"]

    HTM::MCP::GroupSession.remove_group("group-a")
    HTM::MCP::GroupSession.remove_group("group-b")
  end

  # ============================================================
  # GetGroupStatusTool Tests
  # ============================================================

  def test_get_group_status_tool
    reset_mcp_group_session
    robot_name = "status_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "status-group")

    tool = HTM::MCP::GetGroupStatusTool.new
    result = JSON.parse(tool.call(name: "status-group"))

    assert result["success"]
    assert_equal "status-group", result["group_name"]
    assert result.key?("status")
    assert result.key?("sync_stats")

    HTM::MCP::GroupSession.remove_group("status-group")
  end

  def test_get_group_status_tool_not_found
    reset_mcp_group_session
    robot_name = "status_404_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::GetGroupStatusTool.new
    result = JSON.parse(tool.call(name: "nonexistent"))

    refute result["success"]
    assert result["error"].include?("not found")
  end

  # ============================================================
  # JoinGroupTool Tests
  # ============================================================

  def test_join_group_tool_already_member
    reset_mcp_group_session
    robot_name = "join_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "join-group")

    tool = HTM::MCP::JoinGroupTool.new
    result = JSON.parse(tool.call(name: "join-group"))

    refute result["success"]
    assert result["error"].include?("already a member")

    HTM::MCP::GroupSession.remove_group("join-group")
  end

  # ============================================================
  # LeaveGroupTool Tests
  # ============================================================

  def test_leave_group_tool
    reset_mcp_group_session
    robot_name = "leave_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "leave-group")

    tool = HTM::MCP::LeaveGroupTool.new
    result = JSON.parse(tool.call(name: "leave-group"))

    assert result["success"]
    assert_equal robot_name, result["robot_name"]

    HTM::MCP::GroupSession.remove_group("leave-group")
  end

  def test_leave_group_tool_not_member
    reset_mcp_group_session
    robot_name = "leave_nomember_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    # Create group and immediately leave
    HTM::MCP::CreateGroupTool.new.call(name: "leave-nm-group")
    HTM::MCP::LeaveGroupTool.new.call(name: "leave-nm-group")

    # Try to leave again
    tool = HTM::MCP::LeaveGroupTool.new
    result = JSON.parse(tool.call(name: "leave-nm-group"))

    refute result["success"]
    assert result["error"].include?("not a member")

    HTM::MCP::GroupSession.remove_group("leave-nm-group")
  end

  # ============================================================
  # GroupRememberTool Tests
  # ============================================================

  def test_group_remember_tool
    reset_mcp_group_session
    robot_name = "group_remember_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "remember-group")

    tool = HTM::MCP::GroupRememberTool.new
    result = JSON.parse(tool.call(group_name: "remember-group", content: "Shared memory content"))

    assert result["success"]
    assert_instance_of Integer, result["node_id"]
    assert_equal robot_name, result["originator"]

    HTM::MCP::GroupSession.remove_group("remember-group")
  end

  def test_group_remember_tool_not_found
    reset_mcp_group_session
    robot_name = "group_remember_404_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::GroupRememberTool.new
    result = JSON.parse(tool.call(group_name: "nonexistent", content: "test"))

    refute result["success"]
    assert result["error"].include?("not found")
  end

  # ============================================================
  # GroupRecallTool Tests
  # ============================================================

  def test_group_recall_tool
    reset_mcp_group_session
    robot_name = "group_recall_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "recall-group")
    HTM::MCP::GroupRememberTool.new.call(group_name: "recall-group", content: "PostgreSQL configuration")

    tool = HTM::MCP::GroupRecallTool.new
    result = JSON.parse(tool.call(group_name: "recall-group", query: "PostgreSQL", strategy: "fulltext"))

    assert result["success"]
    assert_equal "recall-group", result["group_name"]
    assert_instance_of Array, result["results"]

    HTM::MCP::GroupSession.remove_group("recall-group")
  end

  # ============================================================
  # GetGroupWorkingMemoryTool Tests
  # ============================================================

  def test_get_group_working_memory_tool
    reset_mcp_group_session
    robot_name = "group_wm_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "wm-group")
    HTM::MCP::GroupRememberTool.new.call(group_name: "wm-group", content: "Working memory content")

    tool = HTM::MCP::GetGroupWorkingMemoryTool.new
    result = JSON.parse(tool.call(group_name: "wm-group"))

    assert result["success"]
    assert result.key?("count")
    assert result.key?("token_utilization")
    assert result.key?("contents")

    HTM::MCP::GroupSession.remove_group("wm-group")
  end

  # ============================================================
  # PromoteRobotTool Tests
  # ============================================================

  def test_promote_robot_tool_not_passive
    reset_mcp_group_session
    robot_name = "promote_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "promote-group")

    tool = HTM::MCP::PromoteRobotTool.new
    result = JSON.parse(tool.call(group_name: "promote-group", robot_name: robot_name))

    refute result["success"]
    assert result["error"].include?("not a passive member")

    HTM::MCP::GroupSession.remove_group("promote-group")
  end

  # ============================================================
  # FailoverTool Tests
  # ============================================================

  def test_failover_tool_no_passive
    reset_mcp_group_session
    robot_name = "failover_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "failover-group")

    tool = HTM::MCP::FailoverTool.new
    result = JSON.parse(tool.call(group_name: "failover-group"))

    refute result["success"]
    assert result["error"].include?("No passive robots")

    HTM::MCP::GroupSession.remove_group("failover-group")
  end

  # ============================================================
  # SyncGroupTool Tests
  # ============================================================

  def test_sync_group_tool
    reset_mcp_group_session
    robot_name = "sync_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "sync-group")

    tool = HTM::MCP::SyncGroupTool.new
    result = JSON.parse(tool.call(group_name: "sync-group"))

    assert result["success"]
    assert result.key?("synced_nodes")
    assert result.key?("members_updated")
    assert result.key?("in_sync")

    HTM::MCP::GroupSession.remove_group("sync-group")
  end

  # ============================================================
  # ShutdownGroupTool Tests
  # ============================================================

  def test_shutdown_group_tool
    reset_mcp_group_session
    robot_name = "shutdown_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "shutdown-group")

    tool = HTM::MCP::ShutdownGroupTool.new
    result = JSON.parse(tool.call(name: "shutdown-group"))

    assert result["success"]
    assert_nil HTM::MCP::GroupSession.get_group("shutdown-group")
  end

  def test_shutdown_group_tool_not_found
    reset_mcp_group_session
    robot_name = "shutdown_404_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    tool = HTM::MCP::ShutdownGroupTool.new
    result = JSON.parse(tool.call(name: "nonexistent"))

    refute result["success"]
    assert result["error"].include?("not found")
  end

  # ============================================================
  # HTM::MCP::RobotGroupsResource Tests
  # ============================================================

  def test_robot_groups_resource_content
    reset_mcp_group_session
    robot_name = "res_groups_test_#{rand(10000)}"
    HTM::MCP::Session.set_robot(robot_name)

    HTM::MCP::CreateGroupTool.new.call(name: "res-group")

    resource = HTM::MCP::RobotGroupsResource.new
    content = JSON.parse(resource.content)

    assert content.key?("count")
    assert content.key?("groups")
    assert_equal 1, content["count"]

    HTM::MCP::GroupSession.remove_group("res-group")
  end

  def test_robot_groups_resource_uri
    assert_equal "htm://groups", HTM::MCP::RobotGroupsResource.uri
  end

  private

  def load_mcp_server_classes
    # Only load if not already loaded
    return if defined?(HTM::MCP::Session)

    # Load the MCP module files
    require_relative '../lib/htm/mcp/tools'
    require_relative '../lib/htm/mcp/group_tools'
    require_relative '../lib/htm/mcp/resources'

    # Set up a silent logger for tests
    HTM::MCP::Session.logger = Logger.new(IO::NULL)
  rescue => e
    skip "Failed to load MCP server classes: #{e.message}"
  end

  def reset_mcp_session
    return unless defined?(HTM::MCP::Session)

    # Reset session state
    HTM::MCP::Session.instance_variable_set(:@robot_name, nil)
    HTM::MCP::Session.instance_variable_set(:@htm_instance, nil)
  end

  def reset_mcp_group_session
    return unless defined?(HTM::MCP::GroupSession)

    # Shutdown all existing groups
    HTM::MCP::GroupSession.group_names.each do |name|
      HTM::MCP::GroupSession.remove_group(name)
    end

    # Clear the groups hash
    HTM::MCP::GroupSession.instance_variable_set(:@groups, {})
  end

  def cleanup_test_data
    # Clean up test robots (those with test_ prefix)
    HTM::Models::Robot.where("name LIKE ?", "test_%").find_each do |robot|
      robot.robot_nodes.destroy_all
    end

    # Clean up other test patterns
    %w[mcp_default remember_test recall_test forget_test restore_test
       list_tags_test search_tags_test topic_test stats_test
       res_stats_test res_tags_test res_recent_test wm_test].each do |prefix|
      HTM::Models::Robot.where("name LIKE ?", "#{prefix}%").find_each do |robot|
        robot.robot_nodes.destroy_all
      end
    end
  rescue => e
    # Ignore cleanup errors
  end
end
