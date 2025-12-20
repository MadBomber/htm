# frozen_string_literal: true

# HTM Interactive Development Console
# Usage: HTM_DBURL="postgresql://user@localhost:5432/htm_development" irb

require_relative 'lib/htm'
require 'debug_me'

puts "=" * 60
puts "HTM Interactive Console"
puts "=" * 60

# Database Connection
begin
  HTM::ActiveRecordConfig.establish_connection! unless HTM::ActiveRecordConfig.connected?
  db_name = HTM::Database.default_config[:dbname] rescue 'unknown'
  puts "✓ Database connected: #{db_name}"
rescue => e
  puts "✗ Database connection failed: #{e.message}"
end

# Configure HTM with sensible defaults for interactive use
HTM.configure do |config|
  config.job.backend = :inline
  config.embedding.provider = :ollama
  config.embedding.model = 'nomic-embed-text:latest'
  config.embedding.dimensions = 768
  config.tag.provider = :ollama
  config.tag.model = 'gemma3:latest'
  config.reset_to_defaults
end
puts "✓ HTM configured (inline jobs, Ollama provider)"

# Model shortcuts (constants for easy access)
Node       = HTM::Models::Node
Tag        = HTM::Models::Tag
NodeTag    = HTM::Models::NodeTag
Robot      = HTM::Models::Robot
RobotNode  = HTM::Models::RobotNode
FileSource = HTM::Models::FileSource

# Pre-built HTM instances for common testing scenarios
def user
  @user ||= HTM.new(robot_name: "User")
end

def assistant
  @assistant ||= HTM.new(robot_name: "Assistant")
end

def researcher
  @researcher ||= HTM.new(robot_name: "Researcher")
end

def coder
  @coder ||= HTM.new(robot_name: "Coder")
end

def htm
  @htm ||= HTM.new(robot_name: "IRB Console")
end

# RubyLLM shortcuts
def llm
  require 'ruby_llm' unless defined?(RubyLLM)
  RubyLLM
end

def chat(message, model: 'gemma3:latest')
  llm.chat(messages: [{ role: 'user', content: message }], model: model).content
end

def embed(text, model: 'nomic-embed-text:latest')
  llm.embed(text, model: model)
end

# Database utilities
def db_stats
  puts <<~STATS

    === Database Statistics ===
    Nodes:       #{Node.count} (#{Node.deleted.count} deleted)
    Tags:        #{Tag.count}
    NodeTags:    #{NodeTag.count}
    Robots:      #{Robot.count}
    RobotNodes:  #{RobotNode.count}
    FileSources: #{FileSource.count}

  STATS
end

def health
  HTM::Observability.health_check
end

def healthy?
  HTM::Observability.healthy?
end

