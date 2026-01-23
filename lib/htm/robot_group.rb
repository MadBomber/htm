# examples/robot_groups/lib/htm/robot_group.rb
# frozen_string_literal: true

class HTM
  # Coordinates multiple robots with shared working memory and automatic failover.
  #
  # RobotGroup provides application-level coordination for multiple HTM robots,
  # enabling them to share a common working memory context. Key capabilities include:
  #
  # - **Shared Working Memory**: All group members have access to the same context
  # - **Active/Passive Roles**: Active robots participate in conversations; passive
  #   robots maintain synchronized context for instant failover
  # - **Real-time Sync**: PostgreSQL LISTEN/NOTIFY enables immediate synchronization
  # - **Failover**: When an active robot fails, a passive robot takes over instantly
  # - **Dynamic Scaling**: Add or remove robots at runtime
  #
  # @example High-availability customer support setup
  #   group = HTM::RobotGroup.new(
  #     name: 'customer-support',
  #     active: ['primary-agent'],
  #     passive: ['standby-agent'],
  #     max_tokens: 8000
  #   )
  #
  #   # Add shared context
  #   group.remember('Customer prefers email communication.')
  #   group.remember('Open ticket #789 regarding billing issue.')
  #
  #   # Query shared memory
  #   results = group.recall('billing', limit: 5)
  #
  #   # Simulate failover
  #   group.failover!  # Promotes standby to active
  #
  #   # Cleanup
  #   group.shutdown
  #
  # @see HTM::WorkingMemoryChannel Low-level pub/sub mechanism
  #
  class RobotGroup
    # Name of the robot group
    # @return [String]
    attr_reader :name

    # Maximum token budget for working memory
    # @return [Integer]
    attr_reader :max_tokens

    # The pub/sub channel used for real-time synchronization
    # @return [HTM::WorkingMemoryChannel]
    attr_reader :channel

    # Creates a new robot group with optional initial members.
    #
    # Initializes the group, sets up the PostgreSQL pub/sub channel for real-time
    # synchronization, and registers initial active and passive robots.
    #
    # @param name [String] Unique name for this robot group
    # @param active [Array<String>] Names of robots to add as active members
    # @param passive [Array<String>] Names of robots to add as passive (standby) members
    # @param max_tokens [Integer] Maximum token budget for shared working memory
    # @param db_config [Hash, nil] PostgreSQL connection config (defaults to HTM::Database.default_config)
    #
    # @example Create a group with one active and one passive robot
    #   group = HTM::RobotGroup.new(
    #     name: 'support-team',
    #     active: ['agent-1'],
    #     passive: ['agent-2'],
    #     max_tokens: 4000
    #   )
    #
    # @example Create an empty group and add members later
    #   group = HTM::RobotGroup.new(name: 'dynamic-team')
    #   group.add_active('agent-1')
    #   group.add_passive('agent-2')
    #
    def initialize(name:, active: [], passive: [], max_tokens: 4000, db_config: nil)
      @name           = name
      @max_tokens     = max_tokens
      @active_robots  = {} # name => HTM instance
      @passive_robots = {} # name => HTM instance
      @sync_stats     = { nodes_synced: 0, evictions_synced: 0 }
      @mutex          = Mutex.new

      # Setup pub/sub channel for real-time sync
      @db_config  = db_config || HTM::Database.default_config
      @channel    = HTM::WorkingMemoryChannel.new(name, @db_config)

      # Subscribe to working memory changes
      setup_sync_listener

      # Start listening for notifications
      @channel.start_listening

      # Initialize robots
      active.each  { |robot_name| add_active(robot_name) }
      passive.each { |robot_name| add_passive(robot_name) }
    end

    # Shuts down the group by stopping the listener thread.
    #
    # Should be called when the group is no longer needed to release resources
    # and close the PostgreSQL listener connection.
    #
    # @return [void]
    #
    # @example
    #   group.shutdown
    #
    def shutdown
      @channel.stop_listening
    end

    # @!group Membership Management

    # Adds a robot as an active member of the group.
    #
    # Active robots can add memories and respond to queries. The new robot
    # is automatically synchronized with existing shared working memory.
    #
    # @param robot_name [String] Unique name for the robot
    # @return [Integer] The robot's database ID
    # @raise [ArgumentError] if robot_name is already a member
    #
    # @example
    #   robot_id = group.add_active('new-agent')
    #   puts "Added robot with ID: #{robot_id}"
    #
    def add_active(robot_name)
      raise ArgumentError, "#{robot_name} is already a member" if member?(robot_name)

      htm = HTM.new(robot_name: robot_name, working_memory_size: @max_tokens)
      @active_robots[robot_name] = htm

      # Sync existing shared working memory to new member
      sync_robot(robot_name) if member_ids.length > 1

      htm.robot_id
    end

    # Adds a robot as a passive (standby) member of the group.
    #
    # Passive robots maintain synchronized working memory but don't actively
    # participate in conversations. They serve as warm standbys for failover.
    #
    # @param robot_name [String] Unique name for the robot
    # @return [Integer] The robot's database ID
    # @raise [ArgumentError] if robot_name is already a member
    #
    # @example
    #   robot_id = group.add_passive('standby-agent')
    #
    def add_passive(robot_name)
      raise ArgumentError, "#{robot_name} is already a member" if member?(robot_name)

      htm = HTM.new(robot_name: robot_name, working_memory_size: @max_tokens)
      @passive_robots[robot_name] = htm

      # Sync existing shared working memory to new member
      sync_robot(robot_name) if member_ids.length > 1

      htm.robot_id
    end

    # Removes a robot from the group.
    #
    # Clears the robot's working memory flags in the database. The robot can
    # be either active or passive.
    #
    # @param robot_name [String] Name of the robot to remove
    # @return [void]
    #
    # @example
    #   group.remove('departing-agent')
    #
    def remove(robot_name)
      htm = @active_robots.delete(robot_name) || @passive_robots.delete(robot_name)
      return unless htm

      # Clear working memory flags for this robot
      HTM::Models::RobotNode
        .where(robot_id: htm.robot_id, working_memory: true)
        .update(working_memory: false)
    end

    # Promotes a passive robot to active status.
    #
    # The robot retains its synchronized working memory and becomes eligible
    # to handle queries and add memories.
    #
    # @param robot_name [String] Name of the passive robot to promote
    # @return [void]
    # @raise [ArgumentError] if robot_name is not a passive member
    #
    # @example
    #   group.promote('standby-agent')
    #   group.active?('standby-agent')  # => true
    #
    def promote(robot_name)
      raise ArgumentError, "#{robot_name} is not a passive member" unless passive?(robot_name)

      htm = @passive_robots.delete(robot_name)
      @active_robots[robot_name] = htm
    end

    # Demotes an active robot to passive status.
    #
    # The robot retains its working memory but stops handling queries.
    # Cannot demote the last active robot.
    #
    # @param robot_name [String] Name of the active robot to demote
    # @return [void]
    # @raise [ArgumentError] if robot_name is not an active member
    # @raise [ArgumentError] if this is the last active robot
    #
    # @example
    #   group.demote('primary-agent')
    #   group.passive?('primary-agent')  # => true
    #
    def demote(robot_name)
      raise ArgumentError, "#{robot_name} is not an active member" unless active?(robot_name)
      raise ArgumentError, 'Cannot demote last active robot' if @active_robots.length == 1

      htm = @active_robots.delete(robot_name)
      @passive_robots[robot_name] = htm
    end

    # Checks if a robot is a member of this group.
    #
    # @param robot_name [String] Name of the robot to check
    # @return [Boolean] true if the robot is an active or passive member
    #
    # @example
    #   group.member?('agent-1')  # => true
    #   group.member?('unknown')  # => false
    #
    def member?(robot_name)
      @active_robots.key?(robot_name) || @passive_robots.key?(robot_name)
    end

    # Checks if a robot is an active member of this group.
    #
    # @param robot_name [String] Name of the robot to check
    # @return [Boolean] true if the robot is an active member
    #
    # @example
    #   group.active?('primary-agent')  # => true
    #
    def active?(robot_name)
      @active_robots.key?(robot_name)
    end

    # Checks if a robot is a passive member of this group.
    #
    # @param robot_name [String] Name of the robot to check
    # @return [Boolean] true if the robot is a passive member
    #
    # @example
    #   group.passive?('standby-agent')  # => true
    #
    def passive?(robot_name)
      @passive_robots.key?(robot_name)
    end

    # Returns database IDs of all group members.
    #
    # @return [Array<Integer>] Array of robot IDs (both active and passive)
    #
    # @example
    #   group.member_ids  # => [1, 2, 3]
    #
    def member_ids
      all_robots.values.map(&:robot_id)
    end

    # Returns names of all active robots.
    #
    # @return [Array<String>] Array of active robot names
    #
    # @example
    #   group.active_robot_names  # => ['primary-agent', 'secondary-agent']
    #
    def active_robot_names
      @active_robots.keys
    end

    # Returns names of all passive robots.
    #
    # @return [Array<String>] Array of passive robot names
    #
    # @example
    #   group.passive_robot_names  # => ['standby-agent']
    #
    def passive_robot_names
      @passive_robots.keys
    end

    # @!endgroup

    # @!group Shared Working Memory Operations

    # Adds content to shared working memory for all group members.
    #
    # The memory is created by the specified originator (or first active robot)
    # and automatically synchronized to all other members via database and
    # real-time notifications.
    #
    # @param content [String] The content to remember
    # @param originator [String, nil] Name of the robot creating the memory (optional)
    # @param options [Hash] Additional options passed to HTM#remember
    # @return [Integer] The node ID of the created memory
    # @raise [RuntimeError] if no active robots exist in the group
    #
    # @example Add memory with default originator
    #   node_id = group.remember('Customer prefers morning appointments.')
    #
    # @example Add memory with specific originator
    #   node_id = group.remember(
    #     'Escalated to billing department.',
    #     originator: 'agent-2'
    #   )
    #
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

    # Recalls memories from shared working memory.
    #
    # Uses the first active robot to perform the query against the shared
    # working memory context.
    #
    # @param query [String] The search query
    # @param options [Hash] Additional options passed to HTM#recall
    # @option options [Integer] :limit Maximum number of results
    # @option options [Symbol] :strategy Search strategy (:vector, :fulltext, :hybrid)
    # @return [Array] Array of matching memories
    # @raise [RuntimeError] if no active robots exist in the group
    #
    # @example
    #   results = group.recall('billing issue', limit: 5, strategy: :fulltext)
    #
    def recall(query, **options)
      raise 'No active robots in group' if @active_robots.empty?

      primary = @active_robots.values.first
      primary.recall(query, **options)
    end

    # Returns all nodes currently in shared working memory.
    #
    # Queries the database for the union of all members' working memory,
    # returning nodes sorted by creation date (newest first).
    #
    # @return [Sequel::Dataset] Collection of nodes
    #
    # @example
    #   nodes = group.working_memory_contents
    #   nodes.each { |n| puts n.content }
    #
    def working_memory_contents
      node_ids = HTM::Models::RobotNode
                 .where(robot_id: member_ids, working_memory: true)
                 .distinct
                 .select_map(:node_id)

      HTM::Models::Node.where(id: node_ids).order(Sequel.desc(:created_at))
    end

    # Clears shared working memory for all group members.
    #
    # Updates database flags and notifies all members to clear their
    # in-memory caches.
    #
    # @return [Integer] Number of robot_node records updated
    #
    # @example
    #   cleared_count = group.clear_working_memory
    #   puts "Cleared #{cleared_count} working memory entries"
    #
    def clear_working_memory
      count = HTM::Models::RobotNode
              .where(robot_id: member_ids, working_memory: true)
              .update(working_memory: false)

      # Clear in-memory working memory for primary robot
      primary = @active_robots.values.first || @passive_robots.values.first
      return 0 unless primary

      primary.clear_working_memory

      # Notify all listeners (will clear other in-memory caches via callback)
      @channel.notify(:cleared, node_id: nil, robot_id: primary.robot_id)

      count
    end

    # @!endgroup

    # @!group Synchronization

    # Synchronizes a specific robot to match the group's shared working memory.
    #
    # Copies working memory flags from other members to the specified robot,
    # ensuring it has access to all shared context.
    #
    # @param robot_name [String] Name of the robot to synchronize
    # @return [Integer] Number of nodes synchronized
    # @raise [ArgumentError] if robot_name is not a member
    #
    # @example
    #   synced = group.sync_robot('new-agent')
    #   puts "Synchronized #{synced} nodes"
    #
    def sync_robot(robot_name)
      htm = all_robots[robot_name]
      raise ArgumentError, "#{robot_name} is not a member" unless htm

      # Get all node_ids currently in any member's working memory
      shared_node_ids = HTM::Models::RobotNode
                        .where(robot_id: member_ids, working_memory: true)
                        .exclude(robot_id: htm.robot_id)
                        .distinct
                        .select_map(:node_id)

      synced = 0
      shared_node_ids.each do |node_id|
        # Create or update robot_node with working_memory=true
        robot_node = HTM::Models::RobotNode.first(
          robot_id: htm.robot_id,
          node_id: node_id
        )
        robot_node ||= HTM::Models::RobotNode.new(
          robot_id: htm.robot_id,
          node_id: node_id
        )
        next if robot_node.working_memory

        robot_node.working_memory = true
        robot_node.save
        synced += 1
      end

      synced
    end

    # Synchronizes all members to a consistent state.
    #
    # Ensures every member has access to all shared working memory nodes.
    #
    # @return [Hash] Sync results with :synced_nodes and :members_updated counts
    #
    # @example
    #   result = group.sync_all
    #   puts "Synced #{result[:synced_nodes]} nodes to #{result[:members_updated]} members"
    #
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

    # Checks if all members have identical working memory.
    #
    # Compares the set of working memory node IDs across all members.
    #
    # @return [Boolean] true if all members have the same working memory nodes
    #
    # @example
    #   if group.in_sync?
    #     puts "All robots synchronized"
    #   else
    #     group.sync_all
    #   end
    #
    def in_sync?
      return true if member_ids.length <= 1

      # Get working memory node_ids for each robot
      working_memories = member_ids.map do |robot_id|
        HTM::Models::RobotNode
          .where(robot_id: robot_id, working_memory: true)
          .select_map(:node_id)
          .sort
      end

      # All should be identical
      working_memories.uniq.length == 1
    end

    # @!endgroup

    # @!group Failover

    # Transfers working memory from one robot to another.
    #
    # Copies all working memory node references from the source robot to the
    # target robot, optionally clearing the source.
    #
    # @param from_robot [String] Name of the source robot
    # @param to_robot [String] Name of the destination robot
    # @param clear_source [Boolean] Whether to clear source's working memory after transfer
    # @return [Integer] Number of nodes transferred
    # @raise [ArgumentError] if either robot is not a member
    #
    # @example Transfer with source clearing
    #   transferred = group.transfer_working_memory('failing-agent', 'backup-agent')
    #
    # @example Transfer without clearing source
    #   transferred = group.transfer_working_memory(
    #     'agent-1', 'agent-2',
    #     clear_source: false
    #   )
    #
    def transfer_working_memory(from_robot, to_robot, clear_source: true)
      from_htm = all_robots[from_robot]
      to_htm = all_robots[to_robot]

      raise ArgumentError, "#{from_robot} is not a member" unless from_htm
      raise ArgumentError, "#{to_robot} is not a member" unless to_htm

      # Get source's working memory nodes
      source_node_ids = HTM::Models::RobotNode
                        .where(robot_id: from_htm.robot_id, working_memory: true)
                        .select_map(:node_id)

      transferred = 0
      source_node_ids.each do |node_id|
        robot_node = HTM::Models::RobotNode.first(
          robot_id: to_htm.robot_id,
          node_id: node_id
        )
        robot_node ||= HTM::Models::RobotNode.new(
          robot_id: to_htm.robot_id,
          node_id: node_id
        )
        robot_node.working_memory = true
        robot_node.save
        transferred += 1
      end

      # Clear source's working memory if requested
      if clear_source
        HTM::Models::RobotNode
          .where(robot_id: from_htm.robot_id, working_memory: true)
          .update(working_memory: false)
      end

      transferred
    end

    # Performs automatic failover to the first passive robot.
    #
    # Promotes the first passive robot to active status. The promoted robot
    # already has synchronized working memory and can immediately handle requests.
    #
    # @return [String] Name of the promoted robot
    # @raise [RuntimeError] if no passive robots are available
    #
    # @example
    #   promoted = group.failover!
    #   puts "#{promoted} is now active"
    #
    def failover!
      raise 'No passive robots available for failover' if @passive_robots.empty?

      # Get first passive robot
      standby_name = @passive_robots.keys.first

      # Promote it
      promote(standby_name)

      puts "  ⚡ Failover: #{standby_name} promoted to active"
      standby_name
    end

    # @!endgroup

    # @!group Status & Health

    # Returns comprehensive status information about the group.
    #
    # @return [Hash] Status hash with the following keys:
    # @option return [String] :name Group name
    # @option return [Array<String>] :active Names of active robots
    # @option return [Array<String>] :passive Names of passive robots
    # @option return [Integer] :total_members Total number of members
    # @option return [Integer] :working_memory_nodes Number of nodes in shared memory
    # @option return [Integer] :working_memory_tokens Total tokens in shared memory
    # @option return [Integer] :max_tokens Maximum token budget
    # @option return [Float] :token_utilization Ratio of used to max tokens (0.0-1.0)
    # @option return [Boolean] :in_sync Whether all members are synchronized
    #
    # @example
    #   status = group.status
    #   puts "Group: #{status[:name]}"
    #   puts "Active: #{status[:active].join(', ')}"
    #   puts "Utilization: #{(status[:token_utilization] * 100).round(1)}%"
    #
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

    # Returns statistics about real-time synchronization.
    #
    # @return [Hash] Stats hash with :nodes_synced and :evictions_synced counts
    #
    # @example
    #   stats = group.sync_stats
    #   puts "Nodes synced: #{stats[:nodes_synced]}"
    #   puts "Evictions synced: #{stats[:evictions_synced]}"
    #
    def sync_stats
      @mutex.synchronize { @sync_stats.dup }
    end

    # @!endgroup

    private

    def all_robots
      @active_robots.merge(@passive_robots)
    end

    def setup_sync_listener
      @channel.on_change do |event, node_id, origin_robot_id|
        handle_sync_notification(event, node_id, origin_robot_id)
      end
    end

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

    def sync_node_to_in_memory_caches(node_id, origin_robot_id)
      node = HTM::Models::Node.first(id: node_id)
      return unless node

      all_robots.each do |_name, htm|
        next if htm.robot_id == origin_robot_id

        htm.working_memory.add_from_sync(
          id: node.id,
          content: node.content,
          token_count: node.token_count || 0,
          created_at: node.created_at
        )
      end
    end

    def evict_from_in_memory_caches(node_id, origin_robot_id)
      all_robots.each do |_name, htm|
        next if htm.robot_id == origin_robot_id

        htm.working_memory.remove_from_sync(node_id)
      end
    end

    def clear_all_in_memory_caches(origin_robot_id)
      all_robots.each do |_name, htm|
        next if htm.robot_id == origin_robot_id

        htm.working_memory.clear_from_sync
      end
    end

    def sync_node_to_members(node_id, exclude: nil)
      member_ids.each do |robot_id|
        next if robot_id == exclude

        robot_node = HTM::Models::RobotNode.first(
          robot_id: robot_id,
          node_id: node_id
        )
        robot_node ||= HTM::Models::RobotNode.new(
          robot_id: robot_id,
          node_id: node_id
        )
        robot_node.working_memory = true
        robot_node.save
      end
    end
  end
end
