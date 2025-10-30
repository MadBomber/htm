# frozen_string_literal: true

# HTM IRB Configuration
# Load this with: irb -r ./.irbrc
# Or just: irb (if in the htm directory)

puts "Loading HTM library..."

# Load the HTM library
require_relative 'lib/htm'

# Establish database connection
HTM::ActiveRecordConfig.establish_connection! unless HTM::ActiveRecordConfig.connected?

# Configure HTM with Ollama for embedding and tag generation
HTM.configure do |c|
  c.embedding_provider   = :ollama
  c.embedding_model      = 'nomic-embed-text'
  c.embedding_dimensions = 768
  c.tag_provider = :ollama
  c.tag_model    = 'gemma3'
  c.reset_to_defaults
end

# Convenience aliases for models
Node    = HTM::Models::Node
Tag     = HTM::Models::Tag
NodeTag = HTM::Models::NodeTag
Robot   = HTM::Models::Robot

# Helper methods
def reload!
  puts "Reloading HTM library..."
  load 'lib/htm.rb'
  puts "✓ Reloaded"
end

def db_stats
  puts <<~STATS

    === Database Statistics ===
    Nodes:     #{Node.count}
    Tags:      #{Tag.count}
    NodeTags:  #{NodeTag.count}
    Robots:    #{Robot.count}

  STATS
end

def recent_nodes(limit = 5)
  puts "\n=== Recent Nodes ==="
  Node.order(created_at: :desc).limit(limit).each do |node|
    tags = node.tags.pluck(:name).join(', ')
    tags_str = tags.empty? ? "(no tags)" : tags
    puts "Node #{node.id}: #{node.content[0..60]}..."
    puts "  Tags: #{tags_str}"
    puts "  Embedding: #{node.embedding ? '✓' : '✗'}"
    puts ""
  end
end

def recent_tags(limit = 10)
  puts "\n=== Recent Tags ==="
  Tag.order(created_at: :desc).limit(limit).each do |tag|
    count = tag.nodes.count
    puts "#{tag.name} (#{count} nodes)"
  end
  puts
end

def search_tags(pattern)
  puts "\n=== Tags matching '#{pattern}' ==="
  Tag.where("name LIKE ?", "%#{pattern}%").each do |tag|
    count = tag.nodes.count
    puts "#{tag.name} (#{count} nodes)"
  end
  puts
end

def node_with_tags(node_id)
  node = Node.includes(:tags).find(node_id)
  embedding_info = if node.embedding
    "✓ (#{node.embedding.size} dimensions)"
  else
    '✗'
  end

  puts <<~NODE_INFO

    === Node #{node_id} ===
    Content: #{node.content}
    Source: #{node.source}
    Created: #{node.created_at}
    Embedding: #{embedding_info}

    Tags:
  NODE_INFO

  if node.tags.any?
    node.tags.each { |tag| puts "  - #{tag.name}" }
  else
    puts "  (no tags)"
  end
  puts
  node
end

def create_test_node(content, source: "irb")
  htm = HTM.new(robot_name: "IRB User")
  node_id = htm.remember(content, source: source)
  puts "✓ Created node #{node_id}"
  node_id
end

def htm_help
  puts <<~WELCOME

    ============================================================
      HTM Interactive Console
    ============================================================

    Available models:
      - Node      (HTM::Models::Node)
      - Tag       (HTM::Models::Tag)
      - NodeTag   (HTM::Models::NodeTag)
      - Robot     (HTM::Models::Robot)

    Helper methods:
      htm_help              # Reprints this message
      db_stats              # Show database statistics
      recent_nodes(n)       # Show n recent nodes (default: 5)
      recent_tags(n)        # Show n recent tags (default: 10)
      search_tags(pattern)  # Search tags by pattern
      node_with_tags(id)    # Show node details with tags
      create_test_node(str) # Create a test node
      reload!               # Reload HTM library

    Database: #{HTM::Database.default_config[:dbname]}
  WELCOME
end

htm_help
db_stats

print "HTM Ready!\n\n"
