#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Custom LLM Configuration for HTM
#
# This example demonstrates how to configure HTM with custom LLM methods
# for embedding generation and tag extraction, as well as using defaults.
#
# Prerequisites:
# 1. Set up examples database: rake examples:setup
# 2. Install dependencies: bundle install
#
# Run via:
#   ruby examples/custom_llm_configuration.rb

require_relative 'examples_helper'

ExamplesHelper.section "HTM Custom LLM Configuration Example"
ExamplesHelper.print_environment

# Verify database is available
ExamplesHelper.require_database!

# Example 1: Use Default Configuration (RubyLLM with Ollama)
puts "\n1. Using Default Configuration (RubyLLM + Ollama)"
puts "-" * 50

HTM.configure  # Uses defaults

htm = HTM.new(robot_name: "DefaultBot")
puts "✓ HTM initialized with default LLM configuration"
puts "  Embedding provider: #{HTM.configuration.embedding_provider}"
puts "  Embedding model: #{HTM.configuration.embedding_model}"
puts "  Tag provider: #{HTM.configuration.tag_provider}"
puts "  Tag model: #{HTM.configuration.tag_model}"

# Example 2: Custom Configuration with Lambdas
puts "\n2. Custom Configuration with Lambdas"
puts "-" * 50

HTM.configure do |config|
  # Custom embedding generator
  config.embedding_generator = lambda do |text|
    puts "  → Custom embedding generator called for: #{text[0..50]}..."
    # Simulate custom embedding service
    # In real application, this would call your LLM infrastructure
    Array.new(768) { rand }  # Returns 768-dimensional random vector
  end

  # Custom tag extractor
  config.tag_extractor = lambda do |text, existing_ontology|
    puts "  → Custom tag extractor called for: #{text[0..50]}..."
    puts "  → Existing ontology size: #{existing_ontology.size}"
    # Simulate custom tag extraction
    # In real application, this would call your LLM infrastructure
    ['custom:tag:example', 'test:automated']
  end
end

htm = HTM.new(robot_name: "CustomBot")
puts "✓ HTM initialized with custom LLM configuration"

# Test the custom methods
embedding = HTM.embed("This is a test message")
puts "✓ Custom embedding generated: #{embedding.length} dimensions"

tags = HTM.extract_tags("PostgreSQL is a powerful database", existing_ontology: ['database:sql'])
puts "✓ Custom tags extracted: #{tags.join(', ')}"

# Example 3: Configure with Custom Class
puts "\n3. Custom Configuration with Service Object"
puts "-" * 50

# Define a custom LLM service class
class MyAppLLMService
  def self.embed(text)
    puts "  → MyAppLLMService.embed called"
    # Your application's embedding logic here
    # Could integrate with LangChain, LlamaIndex, or custom infrastructure
    Array.new(1024) { rand }  # 1024-dimensional embeddings
  end

  def self.extract_tags(text, ontology)
    puts "  → MyAppLLMService.extract_tags called"
    # Your application's tag extraction logic here
    ['app:feature:memory', 'app:component:llm']
  end
end

HTM.configure do |config|
  config.embedding_generator = ->(text) { MyAppLLMService.embed(text) }
  config.tag_extractor = ->(text, ontology) { MyAppLLMService.extract_tags(text, ontology) }
end

htm = HTM.new(robot_name: "ServiceBot")
puts "✓ HTM initialized with service object configuration"

embedding = HTM.embed("Another test message")
puts "✓ Service embedding generated: #{embedding.length} dimensions"

# Example 4: Mixed Configuration (Custom Embedding, Default Tags)
puts "\n4. Mixed Configuration (Custom + Default)"
puts "-" * 50

HTM.configure do |config|
  # Use custom embedding
  config.embedding_generator = ->(text) {
    puts "  → Using custom embedder"
    Array.new(512) { rand }
  }

  # Keep default tag extraction
  # (Already set by default, but showing explicit control)
  config.reset_to_defaults  # Reset both

  # Then override just embedding
  config.embedding_generator = ->(text) {
    puts "  → Using custom embedder with default tagger"
    Array.new(512) { rand }
  }
end

htm = HTM.new(robot_name: "MixedBot")
puts "✓ HTM initialized with mixed configuration"

# Example 5: Configure Provider Settings for Defaults
puts "\n5. Configuring Default Provider Settings"
puts "-" * 50

HTM.configure do |config|
  # Customize the default RubyLLM configuration using nested syntax
  config.embedding.provider = :ollama
  config.embedding.model = 'nomic-embed-text'
  config.embedding.dimensions = 768

  config.tag.provider = :ollama
  config.tag.model = 'llama3'

  config.providers.ollama.url = ENV['OLLAMA_URL'] || 'http://localhost:11434'

  # Reset to use these new settings with default implementations
  config.reset_to_defaults
end

htm = HTM.new(robot_name: "ConfiguredDefaultBot")
puts "✓ HTM initialized with configured default settings"
puts "  Embedding model: #{HTM.configuration.embedding_model}"
puts "  Tag model: #{HTM.configuration.tag_model}"
puts "  Ollama URL: #{HTM.configuration.ollama_url}"

# Example 6: Integration with HTM Operations
puts "\n6. Using Custom Configuration in HTM Operations"
puts "-" * 50

# Configure with test implementation
HTM.configure do |config|
  config.embedding_generator = ->(text) {
    puts "  → Embedding: #{text[0..40]}..."
    Array.new(768) { rand }
  }

  config.tag_extractor = ->(text, ontology) {
    puts "  → Tagging: #{text[0..40]}..."
    ['example:ruby:gem', 'memory:llm']
  }
end

htm = HTM.new(robot_name: "IntegrationBot")

# Remember information - will use custom LLM configuration
puts "\nRemembering information in HTM..."
node_id = htm.remember(
  "PostgreSQL with pgvector enables efficient vector similarity search"
)

puts "✓ Information remembered with node_id: #{node_id}"
puts "  Note: Embedding and LLM-generated tags will be processed asynchronously"

# The async jobs will call:
# - HTM.embed(content) for embedding generation
# - HTM.extract_tags(content, existing_ontology) for tag extraction

puts "\n" + "=" * 50
puts "Configuration Summary"
puts "=" * 50
puts "Applications can configure HTM by:"
puts "1. Using HTM.configure with a block"
puts "2. Providing embedding_generator callable (String → Array<Float>)"
puts "3. Providing tag_extractor callable (String, Array<String> → Array<String>)"
puts "4. Or using sensible defaults with RubyLLM + Ollama"
puts "\nHTM delegates all LLM operations to these configured methods,"
puts "allowing complete flexibility in LLM infrastructure."
