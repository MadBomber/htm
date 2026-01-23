#!/usr/bin/env ruby
# Example HTM Application
#
# This demonstrates a simple application using the HTM gem with full RubyLLM integration.
#
# Prerequisites:
# 1. Set up examples database: rake examples:setup
# 2. Install dependencies: bundle install
#
# Run via:
#   ruby examples/example_app/app.rb

require_relative '../examples_helper'
require 'ruby_llm'
require 'logger'

class ExampleApp
  def self.run
    puts "\n=== HTM Full-Featured Example Application ==="
    ExamplesHelper.print_environment

    # Verify database is available
    ExamplesHelper.require_database!

    puts "Database configured: #{HTM.config.actual_database_name}"

    # Configure HTM with RubyLLM for embeddings and tag generation
    puts "\nConfiguring HTM with RubyLLM..."
    HTM.configure do |c|
      # Configure logger
      c.logger = Logger.new($stdout)
      c.logger.level = Logger::INFO

      # Configure embedding generation (using Ollama)
      c.embedding.provider = :ollama
      c.embedding.model = 'nomic-embed-text'
      c.embedding.dimensions = 768
      c.providers.ollama.url = ENV['OLLAMA_URL'] || 'http://localhost:11434'

      # Configure tag extraction (using Ollama - using smaller/faster model)
      c.tag.provider = :ollama
      c.tag.model = 'gemma3'  # Smaller model (3.3GB) for faster tag generation

      # Apply default implementations
      c.reset_to_defaults
    end

    puts "✓ Configured with Ollama:"
    puts "  - Embeddings: #{HTM.configuration.embedding_model}"
    puts "  - Tags: #{HTM.configuration.tag_model}"
    puts "  - Ollama URL: #{HTM.configuration.ollama_url}"

    # Check if Ollama is running
    puts "\nChecking Ollama connection..."
    begin
      require 'net/http'
      uri = URI(HTM.configuration.ollama_url)
      response = Net::HTTP.get_response(uri)
      puts "✓ Ollama is running"
    rescue StandardError => e
      puts "⚠ Warning: Cannot connect to Ollama (#{e.message})"
      puts "  Embeddings and tags will not be generated."
      puts "  Install Ollama: https://ollama.ai"
    end

    # Create HTM instance
    puts "\nInitializing HTM..."
    htm = HTM.new(robot_name: "Example App Robot")

    # Remember some conversation (simulating a conversation)
    puts "\nRemembering example conversation..."
    puts "(Tags will be auto-extracted by LLM in background)"

    node_1 = htm.remember(
      "HTM provides intelligent memory management for LLM-based applications"
    )

    node_2 = htm.remember(
      "The two-tier architecture includes working memory and long-term storage"
    )

    node_3 = htm.remember(
      "Can you explain how the working memory eviction algorithm works?"
    )

    puts "✓ Remembered 3 conversation messages (nodes #{node_1}, #{node_2}, #{node_3})"
    puts "  Embeddings and tags are being generated asynchronously..."

    # Wait for background jobs to complete
    # Note: Tag generation with LLM can take 10-15 seconds depending on model size
    puts "\nWaiting for background jobs to complete (15 seconds)..."
    puts "(Embeddings are fast, but tag generation requires LLM inference)"
    sleep 15

    # Check what was generated
    puts "\n--- Generated Tags ---"
    [node_1, node_2, node_3].each do |node_id|
      node = HTM::Models::Node[node_id]
      if node.tags.any?
        puts "Node #{node_id}:"
        node.tags.each { |tag| puts "  - #{tag.name}" }
      else
        puts "Node #{node_id}: (no tags yet)"
      end
    end

    # Check embeddings
    puts "\n--- Embedding Status ---"
    [node_1, node_2, node_3].each do |node_id|
      node = HTM::Models::Node[node_id]
      if node.embedding
        dimensions = node.embedding.is_a?(Array) ? node.embedding.size : node.embedding_dimension
        status = "✓ Generated (#{dimensions} dimensions)"
      else
        status = "⏳ Pending"
      end
      puts "Node #{node_id}: #{status}"
    end

    # Demonstrate different recall strategies
    puts "\n--- Recall Strategies Comparison ---"

    # 1. Full-text search (doesn't require embeddings)
    puts "\n1. Full-text Search for 'memory':"
    fulltext_memories = htm.recall(
      "memory",
      timeframe: (Time.now - 3600)..Time.now,
      strategy: :fulltext,
      limit: 3
    )
    puts "Found #{fulltext_memories.length} memories:"
    fulltext_memories.each do |content|
      puts "  - #{content[0..60]}..."
    end

    # 2. Vector search (requires embeddings)
    puts "\n2. Vector Search for 'intelligent memory system':"
    begin
      vector_memories = htm.recall(
        "intelligent memory system",
        timeframe: (Time.now - 3600)..Time.now,
        strategy: :vector,
        limit: 3
      )
      puts "Found #{vector_memories.length} memories:"
      vector_memories.each do |content|
        puts "  - #{content[0..60]}..."
      end
    rescue StandardError => e
      puts "  ⚠ Vector search error: #{e.message}"
      puts "     #{e.class}: #{e.backtrace.first}"
    end

    # 3. Hybrid search (combines both)
    puts "\n3. Hybrid Search for 'working memory architecture':"
    begin
      hybrid_memories = htm.recall(
        "working memory architecture",
        timeframe: (Time.now - 3600)..Time.now,
        strategy: :hybrid,
        limit: 3
      )
      puts "Found #{hybrid_memories.length} memories:"
      hybrid_memories.each do |content|
        puts "  - #{content[0..60]}..."
      end
    rescue StandardError => e
      puts "  ⚠ Hybrid search error: #{e.message}"
      puts "     #{e.class}: #{e.backtrace.first}"
    end

    # Summary
    puts "\n" + "="*60
    puts "✓ Demo Complete!"
    puts "="*60
    puts "\nThe HTM API provides 3 core methods:"
    puts "  1. htm.remember(content, tags: [])"
    puts "     - Stores information in long-term memory"
    puts "     - Adds to working memory for immediate use"
    puts "     - Generates embeddings and tags in background"
    puts ""
    puts "  2. htm.recall(topic, timeframe:, strategy:, limit:)"
    puts "     - Retrieves relevant memories"
    puts "     - Strategies: :fulltext, :vector, :hybrid"
    puts "     - Results added to working memory"
    puts ""
    puts "  3. htm.forget(node_id, confirm: :confirmed)"
    puts "     - Permanently deletes a memory node"
    puts "     - Requires explicit confirmation"
    puts ""
    puts "Background Features:"
    puts "  - Automatic embedding generation (#{HTM.configuration.embedding_model})"
    puts "  - Automatic hierarchical tag extraction (#{HTM.configuration.tag_model})"
    puts "  - Token counting for context management"
    puts "  - Multi-robot shared memory (hive mind)"
    puts ""
  end
end

# Run directly if called as script
if __FILE__ == $0
  ExampleApp.run
end