# Node exploration
def recent_nodes(limit = 5)
  puts "\n=== Recent Nodes ==="
  Node.order(created_at: :desc).limit(limit).each do |node|
    tags = node.tags.pluck(:name).join(', ')
    tags_str = tags.empty? ? "(no tags)" : tags
    content_preview = node.content.to_s[0..60].gsub("\n", " ")
    puts "Node #{node.id}: #{content_preview}..."
    puts "  Tags: #{tags_str}"
    puts "  Embedding: #{node.embedding ? "✓ (#{node.embedding.size}d)" : '✗'}"
    puts "  Created: #{node.created_at}"
    puts
  end
  nil
end

def recent_by_robot(robot_name, limit = 10)
  robot = Robot.find_by(name: robot_name)
  return puts("Robot '#{robot_name}' not found") unless robot

  puts "\n=== Recent Nodes by #{robot_name} ==="
  robot.nodes.order(created_at: :desc).limit(limit).each do |node|
    content_preview = node.content.to_s[0..60].gsub("\n", " ")
    puts "Node #{node.id}: #{content_preview}..."
  end
  nil
end

def node_info(node_id)
  node = Node.includes(:tags, :robots).find(node_id)
  embedding_info = node.embedding ? "✓ (#{node.embedding.size} dimensions)" : '✗'

  puts <<~NODE_INFO

    === Node #{node_id} ===
    Content: #{node.content}
    Type: #{node.memory_type}
    Importance: #{node.importance}
    Created: #{node.created_at}
    Last Accessed: #{node.last_accessed}
    Embedding: #{embedding_info}
    Deleted: #{node.deleted_at ? "Yes (#{node.deleted_at})" : 'No'}

    Tags:
  NODE_INFO

  if node.tags.any?
    node.tags.each { |tag| puts "  - #{tag.name}" }
  else
    puts "  (no tags)"
  end

  puts "\n    Robots:"
  if node.robots.any?
    node.robots.each { |robot| puts "  - #{robot.name}" }
  else
    puts "  (no robots)"
  end
  puts
  node
end

# Tag exploration
def tag_tree(prefix = nil)
  scope = prefix ? Tag.where("name LIKE ?", "#{prefix}%") : Tag.all
  puts scope.tree_string
  nil
end

def recent_tags(limit = 10)
  puts "\n=== Recent Tags ==="
  Tag.order(created_at: :desc).limit(limit).each do |tag|
    count = tag.nodes.count
    puts "#{tag.name} (#{count} nodes)"
  end
  nil
end

def popular_tags(limit = 20)
  puts "\n=== Popular Tags ==="
  Tag.joins(:nodes)
     .group('tags.id', 'tags.name')
     .order('COUNT(nodes.id) DESC')
     .limit(limit)
     .pluck('tags.name', 'COUNT(nodes.id)')
     .each { |name, count| puts "#{name} (#{count} nodes)" }
  nil
end

def search_tags(pattern)
  puts "\n=== Tags matching '#{pattern}' ==="
  Tag.where("name LIKE ?", "%#{pattern}%").each do |tag|
    count = tag.nodes.count
    puts "#{tag.name} (#{count} nodes)"
  end
  nil
end

# Robot exploration
def list_robots
  puts "\n=== Robots ==="
  Robot.all.each do |robot|
    node_count = robot.nodes.count
    puts "#{robot.name} (#{node_count} nodes) - created #{robot.created_at}"
  end
  nil
end

# Memory operations
def remember(content, type: :fact, importance: 5.0, tags: [])
  node = htm.remember(content, type: type, importance: importance, tags: tags)
  puts "✓ Created node #{node.id}"
  node
end

def recall(query, limit: 5, raw: false)
  htm.recall(query, limit: limit, raw: raw)
end

def search(query, strategy: :hybrid, limit: 10)
  htm.long_term_memory.search(query, strategy: strategy, limit: limit)
end

def similar_to(node_id, limit: 5)
  node = Node.find(node_id)
  node.nearest_neighbors(:embedding, distance: :cosine).limit(limit)
end

# Timeframe helpers
def today
  Date.today.beginning_of_day..Date.today.end_of_day
end

def yesterday
  1.day.ago.beginning_of_day..1.day.ago.end_of_day
end

def this_week
  Date.today.beginning_of_week..Date.today.end_of_day
end

def last_week
  1.week.ago.beginning_of_week..1.week.ago.end_of_week
end

def nodes_in(timeframe)
  Node.where(created_at: timeframe)
end

# File loading helpers
def load_file(path, force: false)
  htm.load_file(path, force: force)
end

def load_directory(path, pattern: '**/*.md', force: false)
  htm.load_directory(path, pattern: pattern, force: force)
end

def loaded_files
  puts "\n=== Loaded Files ==="
  FileSource.all.each do |fs|
    sync_status = fs.needs_sync? ? "needs sync" : "synced"
    puts "#{fs.file_path} (#{fs.chunks.count} chunks, #{sync_status})"
  end
  nil
end

# Reload helper
def reload!
  puts "Reloading HTM library..."
  load 'lib/htm.rb'
  @htm = nil
  @user = nil
  @assistant = nil
  @researcher = nil
  @coder = nil
  puts "✓ Reloaded"
end

# Help
def htm_help
  puts <<~HELP

    ============================================================
      HTM Interactive Console
    ============================================================

    ROBOT INSTANCES (lazy-loaded):
      htm          - Default console instance
      user         - "User" robot (the human)
      assistant    - "Assistant" robot
      researcher   - "Researcher" robot
      coder        - "Coder" robot

    MODEL CONSTANTS:
      Node, Tag, NodeTag, Robot, RobotNode, FileSource

    MEMORY OPERATIONS:
      remember(content, type:, importance:, tags:)
      recall(query, limit:, raw:)
      search(query, strategy:, limit:)
      similar_to(node_id, limit:)

    NODE EXPLORATION:
      recent_nodes(limit)
      recent_by_robot(robot_name, limit)
      node_info(node_id)
      nodes_in(timeframe)

    TAG EXPLORATION:
      tag_tree(prefix)
      recent_tags(limit)
      popular_tags(limit)
      search_tags(pattern)

    ROBOT EXPLORATION:
      list_robots

    FILE LOADING:
      load_file(path, force:)
      load_directory(path, pattern:, force:)
      loaded_files

    TIMEFRAME HELPERS:
      today, yesterday, this_week, last_week

    RUBYLLM:
      llm                   - RubyLLM module
      chat(message, model:) - Quick chat
      embed(text, model:)   - Generate embedding

    DATABASE:
      db_stats     - Show table counts
      health       - Full health check
      healthy?     - Quick boolean check

    UTILITIES:
      reload!      - Reload HTM library
      htm_help     - Show this help

  HELP
  nil
end

puts "✓ Helpers loaded"
puts "=" * 60
puts "\nType 'htm_help' for available commands\n\n"

db_stats
