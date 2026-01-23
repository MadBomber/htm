# frozen_string_literal: true

require 'fast_mcp'

class HTM
  module MCP
    # Session state for the current robot
    # Each MCP client spawns its own server process, so this is naturally isolated
    module Session
      DEFAULT_ROBOT_NAME = "mcp_default"

      class << self
        attr_accessor :logger

        def htm_instance
          @htm_instance ||= HTM.new(robot_name: DEFAULT_ROBOT_NAME)
        end

        def set_robot(name)
          @robot_name   = name
          @htm_instance = HTM.new(robot_name: name)
          logger&.info "Robot set: #{name} (id=#{@htm_instance.robot_id})"
          @htm_instance
        end

        def robot_name
          @robot_name || DEFAULT_ROBOT_NAME
        end

        def robot_initialized?
          @robot_name != nil
        end
      end
    end

    # Tool: Set the robot identity for this session
    class SetRobotTool < FastMcp::Tool
      description "Set the robot identity for this session. Call this first to establish your robot name."

      arguments do
        required(:name).filled(:string).description("The robot name (will be created if it doesn't exist)")
      end

      def call(name:)
        Session.logger&.info "SetRobotTool called: name=#{name.inspect}"

        htm   = Session.set_robot(name)
        robot = HTM::Models::Robot[htm.robot_id]

        {
          success:    true,
          robot_id:   htm.robot_id,
          robot_name: htm.robot_name,
          node_count: robot.node_count,
          message:    "Robot '#{name}' is now active for this session"
        }.to_json
      end
    end

    # Tool: Get current robot info
    class GetRobotTool < FastMcp::Tool
      description "Get information about the current robot for this session"

      arguments do
      end

      def call
        Session.logger&.info "GetRobotTool called"

        htm   = Session.htm_instance
        robot = HTM::Models::Robot[htm.robot_id]

        {
          success:        true,
          robot_id:       htm.robot_id,
          robot_name:     htm.robot_name,
          initialized:    Session.robot_initialized?,
          memory_summary: robot.memory_summary
        }.to_json
      end
    end

    # Tool: Get working memory contents for session restore
    class GetWorkingMemoryTool < FastMcp::Tool
      description "Get all working memory contents for the current robot. Use this to restore a previous session."

      arguments do
      end

      def call
        htm = Session.htm_instance
        robot = HTM::Models::Robot[htm.robot_id]
        Session.logger&.info "GetWorkingMemoryTool called for robot=#{htm.robot_name}"

        # Get all nodes in working memory with their metadata
        # Filter out any robot_nodes where the node has been deleted
        working_memory_nodes = robot.robot_nodes_dataset
                                    .in_working_memory
                                    .eager(node: :tags)
                                    .order(Sequel.desc(:last_remembered_at))
                                    .all
                                    .filter_map do |rn|
          node = rn.node
          next unless node  # Exclude if node is nil (was deleted)

          {
            id:                 node.id,
            content:            node.content,
            tags:               node.tags.map(&:name),
            remember_count:     rn.remember_count,
            last_remembered_at: rn.last_remembered_at&.iso8601,
            created_at:         node.created_at.iso8601
          }
        end

        Session.logger&.info "GetWorkingMemoryTool complete: #{working_memory_nodes.length} nodes in working memory"

        {
          success:        true,
          robot_id:       htm.robot_id,
          robot_name:     htm.robot_name,
          count:          working_memory_nodes.length,
          working_memory: working_memory_nodes
        }.to_json
      rescue StandardError => e
        Session.logger&.error "GetWorkingMemoryTool error: #{e.message}"
        { success: false, error: e.message, count: 0, working_memory: [] }.to_json
      end
    end

    # Tool: Remember information
    class RememberTool < FastMcp::Tool
      description "Store information in HTM long-term memory with optional tags"

      arguments do
        required(:content).filled(:string).description("The content to remember")
        optional(:tags).array(:string).description("Optional tags for categorization (e.g., ['database:postgresql', 'config'])")
        optional(:metadata).hash.description("Optional metadata key-value pairs")
      end

      def call(content:, tags: [], metadata: {})
        Session.logger&.info "RememberTool called: content=#{content[0..50].inspect}..."

        htm = Session.htm_instance
        node_id = htm.remember(content, tags: tags, metadata: metadata)
        node = HTM::Models::Node.eager(:tags).first!(id: node_id)

        Session.logger&.info "Memory stored: node_id=#{node_id}, robot=#{htm.robot_name}, tags=#{node.tags.map(&:name)}"

        {
          success:        true,
          node_id:        node_id,
          robot_id:       htm.robot_id,
          robot_name:     htm.robot_name,
          content:        node.content,
          tags:           node.tags.map(&:name),
          created_at:     node.created_at.iso8601
        }.to_json
      end
    end

    # Tool: Recall memories
    class RecallTool < FastMcp::Tool
      description "Search and retrieve memories from HTM using semantic, full-text, or hybrid search"

      arguments do
        required(:query).filled(:string).description("Search query - can be natural language or keywords")
        optional(:limit).filled(:integer).description("Maximum number of results (default: 10)")
        optional(:strategy).filled(:string).description("Search strategy: 'vector', 'fulltext', or 'hybrid' (default: 'hybrid')")
        optional(:timeframe).filled(:string).description("Filter by time: 'today', 'this week', 'this month', or ISO8601 date range")
      end

      def call(query:, limit: 10, strategy: 'hybrid', timeframe: nil)
        htm = Session.htm_instance
        Session.logger&.info "RecallTool called: query=#{query.inspect}, strategy=#{strategy}, limit=#{limit}, robot=#{htm.robot_name}"

        recall_opts = {
          limit: limit,
          strategy: strategy.to_sym,
          raw: true
        }

        # Parse timeframe if provided
        if timeframe
          recall_opts[:timeframe] = parse_timeframe(timeframe)
        end

        memories = htm.recall(query, **recall_opts)

        results = memories.map do |memory|
          node = HTM::Models::Node.eager(:tags).first(id: memory['id'])
          next unless node
          {
            id:         memory['id'],
            content:    memory['content'],
            tags:       node.tags.map(&:name),
            created_at: memory['created_at'],
            score:      memory['combined_score'] || memory['similarity']
          }
        end.compact

        Session.logger&.info "Recall complete: found #{results.length} memories"

        {
          success:    true,
          query:      query,
          strategy:   strategy,
          robot_name: htm.robot_name,
          count:      results.length,
          results:    results
        }.to_json
      end

      private

      def parse_timeframe(timeframe)
        now = Time.now
        case timeframe.downcase
        when 'today'
          # Beginning of today
          Time.new(now.year, now.month, now.day)..now
        when 'this week'
          # 7 days ago
          (now - 7 * 24 * 60 * 60)..now
        when 'this month'
          # 30 days ago
          (now - 30 * 24 * 60 * 60)..now
        else
          # Try to parse as ISO8601 range (start..end)
          if timeframe.include?('..')
            parts = timeframe.split('..')
            Time.parse(parts[0])..Time.parse(parts[1])
          else
            # Single date - from that date to now
            Time.parse(timeframe)..now
          end
        end
      rescue ArgumentError
        nil  # Invalid timeframe, skip filtering
      end
    end

    # Tool: Forget a memory
    class ForgetTool < FastMcp::Tool
      description "Soft-delete a memory from HTM (can be restored later)"

      arguments do
        required(:node_id).filled(:integer).description("The ID of the node to forget")
      end

      def call(node_id:)
        htm = Session.htm_instance
        Session.logger&.info "ForgetTool called: node_id=#{node_id}, robot=#{htm.robot_name}"

        htm.forget(node_id)

        Session.logger&.info "Memory soft-deleted: node_id=#{node_id}"

        {
          success:    true,
          node_id:    node_id,
          robot_name: htm.robot_name,
          message:    "Memory soft-deleted. Use restore to recover."
        }.to_json
      rescue HTM::NotFoundError, Sequel::NoMatchingRow
        Session.logger&.warn "ForgetTool failed: node #{node_id} not found"
        {
          success: false,
          error: "Node #{node_id} not found"
        }.to_json
      end
    end

    # Tool: Restore a forgotten memory
    class RestoreTool < FastMcp::Tool
      description "Restore a soft-deleted memory"

      arguments do
        required(:node_id).filled(:integer).description("The ID of the node to restore")
      end

      def call(node_id:)
        htm = Session.htm_instance
        Session.logger&.info "RestoreTool called: node_id=#{node_id}, robot=#{htm.robot_name}"

        htm.restore(node_id)

        Session.logger&.info "Memory restored: node_id=#{node_id}"

        {
          success:    true,
          node_id:    node_id,
          robot_name: htm.robot_name,
          message:    "Memory restored successfully"
        }.to_json
      rescue HTM::NotFoundError, Sequel::NoMatchingRow
        Session.logger&.warn "RestoreTool failed: node #{node_id} not found"
        {
          success: false,
          error: "Node #{node_id} not found"
        }.to_json
      end
    end

    # Tool: List tags
    class ListTagsTool < FastMcp::Tool
      description "List all tags in HTM, optionally filtered by prefix"

      arguments do
        optional(:prefix).filled(:string).description("Filter tags by prefix (e.g., 'database' returns 'database:postgresql', etc.)")
      end

      def call(prefix: nil)
        Session.logger&.info "ListTagsTool called: prefix=#{prefix.inspect}"

        tags_query = HTM::Models::Tag.order(:name)
        tags_query = tags_query.where(Sequel.like(:name, "#{prefix}%")) if prefix

        tags = tags_query.map do |tag|
          {
            name: tag.name,
            node_count: tag.nodes.count
          }
        end

        Session.logger&.info "ListTagsTool complete: found #{tags.length} tags"

        {
          success: true,
          prefix: prefix,
          count: tags.length,
          tags: tags
        }.to_json
      end
    end

    # Tool: Search tags with fuzzy matching
    class SearchTagsTool < FastMcp::Tool
      description "Search for tags using fuzzy matching (typo-tolerant). Use this when you're unsure of exact tag names."

      arguments do
        required(:query).filled(:string).description("Search query - can contain typos (e.g., 'postgrsql' finds 'database:postgresql')")
        optional(:limit).filled(:integer).description("Maximum number of results (default: 20)")
        optional(:min_similarity).filled(:float).description("Minimum similarity threshold 0.0-1.0 (default: 0.3, lower = more fuzzy)")
      end

      def call(query:, limit: 20, min_similarity: 0.3)
        Session.logger&.info "SearchTagsTool called: query=#{query.inspect}, limit=#{limit}, min_similarity=#{min_similarity}"

        htm = Session.htm_instance
        ltm = htm.instance_variable_get(:@long_term_memory)

        results = ltm.search_tags(query, limit: limit, min_similarity: min_similarity)

        # Enrich with node counts
        tags = results.map do |result|
          tag = HTM::Models::Tag.first(name: result[:name])
          {
            name: result[:name],
            similarity: result[:similarity].round(3),
            node_count: tag&.nodes&.count || 0
          }
        end

        Session.logger&.info "SearchTagsTool complete: found #{tags.length} tags"

        {
          success: true,
          query: query,
          min_similarity: min_similarity,
          count: tags.length,
          tags: tags
        }.to_json
      end
    end

    # Tool: Find nodes by topic with fuzzy option
    class FindByTopicTool < FastMcp::Tool
      description "Find memory nodes by topic/tag with optional fuzzy matching for typo tolerance"

      arguments do
        required(:topic).filled(:string).description("Topic or tag to search for (e.g., 'database:postgresql' or 'postgrsql' with fuzzy)")
        optional(:fuzzy).filled(:bool).description("Enable fuzzy matching for typo tolerance (default: false)")
        optional(:exact).filled(:bool).description("Require exact tag match (default: false, uses prefix matching)")
        optional(:limit).filled(:integer).description("Maximum number of results (default: 20)")
        optional(:min_similarity).filled(:float).description("Minimum similarity for fuzzy mode (default: 0.3)")
      end

      def call(topic:, fuzzy: false, exact: false, limit: 20, min_similarity: 0.3)
        Session.logger&.info "FindByTopicTool called: topic=#{topic.inspect}, fuzzy=#{fuzzy}, exact=#{exact}"

        htm = Session.htm_instance
        ltm = htm.instance_variable_get(:@long_term_memory)

        nodes = ltm.nodes_by_topic(
          topic,
          fuzzy: fuzzy,
          exact: exact,
          min_similarity: min_similarity,
          limit: limit
        )

        # Enrich with tags
        results = nodes.map do |node_attrs|
          node = HTM::Models::Node.eager(:tags).first(id: node_attrs['id'])
          next unless node

          {
            id: node.id,
            content: node.content[0..200],
            tags: node.tags.map(&:name),
            created_at: node.created_at.iso8601
          }
        end.compact

        Session.logger&.info "FindByTopicTool complete: found #{results.length} nodes"

        {
          success: true,
          topic: topic,
          fuzzy: fuzzy,
          exact: exact,
          count: results.length,
          results: results
        }.to_json
      end
    end

    # Tool: Get memory statistics
    class StatsTool < FastMcp::Tool
      description "Get statistics about HTM memory usage"

      arguments do
      end

      def call
        htm = Session.htm_instance
        robot = HTM::Models::Robot[htm.robot_id]
        Session.logger&.info "StatsTool called for robot=#{htm.robot_name}"

        # Note: Node uses set_dataset to exclude deleted, so .count returns active nodes
        total_nodes           = HTM::Models::Node.count
        deleted_nodes         = HTM::Models::Node.deleted.count
        nodes_with_embeddings = HTM::Models::Node.with_embeddings.count
        nodes_with_tags       = HTM::Models::Node
                                  .join(:node_tags, node_id: :id)
                                  .distinct
                                  .count
        total_tags            = HTM::Models::Tag.count
        total_robots          = HTM::Models::Robot.count

        Session.logger&.info "StatsTool complete: #{total_nodes} active nodes, #{total_tags} tags"

        {
          success:       true,
          current_robot: {
            name:           htm.robot_name,
            id:             htm.robot_id,
            memory_summary: robot.memory_summary
          },
          statistics: {
            nodes: {
              active:          total_nodes,
              deleted:         deleted_nodes,
              with_embeddings: nodes_with_embeddings,
              with_tags:       nodes_with_tags
            },
            tags: {
              total: total_tags
            },
            robots: {
              total: total_robots
            }
          }
        }.to_json
      rescue StandardError => e
        Session.logger&.error "StatsTool error: #{e.message}"
        { success: false, error: e.message }.to_json
      end
    end

    # All individual tools for registration
    TOOLS = [
      SetRobotTool,
      GetRobotTool,
      GetWorkingMemoryTool,
      RememberTool,
      RecallTool,
      ForgetTool,
      RestoreTool,
      ListTagsTool,
      SearchTagsTool,
      FindByTopicTool,
      StatsTool
    ].freeze
  end
end
