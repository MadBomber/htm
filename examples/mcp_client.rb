#!/usr/bin/env ruby
# frozen_string_literal: true

# MCP Client Example for HTM
#
# This example demonstrates using ruby_llm-mcp to connect to the
# HTM MCP server and interact with it through a chat interface
# using a local Ollama model.
#
# Prerequisites:
# 1. Install gems: gem install ruby_llm-mcp
# 2. Have Ollama running with gpt-oss model: ollama pull gpt-oss
# 3. Set HTM_DBURL environment variable
# 4. The htm_mcp.rb must be available (this client will launch it)
#
# Usage:
#   ruby examples/mcp_client.rb
#
# The client connects to the HTM MCP server via STDIO transport
# and provides an interactive chat loop where you can:
# - Ask the LLM to remember information
# - Query memories using natural language
# - List tags and statistics
# - All through conversational AI with tool calling

require 'ruby_llm'
require 'ruby_llm/mcp'

# Configuration
OLLAMA_MODEL    = ENV.fetch('OLLAMA_MODEL', 'gpt-oss:latest')
OLLAMA_URL      = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
MCP_SERVER_PATH = File.expand_path('../bin/htm_mcp.rb', __dir__)
ENV_ROBOT_NAME  = ENV['HTM_ROBOT_NAME']  # nil if not set, allows prompting

