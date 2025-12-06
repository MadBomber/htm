#!/usr/bin/env ruby
# frozen_string_literal: true
# htm/bin/htm_mcp.rb

# MCP Server Example for HTM
#
# This example demonstrates using FastMCP to expose HTM's memory
# capabilities as an MCP (Model Context Protocol) server that can
# be used by AI assistants like Claude Desktop.
#
# Prerequisites:
# 1. Install fast-mcp gem: gem install fast-mcp
# 2. Set HTM_DBURL environment variable
# 3. Initialize database schema: rake db_setup
#
# Usage:
#   ruby examples/mcp_server.rb
#
# The server uses STDIO transport by default, making it compatible
# with Claude Desktop and other MCP clients.
#
# Claude Desktop configuration (~/.config/claude/claude_desktop_config.json):
#   {
#     "mcpServers": {
#       "htm-memory": {
#         "command": "ruby",
#         "args": ["/path/to/htm/examples/mcp_server.rb"],
#         "env": {
#           "HTM_DBURL": "postgresql://postgres@localhost:5432/htm_development"
#         }
#       }
#     }
#   }

require_relative '../lib/htm'

begin
  require 'fast_mcp'
rescue LoadError
  warn "Error: fast-mcp gem not found."
  warn "Install it with: gem install fast-mcp"
  exit 1
end

# Check environment
unless ENV['HTM_DBURL']
  warn "Error: HTM_DBURL not set."
  warn "  export HTM_DBURL=\"postgresql://postgres@localhost:5432/htm_development\""
  exit 1
end

# IMPORTANT: MCP uses STDIO for JSON-RPC communication.
# ALL logging must go to STDERR to avoid corrupting the protocol.
# Create a logger that writes to STDERR for MCP server diagnostics.
MCP_STDERR_LOG = Logger.new($stderr)
MCP_STDERR_LOG.level = Logger::INFO
MCP_STDERR_LOG.formatter = proc do |severity, datetime, _progname, msg|
  "[MCP #{severity}] #{datetime.strftime('%H:%M:%S')} #{msg}\n"
end

# Silent logger for RubyLLM/HTM internals (prevents STDOUT corruption)
mcp_logger = Logger.new(IO::NULL)

# Configure RubyLLM to not log to STDOUT (corrupts MCP protocol)
require 'ruby_llm'
RubyLLM.configure do |config|
  config.logger = mcp_logger
end

# Configure HTM
HTM.configure do |config|
  config.job_backend = :inline  # Synchronous for MCP responses
  config.logger = mcp_logger    # Silent logging for MCP
end

