#!/usr/bin/env ruby
# frozen_string_literal: true

# File loader example for HTM
#
# Demonstrates loading markdown files into long-term memory with:
# - Single file loading with frontmatter extraction
# - Directory loading with glob patterns
# - Querying nodes from loaded files
# - Unloading files
#
# Prerequisites:
# 1. Set HTM_DBURL environment variable (see SETUP.md)
# 2. Initialize database schema: rake db_setup
# 3. Install dependencies: bundle install

require_relative '../lib/htm'
require 'tempfile'
require 'fileutils'

puts "HTM File Loader Example"
puts "=" * 60

# Check environment
unless ENV['HTM_DBURL']
  puts "ERROR: HTM_DBURL not set. Please set it:"
  puts "  export HTM_DBURL=\"postgresql://postgres@localhost:5432/htm_development\""
  puts "See SETUP.md for details."
  exit 1
end

begin
  # Configure HTM globally (uses Ollama by default)
  puts "\n1. Configuring HTM with Ollama provider..."
  HTM.configure do |config|
    config.embedding_provider = :ollama
    config.embedding_model = 'nomic-embed-text:latest'
    config.embedding_dimensions = 768
    config.tag_provider = :ollama
    config.tag_model = 'gemma3:latest'
    config.reset_to_defaults
  end
  puts "   Configured with Ollama provider"

  # Initialize HTM
  puts "\n2. Initializing HTM..."
  htm = HTM.new(
    robot_name: "FileLoaderDemo",
    working_memory_size: 128_000
  )
  puts "   Robot: #{htm.robot_name} (ID: #{htm.robot_id})"

  # Create a temporary directory with sample markdown files
  puts "\n3. Creating sample markdown files..."
  temp_dir = Dir.mktmpdir('htm_file_loader_demo')

  # Sample file with frontmatter
  doc1_content = <<~MD
    ---
    title: PostgreSQL Guide
    author: HTM Team
    tags:
      - database
      - postgresql
    ---

    PostgreSQL is a powerful open-source relational database.

    It supports advanced features like:
    - JSON/JSONB data types
    - Full-text search
    - Vector similarity search via pgvector

    PostgreSQL is ideal for applications requiring complex queries.
  MD

  # Sample file without frontmatter
  doc2_content = <<~MD
    Ruby is a dynamic programming language.

    Key features include:
    - Everything is an object
    - Blocks and iterators
    - Metaprogramming capabilities

    Ruby on Rails made Ruby popular for web development.
  MD

  doc1_path = File.join(temp_dir, 'postgresql_guide.md')
  doc2_path = File.join(temp_dir, 'ruby_intro.md')
  File.write(doc1_path, doc1_content)
  File.write(doc2_path, doc2_content)
  puts "   Created: #{doc1_path}"
  puts "   Created: #{doc2_path}"

  # Load a single file
  puts "\n4. Loading single file with frontmatter..."
  result = htm.load_file(doc1_path)
  puts "   File: postgresql_guide.md"
  puts "   Source ID: #{result[:file_source_id]}"
  puts "   Chunks created: #{result[:chunks_created]}"
  puts "   Skipped: #{result[:skipped]}"

  # Access the file source to show frontmatter
  source = HTM::Models::FileSource.find(result[:file_source_id])
  puts "   Frontmatter title: #{source.title}"
  puts "   Frontmatter author: #{source.author}"
  puts "   Frontmatter tags: #{source.frontmatter_tags.join(', ')}"

  # Load a directory
  puts "\n5. Loading directory..."
  results = htm.load_directory(temp_dir, pattern: '*.md')
  puts "   Directory: #{temp_dir}"
  puts "   Files processed: #{results.size}"
  results.each do |r|
    status = r[:skipped] ? 'skipped' : "#{r[:chunks_created]} chunks"
    puts "   - #{File.basename(r[:file_path])}: #{status}"
  end

  # Query nodes from a specific file
  puts "\n6. Querying nodes from loaded file..."
  nodes = htm.nodes_from_file(doc1_path)
  puts "   Nodes from postgresql_guide.md: #{nodes.size}"
  nodes.each_with_index do |node, idx|
    preview = node.content[0..50].gsub("\n", " ")
    puts "   [#{idx}] #{preview}..."
  end

  # Demonstrate re-sync behavior (file unchanged)
  puts "\n7. Re-loading unchanged file (should skip)..."
  result = htm.load_file(doc1_path)
  puts "   Skipped: #{result[:skipped]}"
  puts "   (File unchanged, no sync needed)"

  # Force reload
  puts "\n8. Force reloading file..."
  result = htm.load_file(doc1_path, force: true)
  puts "   Skipped: #{result[:skipped]}"
  puts "   Chunks updated: #{result[:chunks_updated]}"

  # Unload a file
  puts "\n9. Unloading file..."
  count = htm.unload_file(doc2_path)
  puts "   Unloaded: ruby_intro.md"
  puts "   Chunks soft-deleted: #{count}"

  # Verify unload
  nodes = htm.nodes_from_file(doc2_path)
  puts "   Nodes remaining: #{nodes.size} (should be 0)"

  # Cleanup
  puts "\n10. Cleaning up..."
  htm.unload_file(doc1_path)
  FileUtils.rm_rf(temp_dir)
  puts "    Removed temporary files"

  puts "\n" + "=" * 60
  puts "Example completed successfully!"
  puts "\nFile loading API methods:"
  puts "  - htm.load_file(path, force: false)"
  puts "  - htm.load_directory(path, pattern: '**/*.md', force: false)"
  puts "  - htm.nodes_from_file(path)"
  puts "  - htm.unload_file(path)"
  puts "\nRake tasks:"
  puts "  - rake htm:files:load[path]"
  puts "  - rake htm:files:load_dir[path,pattern]"
  puts "  - rake htm:files:list"
  puts "  - rake htm:files:info[path]"
  puts "  - rake htm:files:unload[path]"
  puts "  - rake htm:files:sync"
  puts "  - rake htm:files:stats"

rescue => e
  puts "\nError: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
