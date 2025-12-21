#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for HTM
#
# Prerequisites:
# 1. Set HTM_DATABASE__URL environment variable (see SETUP.md)
# 2. Initialize database schema: rake db_setup
# 3. Install dependencies: bundle install

require_relative '../lib/htm'

puts "HTM Basic Usage Example"
puts "=" * 60

# Check environment
unless ENV['HTM_DATABASE__URL']
  puts "ERROR: HTM_DATABASE__URL not set. Please set it:"
  puts "  export HTM_DATABASE__URL=\"postgresql://postgres@localhost:5432/htm_development\""
  puts "See SETUP.md for details."
  exit 1
end

begin
  # Configure HTM globally (uses Ollama by default)
  puts "\n1. Configuring HTM with Ollama provider..."
  HTM.configure do |config|
    config.embedding_provider = :ollama
    config.embedding_model = 'nomic-embed-text:latest'  # Ollama models need :tag suffix
    config.embedding_dimensions = 768
    config.tag_provider = :ollama
    config.tag_model = 'gemma3:latest'  # Ollama models need :tag suffix
    config.reset_to_defaults  # Apply settings
  end
  puts "✓ HTM configured with Ollama provider"

  # Initialize HTM for 'Code Helper' robot
  puts "\n2. Initializing HTM for 'Code Helper' robot..."
  htm = HTM.new(
    robot_name: "Code Helper",
    working_memory_size: 128_000
  )
  puts "✓ HTM initialized"
  puts "  Robot ID: #{htm.robot_id}"
  puts "  Robot Name: #{htm.robot_name}"
  puts "  Embedding Service: Ollama (#{HTM.configuration.embedding_model})"

  # Remember some information
  puts "\n3. Remembering information..."

  node_id_1 = htm.remember(
    "We decided to use PostgreSQL for HTM storage because it provides excellent time-series optimization and native vector search with pgvector."
  )
  puts "✓ Remembered decision about database choice (node #{node_id_1})"

  node_id_2 = htm.remember(
    "We chose RAG (Retrieval-Augmented Generation) for memory recall, combining temporal filtering with semantic vector search."
  )
  puts "✓ Remembered decision about RAG approach (node #{node_id_2})"

  node_id_3 = htm.remember(
    "The user's name is Dewayne and they prefer using debug_me for debugging instead of puts."
  )
  puts "✓ Remembered fact about user preferences (node #{node_id_3})"

  # Sleep briefly to allow async embedding/tag jobs to start
  sleep 0.5

  # Demonstrate recall
  puts "\n4. Recalling memories about 'database'..."
  memories = htm.recall(
    "database",
    timeframe: (Time.now - 3600)..Time.now,  # Last hour
    limit: 5,
    raw: true  # Return full node data (id, content, etc.)
  )
  puts "✓ Found #{memories.length} memories"
  memories.each do |memory|
    content = memory['content'] || memory[:content]
    node_id = memory['id'] || memory[:id]
    puts "  - Node #{node_id}: #{content[0..60]}..."
  end

  puts "\n" + "=" * 60
  puts "✓ Example completed successfully!"
  puts "\nThe HTM API provides 3 core methods:"
  puts "  - htm.remember(content, tags: []) - Store information"
  puts "  - htm.recall(topic, timeframe:, ...) - Retrieve memories"
  puts "  - htm.forget(node_id, confirm:) - Delete a memory"

rescue => e
  puts "\n✗ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
