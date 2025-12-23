#!/usr/bin/env ruby
# frozen_string_literal: true

# Robot Worker - Standalone process that participates in a robot group
#
# Usage: ruby robot_worker.rb <robot_name> <group_name>
#
# Communication:
#   - Receives JSON commands via stdin
#   - Sends JSON responses via stdout
#   - Logs to stderr
#
# Commands:
#   { "cmd": "ping" }
#   { "cmd": "remember", "content": "..." }
#   { "cmd": "recall", "query": "...", "limit": 5 }
#   { "cmd": "status" }
#   { "cmd": "shutdown" }
#
# Note: This worker inherits HTM_ENV and HTM_DATABASE__URL from the parent
# process (multi_process.rb) which uses examples_helper.rb.

require 'logger'
require 'json'
require_relative '../examples_helper'

robot_name = ARGV[0]
group_name = ARGV[1]

unless robot_name && group_name
  $stderr.puts "Usage: ruby robot_worker.rb <robot_name> <group_name>"
  exit 1
end

def log(robot_name, message)
  timestamp = Time.now.strftime('%H:%M:%S.%L')
  $stderr.puts "[#{timestamp}] [#{robot_name}] #{message}"
  $stderr.flush
end

# Configure HTM with logger to stderr (keep stdout clean for JSON)
HTM.configure do |config|
  config.embedding.provider = :ollama
  config.embedding.model = 'nomic-embed-text:latest'
  config.embedding.dimensions = 768
  config.tag.provider = :ollama
  config.tag.model = 'gemma3:latest'
  config.logger = Logger.new($stderr, level: Logger::WARN)
end

log(robot_name, 'Starting up...')

# Create HTM instance for this robot
htm = HTM.new(robot_name: robot_name, working_memory_size: 8000)
db_config = HTM::Database.default_config

# Setup channel for cross-process notifications
channel = HTM::WorkingMemoryChannel.new(group_name, db_config)

# Track notifications received
notifications_count = 0
channel.on_change do |event, node_id, origin_robot_id|
  next if origin_robot_id == htm.robot_id

  notifications_count += 1
  log(robot_name, "Received #{event} for node #{node_id}")

  case event
  when :added
    node = HTM::Models::Node.find_by(id: node_id)
    if node
      htm.working_memory.add_from_sync(
        id: node.id,
        content: node.content,
        token_count: node.token_count || 0,
        created_at: node.created_at
      )
    end
  when :evicted
    htm.working_memory.remove_from_sync(node_id)
  when :cleared
    htm.working_memory.clear_from_sync
  end
end

channel.start_listening
log(robot_name, "Listening on channel: #{channel.channel_name}")

# Process commands from stdin
$stdin.each_line do |line|
  begin
    command = JSON.parse(line.strip, symbolize_names: true)

    result = case command[:cmd]
    when 'remember'
      log(robot_name, "Remembering: #{command[:content][0..40]}...")
      node_id = htm.remember(command[:content])
      channel.notify(:added, node_id: node_id, robot_id: htm.robot_id)
      log(robot_name, "Sent notification for node #{node_id}")
      { status: 'ok', node_id: node_id }

    when 'recall'
      log(robot_name, "Recalling: #{command[:query]}")
      results = htm.recall(command[:query], limit: command[:limit] || 5, strategy: :fulltext, raw: true)
      { status: 'ok', count: results.length }

    when 'status'
      {
        status: 'ok',
        robot_id: htm.robot_id,
        working_memory_nodes: htm.working_memory.node_count,
        working_memory_tokens: htm.working_memory.token_count,
        notifications_received: notifications_count
      }

    when 'ping'
      { status: 'ok', message: 'pong', robot: robot_name }

    when 'shutdown'
      channel.stop_listening
      log(robot_name, 'Shutting down.')
      puts({ status: 'ok', message: 'bye' }.to_json)
      $stdout.flush
      exit 0

    else
      { status: 'error', message: "Unknown command: #{command[:cmd]}" }
    end

    puts result.to_json
    $stdout.flush
  rescue StandardError => e
    puts({ status: 'error', message: e.message }.to_json)
    $stdout.flush
  end
end

channel.stop_listening
