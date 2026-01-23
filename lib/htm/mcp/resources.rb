# frozen_string_literal: true

require 'fast_mcp'

class HTM
  module MCP
    # Resource: Robot Groups
    class RobotGroupsResource < FastMcp::Resource
      uri "htm://groups"
      resource_name "HTM Robot Groups"
      mime_type "application/json"

      def content
        groups = GroupSession.group_names.map do |name|
          group = GroupSession.get_group(name)
          group.status
        end

        {
          count:  groups.length,
          groups: groups
        }.to_json
      end
    end

    # Resource: Memory Statistics
    class MemoryStatsResource < FastMcp::Resource
      uri "htm://statistics"
      resource_name "HTM Memory Statistics"
      mime_type "application/json"

      def content
        htm = Session.htm_instance
        {
          total_nodes:        HTM::Models::Node.count,
          total_tags:         HTM::Models::Tag.count,
          total_robots:       HTM::Models::Robot.count,
          current_robot:      htm.robot_name,
          robot_id:           htm.robot_id,
          robot_initialized:  Session.robot_initialized?,
          embedding_provider: HTM.configuration.embedding_provider,
          embedding_model:    HTM.configuration.embedding_model
        }.to_json
      end
    end

    # Resource: Tag Hierarchy
    class TagHierarchyResource < FastMcp::Resource
      uri "htm://tags/hierarchy"
      resource_name "HTM Tag Hierarchy"
      mime_type "text/plain"

      def content
        HTM::Models::Tag.tree_string
      end
    end

    # Resource: Recent Memories
    class RecentMemoriesResource < FastMcp::Resource
      uri           "htm://memories/recent"
      resource_name "Recent HTM Memories"
      mime_type     "application/json"

      def content
        recent = HTM::Models::Node.eager(:tags)
                                  .order(Sequel.desc(:created_at))
                                  .limit(20)
                                  .all
                                  .map do |node|
          {
            id:         node.id,
            content:    node.content[0..200],
            tags:       node.tags.map(&:name),
            created_at: node.created_at.iso8601
          }
        end

        { recent_memories: recent }.to_json
      end
    end

    # All resources for registration
    RESOURCES = [
      MemoryStatsResource,
      TagHierarchyResource,
      RecentMemoriesResource,
      RobotGroupsResource
    ].freeze
  end
end
