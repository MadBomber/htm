#!/usr/bin/env ruby
# frozen_string_literal: true

# Multi-Process Robot Group Demo
#
# Demonstrates real-time synchronization across SEPARATE PROCESSES
# using PostgreSQL LISTEN/NOTIFY. Spawns robot_worker.rb as child processes.
#
# Key concepts:
# 1. Cross-process sync via PostgreSQL LISTEN/NOTIFY
# 2. Each robot runs as an independent process
# 3. Failover when a process dies
# 4. Dynamic scaling by spawning new processes
#
# Prerequisites:
# 1. Set up examples database: rake examples:setup
# 2. Install dependencies: bundle install
#
# Run via:
#   ruby examples/robot_groups/multi_process.rb

require_relative '../examples_helper'
require 'json'
require 'timeout'
require 'open3'

# =============================================================================
# Robot Process Manager
# =============================================================================

class RobotProcess
  WORKER_SCRIPT = File.expand_path('robot_worker.rb', __dir__)

  attr_reader :name, :pid

  def initialize(name, group_name)
    @name = name
    @group_name = group_name

    # Spawn the worker process
    @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(
      { 'HTM_DATABASE__URL' => ENV['HTM_DATABASE__URL'] },
      'ruby', WORKER_SCRIPT, name, group_name
    )
    @pid = @wait_thread.pid

    # Start thread to read stderr (logs)
    @log_thread = Thread.new do
      @stderr.each_line { |line| print line }
    rescue IOError
      # Pipe closed
    end
  end

  def send_command(cmd, **params)
    command = { cmd: cmd }.merge(params)
    @stdin.puts(command.to_json)
    @stdin.flush

    # Read response, skipping non-JSON lines
    Timeout.timeout(10) do
      loop do
        line = @stdout.gets
        return nil unless line

        line = line.strip
        next if line.empty?
        next unless line.start_with?('{')

        return JSON.parse(line, symbolize_names: true)
      end
    end
  rescue Timeout::Error
    { status: 'error', message: 'timeout' }
  rescue Errno::EPIPE, IOError
    { status: 'error', message: 'pipe closed' }
  rescue JSON::ParserError => e
    { status: 'error', message: "JSON parse error: #{e.message}" }
  end

  def shutdown
    send_command('shutdown')
    sleep 0.2
    cleanup_pipes
    @wait_thread.value
  rescue Errno::EPIPE, IOError
    # Already closed
  end

  def kill!
    Process.kill('TERM', @pid)
    cleanup_pipes
    Process.wait(@pid)
  rescue Errno::ESRCH, Errno::ECHILD
    # Already dead
  end

  def alive?
    @wait_thread && !@wait_thread.stop?
  end

  private

  def cleanup_pipes
    @stdin.close rescue nil
    @stdout.close rescue nil
    @stderr.close rescue nil
    @log_thread.kill rescue nil
  end
end

# =============================================================================
# Demo
# =============================================================================

