#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for HTM
#
# Prerequisites:
# 1. Source environment variables: source ~/.bashrc__tiger
# 2. Initialize database schema: ruby -r ./lib/htm -e "HTM::Database.setup"
# 3. Install dependencies: bundle install

require_relative '../lib/htm'

puts "HTM Basic Usage Example"
puts "=" * 60

# Check environment
unless ENV['HTM_DBURL']
  puts "ERROR: HTM_DBURL not set. Please run: source ~/.bashrc__tiger"
  exit 1
end

begin
  # Configure HTM globally (uses RubyLLM with Ollama by default)
  puts "\n1. Configuring HTM with Ollama provider..."
  HTM.configure do |config|
    config.embedding_provider = :ollama
    config.embedding_model = 'nomic-embed-text'
    config.embedding_dimensions = 768
    config.tag_provider = :ollama
    config.tag_model = 'llama3'
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
    "We decided to use PostgreSQL for HTM storage because it provides excellent time-series optimization and native vector search with pgvector.",
    source: "architect"
  )
  puts "✓ Remembered decision about database choice (node #{node_id_1})"

  node_id_2 = htm.remember(
    "We chose RAG (Retrieval-Augmented Generation) for memory recall, combining temporal filtering with semantic vector search.",
    source: "architect"
  )
  puts "✓ Remembered decision about RAG approach (node #{node_id_2})"

  node_id_3 = htm.remember(
    "The user's name is Dewayne and they prefer using debug_me for debugging instead of puts.",
    source: "system"
  )
  puts "✓ Remembered fact about user preferences (node #{node_id_3})"

  # Sleep briefly to allow async embedding/tag jobs to start
  sleep 0.5

  # Demonstrate recall
  puts "\n4. Recalling memories about 'database'..."
  memories = htm.recall(
    timeframe: (Time.now - 3600)..Time.now,  # Last hour
    topic: "database",
    limit: 5
  )
  puts "✓ Found #{memories.length} memories"
  memories.each do |memory|
    puts "  - Node #{memory['id']}: #{memory['content'][0..60]}..."
  end

  puts "\n" + "=" * 60
  puts "✓ Example completed successfully!"
  puts "\nThe HTM API provides 3 core methods:"
  puts "  - htm.remember(content, source:) - Store information"
  puts "  - htm.recall(timeframe:, topic:, ...) - Retrieve memories"
  puts "  - htm.forget(node_id, confirm:) - Delete a memory"

rescue => e
  puts "\n✗ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
