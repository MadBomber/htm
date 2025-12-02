# robot_groups/lib/robot_group.rb
# frozen_string_literal: true
#
# Application-level coordination for shared working memory

class RobotGroup
  attr_reader :name, :max_tokens, :channel

  def initialize(name:, active: [], passive: [], max_tokens: 4000, db_config: nil)
    @name           = name
    @max_tokens     = max_tokens
    @active_robots  = {} # name => HTM instance
    @passive_robots = {} # name => HTM instance
    @sync_stats     = { nodes_synced: 0, evictions_synced: 0 }
    @mutex          = Mutex.new

    # Setup pub/sub channel for real-time sync
    @db_config  = db_config || HTM::Database.default_config
    @channel    = WorkingMemoryChannel.new(name, @db_config)

    # Subscribe to working memory changes
    setup_sync_listener

    # Start listening for notifications
    @channel.start_listening

    # Initialize robots
    active.each  { |robot_name| add_active(robot_name) }
    passive.each { |robot_name| add_passive(robot_name) }
  end


  # Shutdown the group (stop listener thread)
  def shutdown
    @channel.stop_listening
  end

  # ===========================================================================
  # Membership Management
  # ===========================================================================

  def add_active(robot_name)
    raise ArgumentError, "#{robot_name} is already a member" if member?(robot_name)

    htm = HTM.new(robot_name: robot_name, working_memory_size: @max_tokens)
    @active_robots[robot_name] = htm

    # Sync existing shared working memory to new member
    sync_robot(robot_name) if member_ids.length > 1

    htm.robot_id
  end


  def add_passive(robot_name)
    raise ArgumentError, "#{robot_name} is already a member" if member?(robot_name)

    htm = HTM.new(robot_name: robot_name, working_memory_size: @max_tokens)
    @passive_robots[robot_name] = htm

    # Sync existing shared working memory to new member
    sync_robot(robot_name) if member_ids.length > 1

    htm.robot_id
  end


  def remove(robot_name)
    htm = @active_robots.delete(robot_name) || @passive_robots.delete(robot_name)
    return unless htm

    # Clear working memory flags for this robot
    HTM::Models::RobotNode
      .where(robot_id: htm.robot_id, working_memory: true)
      .update_all(working_memory: false)
  end


  def promote(robot_name)
    raise ArgumentError, "#{robot_name} is not a passive member" unless passive?(robot_name)

    htm = @passive_robots.delete(robot_name)
    @active_robots[robot_name] = htm
  end


  def demote(robot_name)
    raise ArgumentError, "#{robot_name} is not an active member" unless active?(robot_name)
    raise ArgumentError, 'Cannot demote last active robot' if @active_robots.length == 1

    htm = @active_robots.delete(robot_name)
    @passive_robots[robot_name] = htm
  end


  def member?(robot_name)
    @active_robots.key?(robot_name) || @passive_robots.key?(robot_name)
  end


  def active?(robot_name)
    @active_robots.key?(robot_name)
  end


  def passive?(robot_name)
    @passive_robots.key?(robot_name)
  end


  def member_ids
    all_robots.values.map(&:robot_id)
  end


  def active_robot_names
    @active_robots.keys
  end


  def passive_robot_names
    @passive_robots.keys
  end

  # ===========================================================================
  # Shared Working Memory Operations
  # ===========================================================================

  # Add memory to shared working memory for all group members
  def remember(content, originator: nil, **options)
    raise 'No active robots in group' if @active_robots.empty?

    # Use first active robot (or specified originator) to create the memory
    primary = if originator && all_robots[originator]
                all_robots[originator]
              else
                @active_robots.values.first
              end

    node_id = primary.remember(content, **options)

    # Sync to database (robot_nodes table) for all other members
    sync_node_to_members(node_id, exclude: primary.robot_id)

    # Notify all listeners via PostgreSQL NOTIFY (triggers in-memory sync)
    @channel.notify(:added, node_id: node_id, robot_id: primary.robot_id)

    node_id
  end


  # Recall from shared working memory (uses first active robot)
  def recall(query, **options)
    raise 'No active robots in group' if @active_robots.empty?

    primary = @active_robots.values.first
    primary.recall(query, **options)
  end


  # Get shared working memory contents (union of all members)
  def working_memory_contents
    node_ids = HTM::Models::RobotNode
               .where(robot_id: member_ids, working_memory: true)
               .distinct
               .pluck(:node_id)

    HTM::Models::Node.where(id: node_ids).order(created_at: :desc)
  end


  # Clear shared working memory for all members
  def clear_working_memory
    count = HTM::Models::RobotNode
            .where(robot_id: member_ids, working_memory: true)
            .update_all(working_memory: false)

    # Clear in-memory working memory for primary robot
    primary = @active_robots.values.first || @passive_robots.values.first
    return 0 unless primary

    primary.clear_working_memory

    # Notify all listeners (will clear other in-memory caches via callback)
    @channel.notify(:cleared, node_id: nil, robot_id: primary.robot_id)

    count
  end

  # ===========================================================================
  # Synchronization
  # ===========================================================================

  # Sync a specific robot to match group's shared working memory
  def sync_robot(robot_name)
    htm = all_robots[robot_name]
    raise ArgumentError, "#{robot_name} is not a member" unless htm

    # Get all node_ids currently in any member's working memory
    shared_node_ids = HTM::Models::RobotNode
                      .where(robot_id: member_ids, working_memory: true)
                      .where.not(robot_id: htm.robot_id)
                      .distinct
                      .pluck(:node_id)

    synced = 0
    shared_node_ids.each do |node_id|
      # Create or update robot_node with working_memory=true
      robot_node = HTM::Models::RobotNode.find_or_initialize_by(
        robot_id: htm.robot_id,
        node_id: node_id
      )
      next if robot_node.working_memory?

      robot_node.working_memory = true
      robot_node.save!
      synced += 1
    end

    synced
  end


  # Sync all members to consistent state
  def sync_all
    members_updated = 0
    total_synced    = 0

    all_robots.each_key do |robot_name|
      synced = sync_robot(robot_name)
      if synced > 0
        members_updated += 1
        total_synced    += synced
      end
    end

    { synced_nodes: total_synced, members_updated: members_updated }
  end


  # Check if all members have identical working memory
  def in_sync?
    return true if member_ids.length <= 1

    # Get working memory node_ids for each robot
    working_memories = member_ids.map do |robot_id|
      HTM::Models::RobotNode
        .where(robot_id: robot_id, working_memory: true)
        .pluck(:node_id)
        .sort
    end

    # All should be identical
    working_memories.uniq.length == 1
  end

  # ===========================================================================
  # Failover
  # ===========================================================================

  # Transfer working memory from one robot to another
  def transfer_working_memory(from_robot, to_robot, clear_source: true)
    from_htm = all_robots[from_robot]
    to_htm = all_robots[to_robot]

    raise ArgumentError, "#{from_robot} is not a member" unless from_htm
    raise ArgumentError, "#{to_robot} is not a member" unless to_htm

    # Get source's working memory nodes
    source_node_ids = HTM::Models::RobotNode
                      .where(robot_id: from_htm.robot_id, working_memory: true)
                      .pluck(:node_id)

    transferred = 0
    source_node_ids.each do |node_id|
      robot_node = HTM::Models::RobotNode.find_or_initialize_by(
        robot_id: to_htm.robot_id,
        node_id: node_id
      )
      robot_node.working_memory = true
      robot_node.save!
      transferred += 1
    end

    # Clear source's working memory if requested
    if clear_source
      HTM::Models::RobotNode
        .where(robot_id: from_htm.robot_id, working_memory: true)
        .update_all(working_memory: false)
    end

    transferred
  end


  # Simulate failover: promote first passive robot
  def failover!
    raise 'No passive robots available for failover' if @passive_robots.empty?

    # Get first passive robot
    standby_name = @passive_robots.keys.first

    # Promote it
    promote(standby_name)

    puts "  ⚡ Failover: #{standby_name} promoted to active"
    standby_name
  end

  # ===========================================================================
  # Status & Health
  # ===========================================================================

  def status
    wm_contents = working_memory_contents
    token_count = wm_contents.sum { |n| n.token_count || 0 }

    {
      name: @name,
      active: active_robot_names,
      passive: passive_robot_names,
      total_members: member_ids.length,
      working_memory_nodes: wm_contents.count,
      working_memory_tokens: token_count,
      max_tokens: @max_tokens,
      token_utilization: @max_tokens > 0 ? (token_count.to_f / @max_tokens).round(2) : 0,
      in_sync: in_sync?
    }
  end


  def sync_stats
    @mutex.synchronize { @sync_stats.dup }
  end

  private

  def all_robots
    @active_robots.merge(@passive_robots)
  end


  # Subscribe to working memory change notifications
  def setup_sync_listener
    @channel.on_change do |event, node_id, origin_robot_id|
      handle_sync_notification(event, node_id, origin_robot_id)
    end
  end


  # Handle incoming working memory change notifications
  def handle_sync_notification(event, node_id, origin_robot_id)
    @mutex.synchronize do
      case event
      when :added
        sync_node_to_in_memory_caches(node_id, origin_robot_id)
        @sync_stats[:nodes_synced] += 1
      when :evicted
        evict_from_in_memory_caches(node_id, origin_robot_id)
        @sync_stats[:evictions_synced] += 1
      when :cleared
        clear_all_in_memory_caches(origin_robot_id)
      end
    end
  end


  # Sync a node to in-memory WorkingMemory caches of other robots
  def sync_node_to_in_memory_caches(node_id, origin_robot_id)
    node = HTM::Models::Node.find_by(id: node_id)
    return unless node

    all_robots.each do |_name, htm|
      next if htm.robot_id == origin_robot_id

      # Add to in-memory working memory without triggering another notification
      htm.working_memory.add_from_sync(
        id: node.id,
        content: node.content,
        token_count: node.token_count || 0,
        created_at: node.created_at
      )
    end
  end


  # Evict a node from in-memory WorkingMemory caches
  def evict_from_in_memory_caches(node_id, origin_robot_id)
    all_robots.each do |_name, htm|
      next if htm.robot_id == origin_robot_id

      htm.working_memory.remove_from_sync(node_id)
    end
  end


  # Clear all in-memory WorkingMemory caches
  def clear_all_in_memory_caches(origin_robot_id)
    all_robots.each do |_name, htm|
      next if htm.robot_id == origin_robot_id

      htm.working_memory.clear_from_sync
    end
  end


  def sync_node_to_members(node_id, exclude: nil)
    member_ids.each do |robot_id|
      next if robot_id == exclude

      robot_node = HTM::Models::RobotNode.find_or_initialize_by(
        robot_id: robot_id,
        node_id: node_id
      )
      robot_node.working_memory = true
      robot_node.save!
    end
  end
end
