# frozen_string_literal: true

require "test_helper"

class RobotGroupTest < Minitest::Test
  def setup
    skip_without_database
    configure_htm_with_mocks

    # Clean up any existing test data
    cleanup_test_data

    @group_name = "test-group-#{SecureRandom.hex(4)}"
  end

  def teardown
    @group&.shutdown
    cleanup_test_data
  end

  # ========================================
  # Initialization Tests
  # ========================================

  def test_initialization_with_defaults
    @group = HTM::RobotGroup.new(name: @group_name)

    assert_equal @group_name, @group.name
    assert_equal 4000, @group.max_tokens
    assert_equal [], @group.active_robot_names
    assert_equal [], @group.passive_robot_names
  end

  def test_initialization_with_custom_max_tokens
    @group = HTM::RobotGroup.new(name: @group_name, max_tokens: 8000)

    assert_equal 8000, @group.max_tokens
  end

  def test_initialization_with_active_robots
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1", "agent-2"]
    )

    assert_equal 2, @group.active_robot_names.length
    assert_includes @group.active_robot_names, "agent-1"
    assert_includes @group.active_robot_names, "agent-2"
  end

  def test_initialization_with_passive_robots
    @group = HTM::RobotGroup.new(
      name: @group_name,
      passive: ["standby-1", "standby-2"]
    )

    assert_equal 2, @group.passive_robot_names.length
    assert_includes @group.passive_robot_names, "standby-1"
    assert_includes @group.passive_robot_names, "standby-2"
  end

  def test_initialization_with_mixed_robots
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["primary"],
      passive: ["standby"]
    )

    assert_equal ["primary"], @group.active_robot_names
    assert_equal ["standby"], @group.passive_robot_names
  end

  # ========================================
  # Membership Management Tests
  # ========================================

  def test_add_active_robot
    @group = HTM::RobotGroup.new(name: @group_name)

    robot_id = @group.add_active("new-agent")

    assert robot_id.is_a?(Integer)
    assert @group.member?("new-agent")
    assert @group.active?("new-agent")
    refute @group.passive?("new-agent")
  end

  def test_add_passive_robot
    @group = HTM::RobotGroup.new(name: @group_name)

    robot_id = @group.add_passive("standby-agent")

    assert robot_id.is_a?(Integer)
    assert @group.member?("standby-agent")
    assert @group.passive?("standby-agent")
    refute @group.active?("standby-agent")
  end

  def test_add_active_raises_for_duplicate
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert_raises(ArgumentError) do
      @group.add_active("agent-1")
    end
  end

  def test_add_passive_raises_for_duplicate
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    assert_raises(ArgumentError) do
      @group.add_passive("standby-1")
    end
  end

  def test_add_active_raises_for_existing_passive
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["agent-1"])

    assert_raises(ArgumentError) do
      @group.add_active("agent-1")
    end
  end

  def test_remove_active_robot
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    @group.remove("agent-1")

    refute @group.member?("agent-1")
    refute @group.active?("agent-1")
  end

  def test_remove_passive_robot
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    @group.remove("standby-1")

    refute @group.member?("standby-1")
    refute @group.passive?("standby-1")
  end

  def test_remove_nonexistent_robot_is_noop
    @group = HTM::RobotGroup.new(name: @group_name)

    # Should not raise
    @group.remove("nonexistent")

    refute @group.member?("nonexistent")
  end

  def test_promote_passive_to_active
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    @group.promote("standby-1")

    assert @group.active?("standby-1")
    refute @group.passive?("standby-1")
  end

  def test_promote_raises_for_non_passive
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert_raises(ArgumentError) do
      @group.promote("agent-1")
    end
  end

  def test_demote_active_to_passive
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1", "agent-2"]
    )

    @group.demote("agent-1")

    assert @group.passive?("agent-1")
    refute @group.active?("agent-1")
  end

  def test_demote_raises_for_non_active
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    assert_raises(ArgumentError) do
      @group.demote("standby-1")
    end
  end

  def test_demote_raises_for_last_active
    @group = HTM::RobotGroup.new(name: @group_name, active: ["only-agent"])

    assert_raises(ArgumentError) do
      @group.demote("only-agent")
    end
  end

  def test_member_ids
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1"],
      passive: ["standby-1"]
    )

    ids = @group.member_ids

    assert_equal 2, ids.length
    assert ids.all? { |id| id.is_a?(Integer) }
  end

  # ========================================
  # Membership Query Tests
  # ========================================

  def test_member_returns_true_for_active
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert @group.member?("agent-1")
  end

  def test_member_returns_true_for_passive
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    assert @group.member?("standby-1")
  end

  def test_member_returns_false_for_unknown
    @group = HTM::RobotGroup.new(name: @group_name)

    refute @group.member?("unknown")
  end

  def test_active_returns_true_for_active_robot
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert @group.active?("agent-1")
  end

  def test_active_returns_false_for_passive_robot
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    refute @group.active?("standby-1")
  end

  def test_passive_returns_true_for_passive_robot
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    assert @group.passive?("standby-1")
  end

  def test_passive_returns_false_for_active_robot
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    refute @group.passive?("agent-1")
  end

  # ========================================
  # Shared Working Memory Tests
  # ========================================

  def test_remember_creates_node
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    node_id = @group.remember("Test memory content")

    assert node_id.is_a?(Integer)
    node = HTM::Models::Node[node_id]
    assert_equal "Test memory content", node.content
  end

  def test_remember_raises_without_active_robots
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    assert_raises(RuntimeError) do
      @group.remember("Test content")
    end
  end

  def test_remember_with_specific_originator
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1", "agent-2"]
    )

    node_id = @group.remember("Content from agent-2", originator: "agent-2")

    assert node_id.is_a?(Integer)
  end

  def test_remember_syncs_to_all_members
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1"],
      passive: ["standby-1"]
    )

    node_id = @group.remember("Shared memory")

    # Check that robot_nodes exist for all members
    member_ids = @group.member_ids
    member_ids.each do |robot_id|
      robot_node = HTM::Models::RobotNode.first(
        robot_id: robot_id,
        node_id: node_id
      )
      assert robot_node, "Expected RobotNode for robot_id #{robot_id}"
      assert robot_node.working_memory?, "Expected working_memory=true"
    end
  end

  def test_recall_searches_working_memory
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])
    @group.remember("PostgreSQL is a relational database")
    @group.remember("Redis is a key-value store")

    # Allow async processing to complete
    sleep 0.1

    results = @group.recall("database", limit: 5)

    assert results.is_a?(Array)
  end

  def test_recall_raises_without_active_robots
    @group = HTM::RobotGroup.new(name: @group_name, passive: ["standby-1"])

    assert_raises(RuntimeError) do
      @group.recall("test query")
    end
  end

  def test_working_memory_contents
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])
    @group.remember("Memory 1")
    @group.remember("Memory 2")

    contents = @group.working_memory_contents

    assert contents.is_a?(Sequel::Dataset)
    assert_equal 2, contents.count
  end

  def test_clear_working_memory
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])
    @group.remember("Memory to clear")

    count = @group.clear_working_memory

    assert count >= 1
    assert_equal 0, @group.working_memory_contents.count
  end

  # ========================================
  # Synchronization Tests
  # ========================================

  def test_sync_robot
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])
    @group.remember("Existing memory")

    # Add new member
    @group.add_passive("standby-1")

    # Sync should have happened automatically
    contents = @group.working_memory_contents
    assert_equal 1, contents.count
  end

  def test_sync_robot_raises_for_non_member
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert_raises(ArgumentError) do
      @group.sync_robot("unknown")
    end
  end

  def test_sync_all
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1"],
      passive: ["standby-1"]
    )
    @group.remember("Shared memory")

    result = @group.sync_all

    assert result.is_a?(Hash)
    assert result.key?(:synced_nodes)
    assert result.key?(:members_updated)
  end

  def test_in_sync_with_single_member
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert @group.in_sync?
  end

  def test_in_sync_after_remember
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1"],
      passive: ["standby-1"]
    )
    @group.remember("Shared memory")

    # Allow sync to complete
    sleep 0.1

    assert @group.in_sync?
  end

  # ========================================
  # Failover Tests
  # ========================================

  def test_transfer_working_memory
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1"],
      passive: ["standby-1"]
    )
    @group.remember("Memory to transfer")

    transferred = @group.transfer_working_memory("agent-1", "standby-1")

    assert transferred >= 1
  end

  def test_transfer_working_memory_with_clear_source_false
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1", "agent-2"]
    )
    @group.remember("Memory to copy")

    transferred = @group.transfer_working_memory(
      "agent-1",
      "agent-2",
      clear_source: false
    )

    assert transferred >= 1
  end

  def test_transfer_working_memory_raises_for_invalid_source
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert_raises(ArgumentError) do
      @group.transfer_working_memory("unknown", "agent-1")
    end
  end

  def test_transfer_working_memory_raises_for_invalid_target
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert_raises(ArgumentError) do
      @group.transfer_working_memory("agent-1", "unknown")
    end
  end

  def test_failover_promotes_first_passive
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1"],
      passive: ["standby-1", "standby-2"]
    )

    promoted = @group.failover!

    assert_equal "standby-1", promoted
    assert @group.active?("standby-1")
    refute @group.passive?("standby-1")
  end

  def test_failover_raises_without_passive_robots
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert_raises(RuntimeError) do
      @group.failover!
    end
  end

  # ========================================
  # Status Tests
  # ========================================

  def test_status_returns_comprehensive_info
    @group = HTM::RobotGroup.new(
      name: @group_name,
      active: ["agent-1"],
      passive: ["standby-1"],
      max_tokens: 8000
    )
    @group.remember("Test memory")

    status = @group.status

    assert_equal @group_name, status[:name]
    assert_equal ["agent-1"], status[:active]
    assert_equal ["standby-1"], status[:passive]
    assert_equal 2, status[:total_members]
    assert_equal 1, status[:working_memory_nodes]
    assert status[:working_memory_tokens] >= 0
    assert_equal 8000, status[:max_tokens]
    assert status[:token_utilization] >= 0
    assert [true, false].include?(status[:in_sync])
  end

  def test_sync_stats
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    stats = @group.sync_stats

    assert stats.is_a?(Hash)
    assert stats.key?(:nodes_synced)
    assert stats.key?(:evictions_synced)
  end

  # ========================================
  # Channel Tests
  # ========================================

  def test_channel_is_available
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    assert @group.channel.is_a?(HTM::WorkingMemoryChannel)
  end

  def test_shutdown_stops_channel
    @group = HTM::RobotGroup.new(name: @group_name, active: ["agent-1"])

    @group.shutdown

    refute @group.channel.listening?
  end

  private

  def cleanup_test_data
    return unless database_available?

    # Clean up test robots and nodes
    HTM::Models::Robot.where(
      Sequel.like(:name, "agent-%") |
      Sequel.like(:name, "standby-%") |
      Sequel.like(:name, "new-%") |
      Sequel.like(:name, "primary%") |
      Sequel.like(:name, "only-%")
    ).delete
  rescue => e
    # Ignore cleanup errors
  end
end