class HTMMcpClient
  attr_reader :robot_name

  def initialize
    validate_environment
    setup_ruby_llm
    setup_mcp_client
    prompt_for_robot_name
    set_robot_identity
    check_working_memory
    setup_chat
    restore_session_if_requested
  end


  def run
    print_banner
    chat_loop
  ensure
    cleanup
  end

  private

  def validate_environment
    unless ENV['HTM_DBURL']
      warn 'Error: HTM_DBURL not set.'
      warn '  export HTM_DBURL="postgresql://postgres@localhost:5432/htm_development"'
      exit 1
    end

    unless File.exist?(MCP_SERVER_PATH)
      warn "Error: MCP server not found at #{MCP_SERVER_PATH}"
      warn 'Please ensure mcp_server.rb exists in the examples directory.'
      exit 1
    end

    # Check Ollama is running
    require 'net/http'
    begin
      uri = URI(OLLAMA_URL)
      Net::HTTP.get_response(uri)
    rescue StandardError => e
      warn "Error: Cannot connect to Ollama at #{OLLAMA_URL}"
      warn "  #{e.message}"
      warn 'Please ensure Ollama is running: ollama serve'
      exit 1
    end
  end


  def setup_ruby_llm
    # Configure RubyLLM for Ollama
    RubyLLM.configure do |config|
      ollama_api_base = OLLAMA_URL.end_with?('/v1') ? OLLAMA_URL : "#{OLLAMA_URL}/v1"
      config.ollama_api_base = ollama_api_base
    end
  end


  def setup_mcp_client
    puts 'Connecting to HTM MCP server...'

    @mcp_client = RubyLLM::MCP.client(
      name: 'htm-memory',
      transport_type: :stdio,
      request_timeout: 60_000, # 60 seconds (in ms) for Ollama embedding generation
      config: {
        command: RbConfig.ruby,
        args: [MCP_SERVER_PATH],
        env: {
          'HTM_DBURL' => ENV['HTM_DBURL'],
          'OLLAMA_URL' => OLLAMA_URL
        }
      }
    )

    # Wait for server to be ready
    sleep 0.5

    if @mcp_client.alive?
      puts '[✓] Connected to HTM MCP server'
    else
      warn '[✗] Failed to connect to HTM MCP server'
      exit 1
    end

    # List available tools
    @tools = @mcp_client.tools
    puts "[✓] Found #{@tools.length} tools:"
    @tools.each do |tool|
      puts "    - #{tool.name}: #{tool.description[0..60]}..."
    end
    puts
  end


  def prompt_for_robot_name
    if ENV_ROBOT_NAME
      @robot_name = ENV_ROBOT_NAME
      puts "[✓] Using robot name from HTM_ROBOT_NAME: #{@robot_name}"
      return
    end

    puts
    print 'Enter your robot name (or press Enter for "Assistant"): '
    input = gets&.chomp

    @robot_name = if input.nil? || input.empty?
                    'Assistant'
                  else
                    input
                  end

    puts "[✓] Robot name: #{@robot_name}"
  end


  def set_robot_identity
    puts 'Setting robot identity on MCP server...'

    # Find the SetRobotTool
    set_robot_tool = @tools.find { |t| t.name == 'SetRobotTool' }

    unless set_robot_tool
      warn '[⚠] SetRobotTool not found - using default robot identity'
      return
    end

    # Call SetRobotTool directly via MCP
    result = set_robot_tool.call(name: @robot_name)

    # Parse the result
    begin
      response = JSON.parse(result.is_a?(String) ? result : result.to_s)
      if response['success']
        puts "[✓] Robot identity set: #{response['robot_name']} (id=#{response['robot_id']}, nodes=#{response['node_count']})"
      else
        warn "[⚠] Failed to set robot identity: #{response['error']}"
      end
    rescue JSON::ParserError => e
      warn "[⚠] Could not parse SetRobotTool response: #{e.message}"
    end
    puts
  end


  def check_working_memory
    # Check if there's working memory to restore
    get_wm_tool = @tools.find { |t| t.name == 'GetWorkingMemoryTool' }
    @working_memory_to_restore = nil
    return unless get_wm_tool

    result = get_wm_tool.call({})

    # Extract JSON from MCP Content object
    json_str = result.respond_to?(:text) ? result.text : result.to_s
    response = JSON.parse(json_str)

    # Debug: show what we got
    puts "[Debug] Working memory check: success=#{response['success']}, count=#{response['count']}"

    return unless response['success'] && response['count'].to_i > 0

    puts "Found #{response['count']} memories in working memory from previous session."
    print 'Restore previous session? (y/N): '
    input = gets&.chomp&.downcase

    if %w[y yes].include?(input)
      @working_memory_to_restore = response['working_memory']
      puts "[✓] Will restore #{@working_memory_to_restore.length} memories after chat setup"
    else
      puts '[✓] Starting fresh session'
    end
    puts
  rescue JSON::ParserError => e
    warn "[⚠] Could not parse working memory response: #{e.message}"
    warn "[⚠] Raw: #{json_str.inspect[0..200]}" if defined?(json_str)
  rescue StandardError => e
    warn "[⚠] Error checking working memory: #{e.class} - #{e.message}"
  end


  def restore_session_if_requested
    return unless @working_memory_to_restore

    puts "Restoring #{@working_memory_to_restore.length} memories to chat context..."

    # Build a system context from the working memory
    context_parts = @working_memory_to_restore.map do |mem|
      tags_str = mem['tags'].empty? ? '' : " [#{mem['tags'].join(', ')}]"
      "- #{mem['content']}#{tags_str}"
    end

    context_message = <<~CONTEXT
      The following information was remembered from your previous session with this user:

      #{context_parts.join("\n")}

      Use this context to inform your responses, but don't explicitly mention that you're restoring a session unless asked.
    CONTEXT

    # Add the context as a system message to prime the chat
    @chat.add_message(role: :user, content: "Previous session context: #{context_message}")
    @chat.add_message(role: :assistant,
                      content: "I've restored context from our previous session. How can I help you today?")

    puts "[✓] Restored #{@working_memory_to_restore.length} memories to chat context"
    puts
  end


  def setup_chat
    puts "Initializing chat with #{OLLAMA_MODEL}..."

    @chat = RubyLLM.chat(
      model: OLLAMA_MODEL,
      provider: :ollama,
      assume_model_exists: true
    )

    # Attach MCP tools to the chat
    @chat.with_tools(*@tools)

    # Set up tool call logging
    setup_tool_callbacks

    puts '[✓] Chat initialized with tools attached'
  end


  def print_banner
    puts
    puts '=' * 70
    puts 'HTM MCP Client - AI Chat with Memory Tools'
    puts '=' * 70
    puts
    puts "Robot: #{@robot_name}"
    puts "Model: #{OLLAMA_MODEL} (via Ollama)"
    puts "MCP Server: #{MCP_SERVER_PATH}"
    puts
    puts 'Available tools:'
    @tools.each do |tool|
      puts "  • #{tool.name}"
    end
    puts
    puts 'Example queries:'
    puts '  "Remember that the API rate limit is 1000 requests per minute"'
    puts '  "What do you know about databases?"'
    puts '  "Show me the memory statistics"'
    puts '  "List all tags"'
    puts '  "Forget node 123"'
    puts
    puts 'Commands:'
    puts '  /tools     - List available MCP tools'
    puts '  /resources - List available MCP resources'
    puts '  /stats     - Show memory statistics'
    puts '  /tags      - List all tags'
    puts '  /clear     - Clear chat history'
    puts '  /help      - Show this help'
    puts '  /exit      - Quit'
    puts
    puts '=' * 70
    puts
  end


  def chat_loop
    loop do
      print 'you> '
      input = gets&.chomp
      break if input.nil?

      next if input.empty?

      # Handle commands
      case input
      when '/exit', '/quit', '/q'
        break
      when '/tools'
        show_tools
        next
      when '/resources'
        show_resources
        next
      when '/stats'
        show_stats
        next
      when '/tags'
        show_tags
        next
      when '/clear'
        clear_chat
        next
      when '/help'
        print_banner
        next
      end

      # Send to LLM with tools
      begin
        print "\n#{@robot_name}> "
        response = @chat.ask(input)
        puts response.content
        puts
      rescue StandardError => e
        puts "\n[✗] Error: #{e.message}"
        puts "    #{e.class}: #{e.backtrace.first}"
        puts
      end
    end

    puts "\nGoodbye!"
  end


  def show_tools
    puts "\nAvailable MCP Tools:"
    puts '-' * 50
    @tools.each do |tool|
      puts
      puts "#{tool.name}"
      puts "  #{tool.description}"
    end
    puts
  end


  def show_resources
    puts "\nAvailable MCP Resources:"
    puts '-' * 50
    begin
      resources = @mcp_client.resources
      if resources.empty?
        puts '  (no resources available)'
      else
        resources.each do |resource|
          puts
          puts "#{resource.uri}"
          puts "  #{resource.name}" if resource.respond_to?(:name)
        end
      end
    rescue StandardError => e
      puts "  Error fetching resources: #{e.message}"
    end
    puts
  end


  def show_stats
    puts "\nMemory Statistics:"
    puts '-' * 50

    stats_tool = @tools.find { |t| t.name == 'StatsTool' }
    unless stats_tool
      puts '  StatsTool not available'
      puts
      return
    end

    result = stats_tool.call({})

    # Handle different response types from MCP
    # RubyLLM::MCP::Content objects have a .text attribute
    json_str = case result
               when String then result
               when Hash then result.to_json
               else
                 # Try to extract text from MCP Content objects
                 if result.respond_to?(:text)
                   result.text
                 elsif result.respond_to?(:content)
                   result.content.is_a?(String) ? result.content : result.content.to_s
                 else
                   result.to_s
                 end
               end

    response = JSON.parse(json_str)

    if response['success']
      robot = response['current_robot']
      stats = response['statistics']

      puts
      puts "Current Robot: #{robot['name']} (id=#{robot['id']})"
      puts "  Working memory: #{robot['memory_summary']['in_working_memory']} nodes"
      puts "  Total nodes: #{robot['memory_summary']['total_nodes']}"
      puts "  With embeddings: #{robot['memory_summary']['with_embeddings']}"
      puts
      puts 'Global Statistics:'
      puts "  Active nodes: #{stats['nodes']['active']}"
      puts "  Deleted nodes: #{stats['nodes']['deleted']}"
      puts "  Total tags: #{stats['tags']['total']}"
      puts "  Total robots: #{stats['robots']['total']}"
    else
      puts "  Error: #{response['error']}"
    end
    puts
  rescue JSON::ParserError => e
    puts "  Error parsing response: #{e.message}"
    puts "  Raw response: #{result.inspect[0..200]}"
    puts
  rescue StandardError => e
    puts "  Error: #{e.message}"
    puts
  end


  def show_tags
    puts "\nTags:"
    puts '-' * 50

    tags_tool = @tools.find { |t| t.name == 'ListTagsTool' }
    unless tags_tool
      puts '  ListTagsTool not available'
      puts
      return
    end

    result = tags_tool.call({})

    # Extract JSON from MCP Content object
    json_str = result.respond_to?(:text) ? result.text : result.to_s
    response = JSON.parse(json_str)

    if response['success']
      tags = response['tags']
      if tags.empty?
        puts '  (no tags found)'
      else
        tags.each do |tag|
          puts "  #{tag['name']} (#{tag['node_count']} nodes)"
        end
      end
    else
      puts "  Error: #{response['error']}"
    end
    puts
  rescue JSON::ParserError => e
    puts "  Error parsing response: #{e.message}"
    puts
  rescue StandardError => e
    puts "  Error: #{e.message}"
    puts
  end


  def clear_chat
    @chat = RubyLLM.chat(
      model: OLLAMA_MODEL,
      provider: :ollama,
      assume_model_exists: true
    )
    @chat.with_tools(*@tools)
    setup_tool_callbacks

    puts '[✓] Chat history cleared'
    puts
  end


  def setup_tool_callbacks
    @chat.on_tool_call do |tool_call|
      puts "\n[Tool Call] #{tool_call.name}"
      puts "  Arguments: #{tool_call.arguments.inspect}"
    end

    @chat.on_tool_result do |tool_call, result|
      # tool_call may be a Content object, so safely get the name
      tool_name = tool_call.respond_to?(:name) ? tool_call.name : tool_call.class.name.split('::').last
      puts "[Tool Result] #{tool_name}"
      display_result = result.to_s
      display_result = display_result[0..200] + '...' if display_result.length > 200
      puts "  Result: #{display_result}"
      puts
    end
  end


  def cleanup
    @mcp_client&.close if @mcp_client.respond_to?(:close)
  end
end

# Main entry point
begin
  require 'ruby_llm/mcp'
rescue LoadError
  warn 'Error: ruby_llm-mcp gem not found.'
  warn 'Install it with: gem install ruby_llm-mcp'
  exit 1
end

HTMMcpClient.new.run
