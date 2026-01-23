# frozen_string_literal: true

# Database seeding for HTM
#
# This file loads seed data from markdown files in db/seed_data/ directory
# and creates memory nodes with embeddings and tags.
#
# Configuration is read from environment variables:
#   HTM_EMBEDDING__PROVIDER - Embedding provider (default: ollama)
#   HTM_EMBEDDING__MODEL - Embedding model (default: nomic-embed-text)
#   HTM_EMBEDDING__DIMENSIONS - Embedding dimensions (default: 768)
#   HTM_TAG__PROVIDER - Tag extraction provider (default: ollama)
#   HTM_TAG__MODEL - Tag extraction model (default: gemma3)
#   HTM_PROVIDERS__OLLAMA__URL - Ollama server URL (default: http://localhost:11434)
#   HTM_EMBEDDING__TIMEOUT - Embedding generation timeout in seconds (default: 120)
#   HTM_TAG__TIMEOUT - Tag generation timeout in seconds (default: 180)
#   HTM_CONNECTION_TIMEOUT - LLM connection timeout in seconds (default: 30)
#   HTM_DATABASE__URL - Database connection URL
#
# Usage:
#   rake htm:db:seed
#   # or
#   ruby -r ./lib/htm -e "load 'db/seeds.rb'"

require_relative '../lib/htm'

puts "=" * 80
puts "HTM Database Seeding"
puts "=" * 80
puts

# Configure HTM using environment variables or defaults
embedding_provider = (ENV['HTM_EMBEDDING__PROVIDER'] || 'ollama').to_sym
embedding_model = ENV['HTM_EMBEDDING__MODEL'] || 'nomic-embed-text'
embedding_dimensions = (ENV['HTM_EMBEDDING__DIMENSIONS'] || '768').to_i
tag_provider = (ENV['HTM_TAG__PROVIDER'] || 'ollama').to_sym
tag_model = ENV['HTM_TAG__MODEL'] || 'gemma3'
embedding_timeout = (ENV['HTM_EMBEDDING__TIMEOUT'] || '120').to_i
tag_timeout = (ENV['HTM_TAG__TIMEOUT'] || '180').to_i
connection_timeout = (ENV['HTM_CONNECTION_TIMEOUT'] || '60').to_i

puts "Configuration:"
puts "  Embedding Provider: #{embedding_provider}"
puts "  Embedding Model: #{embedding_model}"
puts "  Embedding Dimensions: #{embedding_dimensions}"
puts "  Tag Provider: #{tag_provider}"
puts "  Tag Model: #{tag_model}"
puts "  Timeouts: embedding=#{embedding_timeout}s, tag=#{tag_timeout}s, connection=#{connection_timeout}s"
puts

HTM.configure do |c|
  c.embedding.provider = embedding_provider
  c.embedding.model = embedding_model
  c.embedding.dimensions = embedding_dimensions
  c.tag.provider = tag_provider
  c.tag.model = tag_model
  c.embedding.timeout = embedding_timeout
  c.tag.timeout = tag_timeout
  c.connection_timeout = connection_timeout
  c.providers.ollama.url = ENV['HTM_PROVIDERS__OLLAMA__URL'] if ENV['HTM_PROVIDERS__OLLAMA__URL']
  c.reset_to_defaults  # Apply default implementations with configured settings
end

puts "✓ HTM configured"
puts

# Create HTM instance (uses default database config from ENV['HTM_DATABASE__URL'])
htm = HTM.new(robot_name: ENV['HTM_ROBOT_NAME'] || "Seed Robot")

# Add sample conversation messages
puts "Creating sample conversation..."

htm.remember(
  "What is TimescaleDB good for?",
  metadata: { source: "user" }
)

htm.remember(
  "PostgreSQL with TimescaleDB provides efficient time-series data storage and querying capabilities.",
  metadata: { source: "assistant" }
)

htm.remember(
  "How much training data do ML models need?",
  metadata: { source: "user" }
)

htm.remember(
  "Machine learning models require large amounts of training data to achieve good performance.",
  metadata: { source: "assistant" }
)

htm.remember(
  "Tell me about Ruby on Rails",
  metadata: { source: "user" }
)

htm.remember(
  "Ruby on Rails is a web framework for building database-backed applications.",
  metadata: { source: "assistant" }
)

puts "✓ Created 6 conversation messages (3 exchanges)"
puts

# Load and process all markdown files from seed_data directory
seed_data_dir = File.expand_path('../seed_data', __FILE__)
total_records = 6  # Start with conversation count

if Dir.exist?(seed_data_dir)
  # Find all .md files in seed_data directory
  md_files = Dir.glob(File.join(seed_data_dir, '*.md')).sort

  if md_files.any?
    puts "Found #{md_files.length} seed data files:"
    md_files.each { |f| puts "  - #{File.basename(f)}" }
    puts

    # Process each markdown file
    md_files.each do |md_file|
      filename = File.basename(md_file, '.md')
      puts "Processing #{File.basename(md_file)}..."

      content = File.read(md_file)
      count = 0

      # Parse markdown: find ## headers and their following paragraphs
      current_section = nil
      current_paragraph = []

      content.each_line do |line|
        line = line.strip

        if line.start_with?('## ')
          # Save previous section if we have one
          if current_section && current_paragraph.any?
            paragraph_text = current_paragraph.join(' ')
            htm.remember(paragraph_text, metadata: { source: filename })
            count += 1
            print "." if count % 10 == 0
          end

          # Start new section
          current_section = line.sub(/^## /, '')
          current_paragraph = []
        elsif line.length > 0 && current_section
          # Add to current paragraph
          current_paragraph << line
        end
      end

      # Don't forget the last section
      if current_section && current_paragraph.any?
        paragraph_text = current_paragraph.join(' ')
        htm.remember(paragraph_text, metadata: { source: filename })
        count += 1
      end

      puts
      puts "✓ Created #{count} memories from #{File.basename(md_file)}"
      total_records += count
    end
  else
    puts "⚠ No .md files found in #{seed_data_dir}"
  end
else
  puts "⚠ Seed data directory not found: #{seed_data_dir}"
end

puts
puts "=" * 80
puts "Summary"
puts "=" * 80
puts "✓ Database seeded with #{total_records} total nodes"
puts
puts "Waiting for background jobs to complete (embeddings and tags)..."
puts "This may take 2-3 minutes depending on your system and node count..."
puts

# Wait for background jobs to complete
# Estimate ~2 seconds per node for tags
wait_time = [total_records * 1.5, 30].max.to_i
puts "Waiting #{wait_time} seconds for background processing..."
sleep wait_time

puts
puts "Checking completion status..."

# Check completion status
nodes_with_embeddings = HTM::Models::Node.where.not(embedding: nil).count
puts "  - Nodes with embeddings: #{nodes_with_embeddings}/#{total_records}"

total_tags = HTM::Models::NodeTag.count
puts "  - Total tags generated: #{total_tags}"

unique_tags = HTM::Models::Tag.count
puts "  - Unique tags in ontology: #{unique_tags}"

puts
if nodes_with_embeddings == total_records && total_tags > 0
  puts "✓ All background jobs completed successfully!"
  puts "=" * 80
else
  puts "⚠ Some background jobs may still be running."
  puts "  Run this query to check progress:"
  puts "  HTM::Models::Node.where.not(embedding: nil).count"
  puts "=" * 80
end
