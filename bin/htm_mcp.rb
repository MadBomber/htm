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
  rescue ActiveRecord::RecordNotFound
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
  rescue ActiveRecord::RecordNotFound
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

# Resource: Memory Statistics
class MemoryStatsResource < FastMcp::Resource
  uri "htm://statistics"
  resource_name "HTM Memory Statistics"
  mime_type "application/json"

  def content
    htm = MCPSession.htm_instance
    {
      total_nodes:        HTM::Models::Node.active.count,
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
    recent = HTM::Models::Node.active
                              .includes(:tags)
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

# Register tools
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

# Register resources
server.register_resource(MemoryStatsResource)
server.register_resource(TagHierarchyResource)
server.register_resource(RecentMemoriesResource)

# Start the server (STDIO transport by default)
server.start
