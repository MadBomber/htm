#!/usr/bin/env ruby
# frozen_string_literal: true

# HTM CLI Application Example
#
# Demonstrates using HTM in a command-line application with:
# - Synchronous job execution (inline mode)
# - Interactive command interface
# - Progress feedback
# - Database persistence
#
# Usage:
#   ruby htm_cli.rb
#
# Environment:
#   HTM_DBURL - PostgreSQL connection URL (required)
#   OLLAMA_URL - Ollama server URL (default: http://localhost:11434)
#

require_relative '../../lib/htm'
require 'io/console'
require 'ruby_llm'

PROVIDER = :ollama
MODEL    = 'gpt-oss:latest'

# Configure RubyLLM for Ollama provider (same pattern as HTM uses)
RubyLLM.configure do |config|
  ollama_url = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
  ollama_api_base = ollama_url.end_with?('/v1') ? ollama_url : "#{ollama_url}/v1"
  config.ollama_api_base = ollama_api_base
end

# Create chat with Ollama model - use assume_model_exists to bypass registry check
# AI = RubyLLM.chat(model: MODEL, provider: PROVIDER, assume_model_exists: true)

class HTMCli
  def initialize
    # Configure HTM for CLI usage
    HTM.configure do |config|
      # Use inline mode for synchronous execution
      config.job.backend = :inline

      # CLI-friendly logging
      config.logger.level = Logger::INFO
      config.logger.formatter = proc do |severity, datetime, progname, msg|
        case severity
        when 'INFO'
          "[✓] #{msg}\n"
        when 'WARN'
          "[⚠] #{msg}\n"
        when 'ERROR'
          "[✗] #{msg}\n"
        else
          "[•] #{msg}\n"
        end
      end
    end

    # Initialize RubyLLM chat for context-aware responses
    @chat = RubyLLM.chat(model: MODEL, provider: PROVIDER)

    # Initialize HTM instance
    @htm = HTM.new(robot_name: "cli_assistant")
  end

  def run
    puts
    puts "=" * 60
    puts "HTM CLI - Hierarchical Temporal Memory Assistant"
    puts "=" * 60
    puts
    puts "Job Backend: #{HTM.configuration.job_backend} (synchronous execution)"
    puts "Robot: #{@htm.robot_name}"
    puts
    puts "Commands:"
    puts "  remember <text>  - Store information"
    puts "  recall <topic>   - Search memories"
    puts "  tags             - List all tags with linked nodes"
    puts "  stats            - Show memory statistics"
    puts "  help             - Show this help"
    puts "  exit             - Quit"
    puts
    puts "=" * 60
    puts

    loop do
      print "\nhtm> "
      input = gets&.chomp
      break if input.nil? || input == 'exit'

      handle_command(input)
    end

    puts "\nGoodbye!"
  end

  private

  def handle_command(input)
    return if input.empty?

    parts = input.split(' ', 2)
    command = parts[0]
    args = parts[1]

    case command
    when 'remember'
      handle_remember(args)
    when 'recall'
      handle_recall(args)
    when 'tags'
      handle_tags(args)
    when 'stats'
      handle_stats
    when 'help'
      handle_help
    else
      puts "Unknown command: #{command}. Type 'help' for available commands."
    end
  rescue StandardError => e
    puts "[✗] Error: #{e.message}"
    puts "    #{e.class}: #{e.backtrace.first}"
  end

  def handle_remember(text)
    unless text && !text.empty?
      puts "Usage: remember <text>"
      return
    end

    puts "\nRemembering: \"#{text}\""
    puts "Processing..."

    start_time = Time.now
    node_id = @htm.remember(text)
    duration = ((Time.now - start_time) * 1000).round(2)

    puts "[✓] Stored as node #{node_id} (#{duration}ms)"

    # Show what was generated (inline mode, so already complete)
    node = HTM::Models::Node.includes(:tags).find(node_id)

    if node.embedding
      puts "    Embedding: #{node.embedding_dimension} dimensions"
    else
      puts "    Embedding: Not generated"
    end

    if node.tags.any?
      puts "    Tags: #{node.tags.map(&:name).join(', ')}"
    else
      puts "    Tags: None"
    end
  end

  def handle_recall(topic)
    unless topic && !topic.empty?
      puts "Usage: recall <topic>"
      return
    end

    puts "\nSearching for: \"#{topic}\""
    puts "Strategy: hybrid (vector + fulltext + tags)"

    # Show tags extracted from query and which ones matched
    tag_result = @htm.long_term_memory.find_query_matching_tags(topic, include_extracted: true)

    if tag_result[:extracted].any?
      puts "Extracted tags: #{tag_result[:extracted].join(', ')}"

      # Show what was actually searched (exact + prefixes)
      searched = tag_result[:extracted].dup
      tag_result[:extracted].each do |tag|
        levels = tag.split(':')
        (1...levels.size).each { |i| searched << levels[0, i].join(':') }
      end
      puts "Searched for:   #{searched.uniq.join(', ')}"

      if tag_result[:matched].any?
        puts "Matched in DB:  #{tag_result[:matched].join(', ')}"
      else
        puts "Matched in DB:  (none)"
      end
    else
      puts "Extracted tags: (none)"
    end

    start_time = Time.now
    memories = @htm.recall(
      topic,
      limit: 10,
      strategy: :hybrid,
      raw: true
    )
    duration = ((Time.now - start_time) * 1000).round(2)

    if memories.empty?
      puts "[•] No memories found (#{duration}ms)"
      return
    end

    puts "[✓] Found #{memories.length} memories (#{duration}ms)\n"

    memories.each_with_index do |memory, index|
      puts
      puts "#{index + 1}. Node #{memory['id']}"
      puts "   Created: #{memory['created_at']}"
      puts "   Content: #{memory['content']}"

      # Show scores from hybrid search
      if memory['combined_score']
        similarity = (memory['similarity'].to_f * 100).round(1)
        tag_boost = (memory['tag_boost'].to_f * 100).round(1)
        combined = (memory['combined_score'].to_f * 100).round(1)
        puts "   Scores: similarity=#{similarity}%, tag_boost=#{tag_boost}%, combined=#{combined}%"
      end

      # Show tags if any
      node = HTM::Models::Node.includes(:tags).find(memory['id'])
      if node.tags.any?
        puts "   Tags: #{node.tags.map(&:name).join(', ')}"
      else
        puts "   Tags: (none)"
      end
    end

    # Build LLM prompt with context from retrieved memories
    context_content = memories.map { |m| m['content'] }.join("\n\n")

    llm_prompt = <<~PROMPT
      #{topic}
      Your response should highlight information also found in the
      following context:
      <CONTEXT>
      #{context_content}
      </CONTEXT>
    PROMPT

    puts "\n" + "=" * 60
    puts "Generating response for this prompt..."
    puts llm_prompt
    puts "=" * 60

    begin
      response = @chat.ask(llm_prompt)
      puts "\n#{response.content}"

      # Remember the LLM response in long-term memory
      node_id = @htm.remember(response.content)
      puts "\n[✓] Response stored as node #{node_id}"
    rescue StandardError => e
      puts "[✗] LLM Error: #{e.message}"
    end
  end

  def handle_tags(filter = nil)
    puts "\nTags Overview:"
    puts

    # Get all tags with their nodes, optionally filtered by prefix
    tags_query = HTM::Models::Tag.includes(:nodes).order(:name)
    tags_query = tags_query.where("name LIKE ?", "#{filter}%") if filter && !filter.empty?

    tags = tags_query.to_a

    if tags.empty?
      if filter
        puts "[•] No tags found matching '#{filter}'"
      else
        puts "[•] No tags in database"
      end
      return
    end

    puts "[✓] Found #{tags.length} tags#{filter ? " matching '#{filter}'" : ""}"
    puts

    tags.each do |tag|
      nodes = tag.nodes.to_a
      puts "━" * 60
      puts "Tag: #{tag.name}"
      puts "     Nodes: #{nodes.length}"
      puts

      if nodes.any?
        nodes.each do |node|
          content_preview = node.content.to_s[0..70]
          content_preview += "..." if node.content.to_s.length > 70
          puts "     [#{node.id}] #{content_preview}"
        end
      else
        puts "     (no nodes linked)"
      end
      puts
    end

    # Show tag hierarchy summary
    root_tags = tags.map { |t| t.name.split(':').first }.uniq.sort
    if root_tags.length > 1
      puts "━" * 60
      puts "Root categories: #{root_tags.join(', ')}"
    end
  end

  def handle_stats
    puts "\nMemory Statistics:"
    puts

    total_nodes = HTM::Models::Node.count
    nodes_with_embeddings = HTM::Models::Node.where.not(embedding: nil).count
    nodes_with_tags = HTM::Models::Node.joins(:tags).distinct.count
    total_tags = HTM::Models::Tag.count
    total_robots = HTM::Models::Robot.count

    puts "Nodes:"
    puts "  Total: #{total_nodes}"
    puts "  With embeddings: #{nodes_with_embeddings} (#{percentage(nodes_with_embeddings, total_nodes)})"
    puts "  With tags: #{nodes_with_tags} (#{percentage(nodes_with_tags, total_nodes)})"
    puts

    puts "Tags:"
    puts "  Total: #{total_tags}"
    if total_tags > 0
      puts "  Average per node: #{(total_tags.to_f / total_nodes).round(2)}"
    end
    puts

    puts "Robots:"
    puts "  Total: #{total_robots}"
    puts

    puts "Current Robot (#{@htm.robot_name}):"
    robot_nodes = HTM::Models::RobotNode.where(robot_id: @htm.robot_id).count
    puts "  Nodes: #{robot_nodes}"
  end

  def handle_help
    puts
    puts "HTM CLI Commands:"
    puts
    puts "  remember <text>"
    puts "    Store information in long-term memory"
    puts "    Embeddings and tags are generated synchronously"
    puts "    Example: remember PostgreSQL is great for time-series data"
    puts
    puts "  recall <topic>"
    puts "    Search for relevant memories using hybrid search"
    puts "    Combines vector similarity, full-text search, and tag matching"
    puts "    Shows matching tags, scores (similarity, tag_boost, combined)"
    puts "    Example: recall PostgreSQL"
    puts "    Example: recall database optimization"
    puts
    puts "  tags [prefix]"
    puts "    List all tags with their linked node content"
    puts "    Optionally filter by tag prefix"
    puts "    Example: tags"
    puts "    Example: tags database"
    puts "    Example: tags ai:machine"
    puts
    puts "  stats"
    puts "    Show memory statistics and current state"
    puts
    puts "  help"
    puts "    Show this help message"
    puts
    puts "  exit"
    puts "    Quit the CLI"
    puts
  end

  def percentage(part, total)
    return "0%" if total.zero?
    "#{((part.to_f / total) * 100).round(1)}%"
  end
end

# Check database configuration
unless ENV['HTM_DBURL']
  puts
  puts "[✗] Error: HTM_DBURL environment variable not set"
  puts
  puts "Please set your database connection URL:"
  puts "  export HTM_DBURL='postgresql://postgres@localhost:5432/htm_development'"
  puts
  puts "See SETUP.md for database setup instructions."
  puts
  exit 1
end

# Check Ollama connection (optional but recommended)
begin
  require 'net/http'
  uri = URI(ENV['OLLAMA_URL'] || 'http://localhost:11434')
  response = Net::HTTP.get_response(uri)
rescue StandardError => e
  puts
  puts "[⚠] Warning: Cannot connect to Ollama (#{e.message})"
  puts "    Embeddings and tags will not be generated"
  puts "    Install Ollama: https://ollama.ai"
  puts
  puts "Continue anyway? (y/n) "
  answer = gets.chomp.downcase
  exit unless answer == 'y' || answer == 'yes'
end

# Run CLI
HTMCli.new.run
