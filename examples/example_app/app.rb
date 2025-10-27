# Example HTM Application
#
# This demonstrates a simple application using the HTM gem.

require 'htm'

class ExampleApp
  def self.run
    puts "\n=== HTM Example Application ==="
    puts "\nChecking database connection..."

    # Check if database is configured
    config = HTM::Database.default_config
    unless config
      puts "\n⚠ Database not configured!"
      puts "Set HTM_DBURL environment variable:"
      puts "  export HTM_DBURL='postgresql://user:pass@host:port/dbname'"
      puts "\nOr run: rake app:bootstrap"
      return
    end

    puts "✓ Database configured: #{config[:dbname]} @ #{config[:host]}"

    # Create HTM instance
    puts "\nInitializing HTM..."
    htm = HTM.new(robot_name: "Example App Robot")

    # Add some example memories
    puts "\nAdding example memories..."

    htm.add_node(
      "example_001",
      "HTM provides intelligent memory management for LLM-based applications",
      type: :fact,
      importance: 8.0,
      tags: ["memory", "llm", "ai"]
    )

    htm.add_node(
      "example_002",
      "The two-tier architecture includes working memory and long-term storage",
      type: :fact,
      importance: 7.0,
      tags: ["architecture", "design"]
    )

    puts "✓ Added 2 example memories"

    # Recall memories
    puts "\nRecalling memories about 'memory'..."
    memories = htm.recall(
      timeframe: (Time.now - 3600)..Time.now,
      topic: "memory",
      limit: 5
    )

    puts "Found #{memories.length} memories:"
    memories.each do |memory|
      puts "  - #{memory['key']}: #{memory['value'][0..60]}..."
    end

    # Show statistics
    puts "\nMemory Statistics:"
    stats = htm.memory_stats
    puts "  Working Memory: #{stats[:working_memory_count]} nodes"
    puts "  Long-term Memory: #{stats[:long_term_memory_count]} nodes"
    puts "  Total: #{stats[:total_count]} nodes"

    # Shutdown
    htm.shutdown

    puts "\n✓ Example complete!"
    puts "\nNext steps:"
    puts "  - Run 'rake htm:db:info' to see database details"
    puts "  - Run 'rake htm:db:console' to explore the database"
    puts "  - See examples/basic_usage.rb for more examples"
    puts ""
  end
end

# Run directly if called as script
if __FILE__ == $0
  ExampleApp.run
end