def run_demo
  puts <<~BANNER
    ╔══════════════════════════════════════════════════════════════╗
    ║     HTM Multi-Process Robot Group Demo                       ║
    ║     Real-time Sync via PostgreSQL LISTEN/NOTIFY              ║
    ╚══════════════════════════════════════════════════════════════╝

  BANNER

  ExamplesHelper.print_environment
  ExamplesHelper.require_database!

  group_name = "demo-#{Time.now.to_i}"
  robots = []

  begin
    # =========================================================================
    # Scenario 1: Start robot processes
    # =========================================================================
    puts '━' * 60
    puts "SCENARIO 1: Starting Robot Processes"
    puts '━' * 60
    puts

    %w[robot-alpha robot-beta robot-gamma].each do |name|
      robots << RobotProcess.new(name, group_name)
    end

    sleep 1.5

    robots.each do |robot|
      result = robot.send_command('ping')
      status = result&.dig(:status) == 'ok' ? '✓' : '✗'
      puts "  #{status} #{robot.name} (PID #{robot.pid})"
    end
    puts

    # =========================================================================
    # Scenario 2: Cross-process memory sharing
    # =========================================================================
    puts '━' * 60
    puts "SCENARIO 2: Cross-Process Memory Sharing"
    puts '━' * 60
    puts
    puts "  Alpha adds memories, others receive notifications..."
    puts

    alpha, beta, gamma = robots

    alpha.send_command('remember', content: 'Customer John Smith prefers morning appointments.')
    sleep 0.5
    alpha.send_command('remember', content: 'Account #A-789 has a pending refund for $150.')
    sleep 0.5
    alpha.send_command('remember', content: 'Escalate billing issues to finance team.')
    sleep 1.0

    puts
    puts "  Working memory status:"
    robots.each do |robot|
      status = robot.send_command('status')
      next unless status&.dig(:status) == 'ok'

      puts "    #{robot.name}: #{status[:working_memory_nodes]} nodes, #{status[:notifications_received]} notifications"
    end
    puts

    # =========================================================================
    # Scenario 3: Collaborative memory
    # =========================================================================
    puts '━' * 60
    puts "SCENARIO 3: Collaborative Memory"
    puts '━' * 60
    puts

    beta.send_command('remember', content: 'Customer confirmed refund was processed.')
    sleep 0.5
    gamma.send_command('remember', content: 'Customer wants email confirmation.')
    sleep 1.0

    puts "  Each robot recalls 'refund':"
    robots.each do |robot|
      result = robot.send_command('recall', query: 'refund', limit: 3)
      next unless result&.dig(:status) == 'ok'

      puts "    #{robot.name}: found #{result[:count]} memories"
    end
    puts

    # =========================================================================
    # Scenario 4: Failover
    # =========================================================================
    puts '━' * 60
    puts "SCENARIO 4: Simulated Failover"
    puts '━' * 60
    puts

    puts "  Killing robot-alpha..."
    alpha.kill!
    robots.delete(alpha)
    sleep 0.5
    puts "  ⚠ robot-alpha terminated"
    puts

    puts "  Remaining robots retain context:"
    robots.each do |robot|
      status = robot.send_command('status')
      result = robot.send_command('recall', query: 'customer', limit: 5)
      next unless status && result

      puts "    #{robot.name}: #{status[:working_memory_nodes]} nodes, recalls #{result[:count]}"
    end
    puts
    puts "  ✓ Failover successful"
    puts

    # =========================================================================
    # Scenario 5: Dynamic scaling
    # =========================================================================
    puts '━' * 60
    puts "SCENARIO 5: Dynamic Scaling"
    puts '━' * 60
    puts

    puts "  Adding robot-delta..."
    delta = RobotProcess.new('robot-delta', group_name)
    robots << delta
    sleep 1.5

    result = delta.send_command('ping')
    puts "  ✓ robot-delta (PID #{delta.pid}) joined" if result&.dig(:status) == 'ok'

    delta.send_command('remember', content: 'New robot ready to assist.')
    sleep 1.0

    puts
    puts "  Notifications received:"
    robots.each do |robot|
      status = robot.send_command('status')
      next unless status&.dig(:status) == 'ok'

      puts "    #{robot.name}: #{status[:notifications_received]}"
    end
    puts

    # =========================================================================
    # Summary
    # =========================================================================
    puts '━' * 60
    puts "DEMO COMPLETE"
    puts '━' * 60
    puts
    puts "  Demonstrated:"
    puts "    • Real-time sync across #{robots.length} processes"
    puts "    • PostgreSQL LISTEN/NOTIFY pub/sub"
    puts "    • Failover with context preservation"
    puts "    • Dynamic scaling"
    puts

  ensure
    puts "Cleaning up..."
    robots.each do |robot|
      next unless robot.alive?

      robot.shutdown
      puts "  Stopped #{robot.name}"
    end
    puts "Done."
  end
end

run_demo if __FILE__ == $PROGRAM_NAME
