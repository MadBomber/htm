#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example for HTM
#
# Prerequisites:
# 1. Configure database via environment or config file:
#    - HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
#    - Or individual vars: HTM_DATABASE__HOST, HTM_DATABASE__NAME, etc.
# 2. Initialize database schema: rake htm:db:setup
# 3. Install dependencies: bundle install

require_relative '../lib/htm'

puts "HTM Basic Usage Example"
puts "=" * 60

# Check database configuration using the config system
unless HTM.config.database_configured?
  puts "ERROR: Database not configured. Set one of:"
  puts "  export HTM_DATABASE__URL=\"postgresql://user@localhost:5432/htm_development\""
  puts "  Or configure in ~/.config/htm/htm.yml"
  puts "Run 'bin/htm_mcp help' for all configuration options."
  exit 1
end

begin
  # Configure HTM globally (uses Ollama by default from defaults.yml)
  puts "\n1. Configuring HTM with Ollama provider..."
  HTM.configure do |config|
    config.embedding.provider = :ollama
    config.embedding.model = 'nomic-embed-text:latest'
    config.embedding.dimensions = 768
    config.tag.provider = :ollama
    config.tag.model = 'gemma3:latest'
    # Use inline job backend for synchronous execution in examples
    # (In production, use :thread or :sidekiq for async processing)
    config.job.backend = :inline
    # Quiet the logs for cleaner output
    config.log_level = :warn
  end
  puts "✓ HTM configured with Ollama provider (inline job backend)"

  # Initialize HTM for 'Code Helper' robot
  puts "\n2. Initializing HTM for 'Code Helper' robot..."
  htm = HTM.new(
    robot_name: "Code Helper",
    working_memory_size: 128_000
  )
  puts "✓ HTM initialized"
  puts "  Robot ID: #{htm.robot_id}"
  puts "  Robot Name: #{htm.robot_name}"
  puts "  Embedding Service: #{HTM.config.embedding.provider} (#{HTM.config.embedding.model})"

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

  # With inline backend, embeddings and tags are generated synchronously
  # No sleep needed - memories are immediately searchable

  # Demonstrate recall using fulltext search (keyword matching)
  # Note: hybrid search requires fulltext matches first, so search terms
  # must appear in the stored content. Use fulltext for keyword matching.
  puts "\n4. Recalling memories about 'PostgreSQL'..."
  memories = htm.recall(
    "PostgreSQL",  # This word appears in the stored content
    timeframe: (Time.now - 3600)..Time.now,  # Last hour
    limit: 5,
    strategy: :fulltext,  # Keyword matching (words must appear in content)
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
