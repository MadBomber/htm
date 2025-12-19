# frozen_string_literal: true

require 'fast_mcp'

class HTM
  module MCP
    # Session state for robot groups
    module GroupSession
      class << self
        def groups
          @groups ||= {}
        end

        def get_group(name)
          groups[name]
        end

        def set_group(name, group)
          groups[name] = group
        end

        def remove_group(name)
          group = groups.delete(name)
          group&.shutdown
        end

        def group_names
          groups.keys
        end
      end
    end

    # Tool: Create a new robot group
    class CreateGroupTool < FastMcp::Tool
      description "Create a new robot group for coordinating multiple robots with shared working memory"

      arguments do
        required(:name).filled(:string).description("Unique name for the robot group")
        optional(:max_tokens).filled(:integer).description("Maximum token budget for shared working memory (default: 4000)")
        optional(:join_as).filled(:string).description("Role to join as: 'active' or 'passive' (default: 'active')")
      end

      def call(name:, max_tokens: 4000, join_as: 'active')
        Session.logger&.info "CreateGroupTool called: name=#{name.inspect}, max_tokens=#{max_tokens}"

        if GroupSession.get_group(name)
          return { success: false, error: "Group '#{name}' already exists in this session" }.to_json
        end

        # Get current robot name
        robot_name = Session.robot_name

        # Create the group with current robot as initial member
        active  = join_as == 'active' ? [robot_name] : []
        passive = join_as == 'passive' ? [robot_name] : []

        group = HTM::RobotGroup.new(
          name: name,
          active: active,
          passive: passive,
          max_tokens: max_tokens
        )

        GroupSession.set_group(name, group)

        Session.logger&.info "Group created: #{name}, robot=#{robot_name} joined as #{join_as}"

        {
          success:      true,
          group_name:   name,
          max_tokens:   max_tokens,
          robot_name:   robot_name,
          role:         join_as,
          message:      "Group '#{name}' created. Robot '#{robot_name}' joined as #{join_as}."
        }.to_json
      rescue StandardError => e
        Session.logger&.error "CreateGroupTool error: #{e.message}"
        { success: false, error: e.message }.to_json
      end
    end

    # Tool: List all robot groups
    class ListGroupsTool < FastMcp::Tool
      description "List all robot groups in this session with their status"

      arguments do
      end

      def call
        Session.logger&.info "ListGroupsTool called"

        groups = GroupSession.group_names.map do |name|
          group = GroupSession.get_group(name)
          status = group.status
          {
            name:            name,
            active_robots:   status[:active],
            passive_robots:  status[:passive],
            total_members:   status[:total_members],
            in_sync:         status[:in_sync],
            token_utilization: status[:token_utilization]
          }
        end

        Session.logger&.info "ListGroupsTool complete: #{groups.length} groups"

        {
          success: true,
          count:   groups.length,
          groups:  groups
        }.to_json
      end
    end

    # Tool: Get detailed group status
    class GetGroupStatusTool < FastMcp::Tool
      description "Get detailed status of a specific robot group"

      arguments do
        required(:name).filled(:string).description("Name of the robot group")
      end

      def call(name:)
        Session.logger&.info "GetGroupStatusTool called: name=#{name.inspect}"

        group = GroupSession.get_group(name)
        unless group
          return { success: false, error: "Group '#{name}' not found in this session" }.to_json
        end

        status = group.status
        sync_stats = group.sync_stats

        Session.logger&.info "GetGroupStatusTool complete: #{name}"

        {
          success:    true,
          group_name: name,
          status:     status,
          sync_stats: sync_stats
        }.to_json
      end
    end

    # Tool: Join current robot to an existing group
    class JoinGroupTool < FastMcp::Tool
      description "Join the current robot to an existing robot group"

      arguments do
        required(:name).filled(:string).description("Name of the robot group to join")
        optional(:role).filled(:string).description("Role to join as: 'active' or 'passive' (default: 'active')")
      end

      def call(name:, role: 'active')
        Session.logger&.info "JoinGroupTool called: name=#{name.inspect}, role=#{role}"

        group = GroupSession.get_group(name)
        unless group
          return { success: false, error: "Group '#{name}' not found in this session" }.to_json
        end

        robot_name = Session.robot_name

        if group.member?(robot_name)
          return { success: false, error: "Robot '#{robot_name}' is already a member of group '#{name}'" }.to_json
        end

        robot_id = if role == 'passive'
                     group.add_passive(robot_name)
                   else
                     group.add_active(robot_name)
                   end

        Session.logger&.info "Robot #{robot_name} joined group #{name} as #{role}"

        {
          success:    true,
          group_name: name,
          robot_name: robot_name,
          robot_id:   robot_id,
          role:       role,
          message:    "Robot '#{robot_name}' joined group '#{name}' as #{role}"
        }.to_json
      rescue ArgumentError => e
        { success: false, error: e.message }.to_json
      end
    end

    # Tool: Leave a robot group
    class LeaveGroupTool < FastMcp::Tool
      description "Remove the current robot from a robot group"

      arguments do
        required(:name).filled(:string).description("Name of the robot group to leave")
      end

      def call(name:)
        Session.logger&.info "LeaveGroupTool called: name=#{name.inspect}"

        group = GroupSession.get_group(name)
        unless group
          return { success: false, error: "Group '#{name}' not found in this session" }.to_json
        end

        robot_name = Session.robot_name

        unless group.member?(robot_name)
          return { success: false, error: "Robot '#{robot_name}' is not a member of group '#{name}'" }.to_json
        end

        group.remove(robot_name)

        Session.logger&.info "Robot #{robot_name} left group #{name}"

        {
          success:    true,
          group_name: name,
          robot_name: robot_name,
          message:    "Robot '#{robot_name}' left group '#{name}'"
        }.to_json
      end
    end

    # Tool: Remember via group (syncs to all members)
    class GroupRememberTool < FastMcp::Tool
      description "Store information in a robot group's shared working memory (syncs to all members)"

      arguments do
        required(:group_name).filled(:string).description("Name of the robot group")
        required(:content).filled(:string).description("The content to remember")
        optional(:tags).array(:string).description("Optional tags for categorization")
        optional(:metadata).hash.description("Optional metadata key-value pairs")
      end

      def call(group_name:, content:, tags: [], metadata: {})
        Session.logger&.info "GroupRememberTool called: group=#{group_name.inspect}, content=#{content[0..50].inspect}..."

        group = GroupSession.get_group(group_name)
        unless group
          return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
        end

        robot_name = Session.robot_name
        node_id = group.remember(content, originator: robot_name, tags: tags, metadata: metadata)

        Session.logger&.info "Group memory stored: node_id=#{node_id}, group=#{group_name}"

        {
          success:    true,
          node_id:    node_id,
          group_name: group_name,
          originator: robot_name,
          message:    "Memory stored and synced to all group members"
        }.to_json
      rescue StandardError => e
        Session.logger&.error "GroupRememberTool error: #{e.message}"
        { success: false, error: e.message }.to_json
      end
    end

    # Tool: Recall from group's shared memory
    class GroupRecallTool < FastMcp::Tool
      description "Search and retrieve memories from a robot group's shared working memory"

      arguments do
        required(:group_name).filled(:string).description("Name of the robot group")
        required(:query).filled(:string).description("Search query")
        optional(:limit).filled(:integer).description("Maximum number of results (default: 10)")
        optional(:strategy).filled(:string).description("Search strategy: 'vector', 'fulltext', or 'hybrid' (default: 'hybrid')")
      end

      def call(group_name:, query:, limit: 10, strategy: 'hybrid')
        Session.logger&.info "GroupRecallTool called: group=#{group_name.inspect}, query=#{query.inspect}"

        group = GroupSession.get_group(group_name)
        unless group
          return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
        end

        memories = group.recall(query, limit: limit, strategy: strategy.to_sym)

        Session.logger&.info "GroupRecallTool complete: found #{memories.length} memories"

        {
          success:    true,
          group_name: group_name,
          query:      query,
          strategy:   strategy,
          count:      memories.length,
          results:    memories
        }.to_json
      rescue StandardError => e
        Session.logger&.error "GroupRecallTool error: #{e.message}"
        { success: false, error: e.message }.to_json
      end
    end

    # Tool: Promote a passive robot to active
    class PromoteRobotTool < FastMcp::Tool
      description "Promote a passive robot to active status in a group"

      arguments do
        required(:group_name).filled(:string).description("Name of the robot group")
        required(:robot_name).filled(:string).description("Name of the passive robot to promote")
      end

      def call(group_name:, robot_name:)
        Session.logger&.info "PromoteRobotTool called: group=#{group_name.inspect}, robot=#{robot_name.inspect}"

        group = GroupSession.get_group(group_name)
        unless group
          return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
        end

        group.promote(robot_name)

        Session.logger&.info "Robot #{robot_name} promoted to active in group #{group_name}"

        {
          success:    true,
          group_name: group_name,
          robot_name: robot_name,
          message:    "Robot '#{robot_name}' promoted to active"
        }.to_json
      rescue ArgumentError => e
        { success: false, error: e.message }.to_json
      end
    end

    # Tool: Trigger automatic failover
    class FailoverTool < FastMcp::Tool
      description "Trigger automatic failover - promotes first passive robot to active"

      arguments do
        required(:group_name).filled(:string).description("Name of the robot group")
      end

      def call(group_name:)
        Session.logger&.info "FailoverTool called: group=#{group_name.inspect}"

        group = GroupSession.get_group(group_name)
        unless group
          return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
        end

        promoted = group.failover!

        Session.logger&.info "Failover complete: #{promoted} promoted to active in group #{group_name}"

        {
          success:        true,
          group_name:     group_name,
          promoted_robot: promoted,
          message:        "Failover complete. Robot '#{promoted}' is now active."
        }.to_json
      rescue RuntimeError => e
        { success: false, error: e.message }.to_json
      end
    end

    # Tool: Force sync all group members
    class SyncGroupTool < FastMcp::Tool
      description "Force synchronization of all group members' working memory"

      arguments do
        required(:group_name).filled(:string).description("Name of the robot group")
      end

      def call(group_name:)
        Session.logger&.info "SyncGroupTool called: group=#{group_name.inspect}"

        group = GroupSession.get_group(group_name)
        unless group
          return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
        end

        result = group.sync_all

        Session.logger&.info "SyncGroupTool complete: synced #{result[:synced_nodes]} nodes to #{result[:members_updated]} members"

        {
          success:         true,
          group_name:      group_name,
          synced_nodes:    result[:synced_nodes],
          members_updated: result[:members_updated],
          in_sync:         group.in_sync?,
          message:         "Synced #{result[:synced_nodes]} nodes to #{result[:members_updated]} members"
        }.to_json
      end
    end

    # Tool: Get group's shared working memory contents
    class GetGroupWorkingMemoryTool < FastMcp::Tool
      description "Get all nodes in a group's shared working memory"

      arguments do
        required(:group_name).filled(:string).description("Name of the robot group")
      end

      def call(group_name:)
        Session.logger&.info "GetGroupWorkingMemoryTool called: group=#{group_name.inspect}"

        group = GroupSession.get_group(group_name)
        unless group
          return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
        end

        contents = group.working_memory_contents.map do |node|
          {
            id:         node.id,
            content:    node.content,
            tags:       node.tags.map(&:name),
            created_at: node.created_at.iso8601
          }
        end

        status = group.status

        Session.logger&.info "GetGroupWorkingMemoryTool complete: #{contents.length} nodes"

        {
          success:           true,
          group_name:        group_name,
          count:             contents.length,
          token_count:       status[:working_memory_tokens],
          token_utilization: status[:token_utilization],
          contents:          contents
        }.to_json
      end
    end

    # Tool: Shutdown a robot group
    class ShutdownGroupTool < FastMcp::Tool
      description "Shutdown a robot group and release its resources"

      arguments do
        required(:name).filled(:string).description("Name of the robot group to shutdown")
      end

      def call(name:)
        Session.logger&.info "ShutdownGroupTool called: name=#{name.inspect}"

        group = GroupSession.get_group(name)
        unless group
          return { success: false, error: "Group '#{name}' not found in this session" }.to_json
        end

        GroupSession.remove_group(name)

        Session.logger&.info "Group #{name} shutdown complete"

        {
          success:    true,
          group_name: name,
          message:    "Group '#{name}' has been shutdown"
        }.to_json
      end
    end

    # All group tools for registration
    GROUP_TOOLS = [
      CreateGroupTool,
      ListGroupsTool,
      GetGroupStatusTool,
      JoinGroupTool,
      LeaveGroupTool,
      GroupRememberTool,
      GroupRecallTool,
      GetGroupWorkingMemoryTool,
      PromoteRobotTool,
      FailoverTool,
      SyncGroupTool,
      ShutdownGroupTool
    ].freeze
  end
end