# Session state for the current robot
# Each MCP client spawns its own server process, so this is naturally isolated
module MCPSession
  DEFAULT_ROBOT_NAME = "mcp_default"

  class << self
    def htm_instance
      @htm_instance ||= HTM.new(robot_name: DEFAULT_ROBOT_NAME)
    end

    def set_robot(name)
      @robot_name   = name
      @htm_instance = HTM.new(robot_name: name)
      MCP_STDERR_LOG.info "Robot set: #{name} (id=#{@htm_instance.robot_id})"
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
    MCP_STDERR_LOG.info "SetRobotTool called: name=#{name.inspect}"

    htm   = MCPSession.set_robot(name)
    robot = HTM::Models::Robot.find(htm.robot_id)

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
    MCP_STDERR_LOG.info "GetRobotTool called"

    htm   = MCPSession.htm_instance
    robot = HTM::Models::Robot.find(htm.robot_id)

    {
      success:        true,
      robot_id:       htm.robot_id,
      robot_name:     htm.robot_name,
      initialized:    MCPSession.robot_initialized?,
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
    htm = MCPSession.htm_instance
    robot = HTM::Models::Robot.find(htm.robot_id)
    MCP_STDERR_LOG.info "GetWorkingMemoryTool called for robot=#{htm.robot_name}"

    # Get all nodes in working memory with their metadata
    # Filter out any robot_nodes where the node has been deleted (node uses default_scope)
    working_memory_nodes = robot.robot_nodes
                                .in_working_memory
                                .joins(:node)  # Inner join excludes deleted nodes
                                .includes(node: :tags)
                                .order(last_remembered_at: :desc)
                                .filter_map do |rn|
      next unless rn.node  # Extra safety check

      {
        id: rn.node.id,
        content:            rn.node.content,
        tags:               rn.node.tags.map(&:name),
        remember_count:     rn.remember_count,
        last_remembered_at: rn.last_remembered_at&.iso8601,
        created_at:         rn.node.created_at.iso8601
      }
    end

    MCP_STDERR_LOG.info "GetWorkingMemoryTool complete: #{working_memory_nodes.length} nodes in working memory"

    {
      success:        true,
      robot_id:       htm.robot_id,
      robot_name:     htm.robot_name,
      count:          working_memory_nodes.length,
      working_memory: working_memory_nodes
    }.to_json
  rescue StandardError => e
    MCP_STDERR_LOG.error "GetWorkingMemoryTool error: #{e.message}"
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
    MCP_STDERR_LOG.info "RememberTool called: content=#{content[0..50].inspect}..."

    htm = MCPSession.htm_instance
    node_id = htm.remember(content, tags: tags, metadata: metadata)
    node = HTM::Models::Node.includes(:tags).find(node_id)

    MCP_STDERR_LOG.info "Memory stored: node_id=#{node_id}, robot=#{htm.robot_name}, tags=#{node.tags.map(&:name)}"

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
    htm = MCPSession.htm_instance
    MCP_STDERR_LOG.info "RecallTool called: query=#{query.inspect}, strategy=#{strategy}, limit=#{limit}, robot=#{htm.robot_name}"

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
      node = HTM::Models::Node.includes(:tags).find(memory['id'])
      {
        id:         memory['id'],
        content:    memory['content'],
        tags:       node.tags.map(&:name),
        created_at: memory['created_at'],
        score:      memory['combined_score'] || memory['similarity']
      }
    end

    MCP_STDERR_LOG.info "Recall complete: found #{results.length} memories"

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
    case timeframe.downcase
    when 'today'
      Time.now.beginning_of_day..Time.now
    when 'this week'
      1.week.ago..Time.now
    when 'this month'
      1.month.ago..Time.now
    else
      # Try to parse as ISO8601 range (start..end)
      if timeframe.include?('..')
        parts = timeframe.split('..')
        Time.parse(parts[0])..Time.parse(parts[1])
      else
        # Single date - from that date to now
        Time.parse(timeframe)..Time.now
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
    htm = MCPSession.htm_instance
    MCP_STDERR_LOG.info "ForgetTool called: node_id=#{node_id}, robot=#{htm.robot_name}"

    htm.forget(node_id)

    MCP_STDERR_LOG.info "Memory soft-deleted: node_id=#{node_id}"

    {
      success:    true,
      node_id:    node_id,
      robot_name: htm.robot_name,
      message:    "Memory soft-deleted. Use restore to recover."
    }.to_json
  rescue HTM::NotFoundError, ActiveRecord::RecordNotFound
    MCP_STDERR_LOG.warn "ForgetTool failed: node #{node_id} not found"
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
    htm = MCPSession.htm_instance
    MCP_STDERR_LOG.info "RestoreTool called: node_id=#{node_id}, robot=#{htm.robot_name}"

    htm.restore(node_id)

    MCP_STDERR_LOG.info "Memory restored: node_id=#{node_id}"

    {
      success:    true,
      node_id:    node_id,
      robot_name: htm.robot_name,
      message:    "Memory restored successfully"
    }.to_json
  rescue HTM::NotFoundError, ActiveRecord::RecordNotFound
    MCP_STDERR_LOG.warn "RestoreTool failed: node #{node_id} not found"
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
    MCP_STDERR_LOG.info "ListTagsTool called: prefix=#{prefix.inspect}"

    tags_query = HTM::Models::Tag.order(:name)
    tags_query = tags_query.where("name LIKE ?", "#{prefix}%") if prefix

    tags = tags_query.map do |tag|
      {
        name: tag.name,
        node_count: tag.nodes.count
      }
    end

    MCP_STDERR_LOG.info "ListTagsTool complete: found #{tags.length} tags"

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
    MCP_STDERR_LOG.info "SearchTagsTool called: query=#{query.inspect}, limit=#{limit}, min_similarity=#{min_similarity}"

    htm = MCPSession.htm_instance
    ltm = htm.instance_variable_get(:@long_term_memory)

    results = ltm.search_tags(query, limit: limit, min_similarity: min_similarity)

    # Enrich with node counts
    tags = results.map do |result|
      tag = HTM::Models::Tag.find_by(name: result[:name])
      {
        name: result[:name],
        similarity: result[:similarity].round(3),
        node_count: tag&.nodes&.count || 0
      }
    end

    MCP_STDERR_LOG.info "SearchTagsTool complete: found #{tags.length} tags"

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
    MCP_STDERR_LOG.info "FindByTopicTool called: topic=#{topic.inspect}, fuzzy=#{fuzzy}, exact=#{exact}"

    htm = MCPSession.htm_instance
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
      node = HTM::Models::Node.includes(:tags).find_by(id: node_attrs['id'])
      next unless node

      {
        id: node.id,
        content: node.content[0..200],
        tags: node.tags.map(&:name),
        created_at: node.created_at.iso8601
      }
    end.compact

    MCP_STDERR_LOG.info "FindByTopicTool complete: found #{results.length} nodes"

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
    htm = MCPSession.htm_instance
    robot = HTM::Models::Robot.find(htm.robot_id)
    MCP_STDERR_LOG.info "StatsTool called for robot=#{htm.robot_name}"

    # Note: Node uses default_scope to exclude deleted, so .count returns active nodes
    total_nodes           = HTM::Models::Node.count
    deleted_nodes         = HTM::Models::Node.deleted.count
    nodes_with_embeddings = HTM::Models::Node.with_embeddings.count
    nodes_with_tags       = HTM::Models::Node.joins(:tags).distinct.count
    total_tags            = HTM::Models::Tag.count
    total_robots          = HTM::Models::Robot.count

    MCP_STDERR_LOG.info "StatsTool complete: #{total_nodes} active nodes, #{total_tags} tags"

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
    MCP_STDERR_LOG.error "StatsTool error: #{e.message}"
    { success: false, error: e.message }.to_json
  end
end

# ============================================================
# Robot Group Tools
# ============================================================

# Session state for robot groups (similar to MCPSession for robots)
module MCPGroupSession
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
    MCP_STDERR_LOG.info "CreateGroupTool called: name=#{name.inspect}, max_tokens=#{max_tokens}"

    if MCPGroupSession.get_group(name)
      return { success: false, error: "Group '#{name}' already exists in this session" }.to_json
    end

    # Get current robot name
    robot_name = MCPSession.robot_name

    # Create the group with current robot as initial member
    active  = join_as == 'active' ? [robot_name] : []
    passive = join_as == 'passive' ? [robot_name] : []

    group = HTM::RobotGroup.new(
      name: name,
      active: active,
      passive: passive,
      max_tokens: max_tokens
    )

    MCPGroupSession.set_group(name, group)

    MCP_STDERR_LOG.info "Group created: #{name}, robot=#{robot_name} joined as #{join_as}"

    {
      success:      true,
      group_name:   name,
      max_tokens:   max_tokens,
      robot_name:   robot_name,
      role:         join_as,
      message:      "Group '#{name}' created. Robot '#{robot_name}' joined as #{join_as}."
    }.to_json
  rescue StandardError => e
    MCP_STDERR_LOG.error "CreateGroupTool error: #{e.message}"
    { success: false, error: e.message }.to_json
  end
end

# Tool: List all robot groups
class ListGroupsTool < FastMcp::Tool
  description "List all robot groups in this session with their status"

  arguments do
  end

  def call
    MCP_STDERR_LOG.info "ListGroupsTool called"

    groups = MCPGroupSession.group_names.map do |name|
      group = MCPGroupSession.get_group(name)
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

    MCP_STDERR_LOG.info "ListGroupsTool complete: #{groups.length} groups"

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
    MCP_STDERR_LOG.info "GetGroupStatusTool called: name=#{name.inspect}"

    group = MCPGroupSession.get_group(name)
    unless group
      return { success: false, error: "Group '#{name}' not found in this session" }.to_json
    end

    status = group.status
    sync_stats = group.sync_stats

    MCP_STDERR_LOG.info "GetGroupStatusTool complete: #{name}"

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
    MCP_STDERR_LOG.info "JoinGroupTool called: name=#{name.inspect}, role=#{role}"

    group = MCPGroupSession.get_group(name)
    unless group
      return { success: false, error: "Group '#{name}' not found in this session" }.to_json
    end

    robot_name = MCPSession.robot_name

    if group.member?(robot_name)
      return { success: false, error: "Robot '#{robot_name}' is already a member of group '#{name}'" }.to_json
    end

    robot_id = if role == 'passive'
                 group.add_passive(robot_name)
               else
                 group.add_active(robot_name)
               end

    MCP_STDERR_LOG.info "Robot #{robot_name} joined group #{name} as #{role}"

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
    MCP_STDERR_LOG.info "LeaveGroupTool called: name=#{name.inspect}"

    group = MCPGroupSession.get_group(name)
    unless group
      return { success: false, error: "Group '#{name}' not found in this session" }.to_json
    end

    robot_name = MCPSession.robot_name

    unless group.member?(robot_name)
      return { success: false, error: "Robot '#{robot_name}' is not a member of group '#{name}'" }.to_json
    end

    group.remove(robot_name)

    MCP_STDERR_LOG.info "Robot #{robot_name} left group #{name}"

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
    MCP_STDERR_LOG.info "GroupRememberTool called: group=#{group_name.inspect}, content=#{content[0..50].inspect}..."

    group = MCPGroupSession.get_group(group_name)
    unless group
      return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
    end

    robot_name = MCPSession.robot_name
    node_id = group.remember(content, originator: robot_name, tags: tags, metadata: metadata)

    MCP_STDERR_LOG.info "Group memory stored: node_id=#{node_id}, group=#{group_name}"

    {
      success:    true,
      node_id:    node_id,
      group_name: group_name,
      originator: robot_name,
      message:    "Memory stored and synced to all group members"
    }.to_json
  rescue StandardError => e
    MCP_STDERR_LOG.error "GroupRememberTool error: #{e.message}"
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
    MCP_STDERR_LOG.info "GroupRecallTool called: group=#{group_name.inspect}, query=#{query.inspect}"

    group = MCPGroupSession.get_group(group_name)
    unless group
      return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
    end

    memories = group.recall(query, limit: limit, strategy: strategy.to_sym)

    MCP_STDERR_LOG.info "GroupRecallTool complete: found #{memories.length} memories"

    {
      success:    true,
      group_name: group_name,
      query:      query,
      strategy:   strategy,
      count:      memories.length,
      results:    memories
    }.to_json
  rescue StandardError => e
    MCP_STDERR_LOG.error "GroupRecallTool error: #{e.message}"
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
    MCP_STDERR_LOG.info "PromoteRobotTool called: group=#{group_name.inspect}, robot=#{robot_name.inspect}"

    group = MCPGroupSession.get_group(group_name)
    unless group
      return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
    end

    group.promote(robot_name)

    MCP_STDERR_LOG.info "Robot #{robot_name} promoted to active in group #{group_name}"

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
    MCP_STDERR_LOG.info "FailoverTool called: group=#{group_name.inspect}"

    group = MCPGroupSession.get_group(group_name)
    unless group
      return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
    end

    promoted = group.failover!

    MCP_STDERR_LOG.info "Failover complete: #{promoted} promoted to active in group #{group_name}"

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
    MCP_STDERR_LOG.info "SyncGroupTool called: group=#{group_name.inspect}"

    group = MCPGroupSession.get_group(group_name)
    unless group
      return { success: false, error: "Group '#{group_name}' not found in this session" }.to_json
    end

    result = group.sync_all

    MCP_STDERR_LOG.info "SyncGroupTool complete: synced #{result[:synced_nodes]} nodes to #{result[:members_updated]} members"

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
    MCP_STDERR_LOG.info "GetGroupWorkingMemoryTool called: group=#{group_name.inspect}"

    group = MCPGroupSession.get_group(group_name)
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

    MCP_STDERR_LOG.info "GetGroupWorkingMemoryTool complete: #{contents.length} nodes"

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
    MCP_STDERR_LOG.info "ShutdownGroupTool called: name=#{name.inspect}"

    group = MCPGroupSession.get_group(name)
    unless group
      return { success: false, error: "Group '#{name}' not found in this session" }.to_json
    end

    MCPGroupSession.remove_group(name)

    MCP_STDERR_LOG.info "Group #{name} shutdown complete"

    {
      success:    true,
      group_name: name,
      message:    "Group '#{name}' has been shutdown"
    }.to_json
  end
end

# Resource: Robot Groups
class RobotGroupsResource < FastMcp::Resource
  uri "htm://groups"
  resource_name "HTM Robot Groups"
  mime_type "application/json"

  def content
    groups = MCPGroupSession.group_names.map do |name|
      group = MCPGroupSession.get_group(name)
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
    htm = MCPSession.htm_instance
    {
      total_nodes:        HTM::Models::Node.count,
      total_tags:         HTM::Models::Tag.count,
      total_robots:       HTM::Models::Robot.count,
      current_robot:      htm.robot_name,
      robot_id:           htm.robot_id,
      robot_initialized:  MCPSession.robot_initialized?,
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
    HTM::Models::Tag.all.tree_string
  end
end

# Resource: Recent Memories
class RecentMemoriesResource < FastMcp::Resource
  uri           "htm://memories/recent"
  resource_name "Recent HTM Memories"
  mime_type     "application/json"

  def content
    recent = HTM::Models::Node.includes(:tags)
                              .order(created_at: :desc)
                              .limit(20)
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

# Create and configure the MCP server
server = FastMcp::Server.new(
  name:    'htm-memory-server',
  version: HTM::VERSION
)

# Register tools - Robot/Memory Management
server.register_tool(SetRobotTool)    # Call first to set robot identity
server.register_tool(GetRobotTool)    # Get current robot info
server.register_tool(GetWorkingMemoryTool)  # Get working memory for session restore
server.register_tool(RememberTool)
server.register_tool(RecallTool)
server.register_tool(ForgetTool)
server.register_tool(RestoreTool)
server.register_tool(ListTagsTool)
server.register_tool(SearchTagsTool)   # Fuzzy tag search with typo tolerance
server.register_tool(FindByTopicTool)  # Find nodes by topic with fuzzy option
server.register_tool(StatsTool)

# Register tools - Robot Groups (HA/Collaboration)
server.register_tool(CreateGroupTool)        # Create a robot group
server.register_tool(ListGroupsTool)         # List all groups
server.register_tool(GetGroupStatusTool)     # Get detailed group status
server.register_tool(JoinGroupTool)          # Join current robot to group
server.register_tool(LeaveGroupTool)         # Leave a group
server.register_tool(GroupRememberTool)      # Remember via group (syncs to all)
server.register_tool(GroupRecallTool)        # Recall from group's shared memory
server.register_tool(GetGroupWorkingMemoryTool)  # Get group's working memory
server.register_tool(PromoteRobotTool)       # Promote passive to active
server.register_tool(FailoverTool)           # Trigger automatic failover
server.register_tool(SyncGroupTool)          # Force sync all members
server.register_tool(ShutdownGroupTool)      # Shutdown a group

# Register resources
server.register_resource(MemoryStatsResource)
server.register_resource(TagHierarchyResource)
server.register_resource(RecentMemoriesResource)
server.register_resource(RobotGroupsResource)  # Robot groups status

# Start the server (STDIO transport by default)
server.start
