#!/usr/bin/env ruby
# frozen_string_literal: true

# Robot Group Demo - Shared Working Memory & Failover
#
# This example demonstrates an application-level pattern for coordinating
# multiple robots with shared working memory. Key concepts:
#
# 1. **Shared Working Memory**: Multiple robots can share the same working
#    memory by having working_memory=true for the same nodes in robot_nodes.
#
# 2. **Active/Passive Roles**: Active robots participate in conversations;
#    passive robots maintain synchronized context for instant failover.
#
# 3. **Failover**: When an active robot fails, a passive robot can take over
#    with full context already loaded (warm standby).
#
# 4. **Real-time Sync**: PostgreSQL LISTEN/NOTIFY enables real-time
#    synchronization of in-memory working memory across robots.
#
# Prerequisites:
# 1. Set up examples database: rake examples:setup
# 2. Install dependencies: bundle install
#
# Run via:
#   ruby examples/robot_groups/same_process.rb

require_relative '../examples_helper'
require 'json'

# =============================================================================
# Demo Script
# =============================================================================

ExamplesHelper.section "HTM Robot Group Demo - Shared Working Memory & Failover"
ExamplesHelper.print_environment
ExamplesHelper.require_database!

begin
  # Configure HTM
  puts "\n1. Configuring HTM..."
  HTM.configure do |config|
    config.embedding.provider = :ollama
    config.embedding.model = 'nomic-embed-text:latest'
    config.embedding.dimensions = 768
    config.tag.provider = :ollama
    config.tag.model = 'gemma3:latest'
  end
  puts '✓ HTM configured'

  # ---------------------------------------------------------------------------
  # Scenario 1: Create a high-availability robot group
  # ---------------------------------------------------------------------------
  puts "\n2. Creating robot group with primary + standby..."

  group = HTM::RobotGroup.new(
    name: 'customer-support-ha',
    active: ['support-primary'],
    passive: ['support-standby'],
    max_tokens: 8000
  )

  status = group.status
  puts "✓ Group created: #{status[:name]}"
  puts "  Active:  #{status[:active].join(', ')}"
  puts "  Passive: #{status[:passive].join(', ')}"

  # ---------------------------------------------------------------------------
  # Scenario 2: Add shared memories
  # ---------------------------------------------------------------------------
  puts "\n3. Adding memories to shared working memory..."

  group.remember(
    'Customer account #12345 prefers email communication over phone calls.',
    originator: 'support-primary'
  )
  puts '  ✓ Remembered customer preference'

  group.remember(
    'Open ticket #789: Customer reported billing discrepancy on invoice dated Nov 15.',
    originator: 'support-primary'
  )
  puts '  ✓ Remembered open ticket'

  group.remember(
    'Customer has been with us for 5 years and has premium tier subscription.',
    originator: 'support-primary'
  )
  puts '  ✓ Remembered customer status'

  # Brief pause for async jobs
  sleep 0.3

  # ---------------------------------------------------------------------------
  # Scenario 3: Verify synchronization
  # ---------------------------------------------------------------------------
  puts "\n4. Verifying working memory synchronization..."

  status = group.status
  puts "  Working memory nodes: #{status[:working_memory_nodes]}"
  puts "  Token utilization: #{(status[:token_utilization] * 100).round(1)}%"
  puts "  In sync: #{status[:in_sync] ? '✓ Yes' : '✗ No'}"

  # Force sync if needed
  unless status[:in_sync]
    result = group.sync_all
    puts "  Synced #{result[:synced_nodes]} nodes to #{result[:members_updated]} members"
  end

  # ---------------------------------------------------------------------------
  # Scenario 4: Simulate primary robot failure and failover
  # ---------------------------------------------------------------------------
  puts "\n5. Simulating failover scenario..."
  puts "  ⚠ Primary robot 'support-primary' has stopped responding!"

  # Failover to standby
  group.failover!

  status = group.status
  puts "  Active robots now: #{status[:active].join(', ')}"
  puts "  Passive robots now: #{status[:passive].join(', ') || '(none)'}"

  # ---------------------------------------------------------------------------
  # Scenario 5: Verify standby has full context
  # ---------------------------------------------------------------------------
  puts "\n6. Verifying standby has full context after failover..."

  # Use fulltext search (doesn't require embeddings)
  memories = group.recall('customer', limit: 5, strategy: :fulltext, raw: true)
  puts "  ✓ Standby recalled #{memories.length} memories about 'customer'"
  memories.each do |memory|
    content = memory['content'] || memory[:content]
    puts "    - #{content[0..55]}..."
  end

  # ---------------------------------------------------------------------------
  # Scenario 6: Add a new active robot (scaling up)
  # ---------------------------------------------------------------------------
  puts "\n7. Adding a second active robot (scaling up)..."

  group.add_active('support-secondary')
  group.sync_robot('support-secondary')

  status = group.status
  puts "  ✓ Now running with #{status[:active].length} active robots"
  puts "  Active: #{status[:active].join(', ')}"
  puts "  In sync: #{status[:in_sync] ? '✓ Yes' : '✗ No'}"

  # ---------------------------------------------------------------------------
  # Scenario 7: Collaborative memory - both robots can add
  # ---------------------------------------------------------------------------
  puts "\n8. Demonstrating collaborative memory..."

  # This memory is added through the group and synced to all
  group.remember(
    'Customer called again - issue escalated to billing department.',
    originator: 'support-secondary'
  )
  puts '  ✓ Secondary robot added memory, synced to all'

  status = group.status
  puts "  Total shared memories: #{status[:working_memory_nodes]}"

  # ---------------------------------------------------------------------------
  # Scenario 8: Real-time sync via PostgreSQL LISTEN/NOTIFY
  # ---------------------------------------------------------------------------
  puts "\n9. Demonstrating real-time sync via PostgreSQL LISTEN/NOTIFY..."

  # Check initial in-memory state of each robot
  puts '  Initial in-memory working memory state:'
  puts "    support-standby: #{group.instance_variable_get(:@active_robots)['support-standby']&.working_memory&.node_count || 0} nodes"
  puts "    support-secondary: #{group.instance_variable_get(:@active_robots)['support-secondary']&.working_memory&.node_count || 0} nodes"

  # Add a memory from secondary robot
  puts "\n  Adding memory from support-secondary..."
  group.remember(
    'Resolution: Refund issued for $47.50 - billing error confirmed.',
    originator: 'support-secondary'
  )

  # Give the LISTEN/NOTIFY a moment to propagate
  sleep 0.2

  # Check sync stats
  sync_stats = group.sync_stats
  puts "\n  Real-time sync statistics:"
  puts "    Nodes synced via NOTIFY: #{sync_stats[:nodes_synced]}"
  puts "    Evictions synced: #{sync_stats[:evictions_synced]}"
  puts "    Channel notifications received: #{group.channel.notifications_received}"
  puts "    Listener active: #{group.channel.listening? ? '✓ Yes' : '✗ No'}"

  # Verify both robots have the memory in their in-memory cache
  puts "\n  In-memory working memory after sync:"
  group.instance_variable_get(:@active_robots).each do |name, htm|
    puts "    #{name}: #{htm.working_memory.node_count} nodes"
  end

  # ---------------------------------------------------------------------------
  # Summary
  # ---------------------------------------------------------------------------
  puts "\n" + '=' * 60
  puts 'Demo Complete!'
  puts "\nRobotGroup enables:"
  puts '  • Shared working memory across multiple robots'
  puts '  • Instant failover with warm standby (passive robots)'
  puts '  • Collaborative context building'
  puts '  • Dynamic scaling (add/remove robots)'
  puts '  • Real-time sync via PostgreSQL LISTEN/NOTIFY'
  puts "\nFinal group status:"
  status = group.status
  status.each { |k, v| puts "  #{k}: #{v}" }

  # Cleanup
  puts "\nCleaning up..."
  group.clear_working_memory
  group.shutdown
  puts '✓ Cleared shared working memory and stopped listener'
rescue StandardError => e
  puts "\n✗ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  group&.shutdown # Ensure we clean up on error too
  exit 1
end
