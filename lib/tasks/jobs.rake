# frozen_string_literal: true

namespace :htm do
  namespace :jobs do
    desc "Show statistics for nodes and async job processing"
    task :stats => :environment do
      require 'htm'

      # Establish connection
      HTM::ActiveRecordConfig.establish_connection!

      puts "HTM Async Job Statistics"
      puts "=" * 60

      # Total nodes
      total_nodes = HTM::Models::Node.count
      puts "Total nodes: #{total_nodes}"

      # Nodes with embeddings
      with_embeddings = HTM::Models::Node.where.not(embedding: nil).count
      puts "Nodes with embeddings: #{with_embeddings} (#{percentage(with_embeddings, total_nodes)}%)"

      # Nodes without embeddings (pending embedding jobs)
      without_embeddings = HTM::Models::Node.where(embedding: nil).count
      puts "Nodes without embeddings: #{without_embeddings} (#{percentage(without_embeddings, total_nodes)}%)"

      # Nodes with tags
      nodes_with_tags = HTM::Models::Node
        .joins(:node_tags)
        .distinct
        .count
      puts "Nodes with tags: #{nodes_with_tags} (#{percentage(nodes_with_tags, total_nodes)}%)"

      # Nodes without tags
      nodes_without_tags = total_nodes - nodes_with_tags
      puts "Nodes without tags: #{nodes_without_tags} (#{percentage(nodes_without_tags, total_nodes)}%)"

      # Total tags
      total_tags = HTM::Models::Tag.count
      puts "\nTotal tags in ontology: #{total_tags}"

      # Tags by depth
      if total_tags > 0
        puts "\nTag hierarchy breakdown:"
        depth_counts = Hash.new(0)
        HTM::Models::Tag.pluck(:name).each do |name|
          depth = name.count(':')
          depth_counts[depth] += 1
        end
        depth_counts.keys.sort.each do |depth|
          puts "  Depth #{depth}: #{depth_counts[depth]} tags"
        end
      end

      # Average tags per node
      if nodes_with_tags > 0
        avg_tags = HTM::Models::NodeTag.count.to_f / nodes_with_tags
        puts "\nAverage tags per node: #{avg_tags.round(2)}"
      end

      HTM::ActiveRecordConfig.disconnect!
    end

    desc "Process pending embedding jobs for nodes without embeddings"
    task :process_embeddings => :environment do
      require 'htm'

      # Establish connection and configure HTM
      HTM::ActiveRecordConfig.establish_connection!
      HTM.configure  # Use default configuration

      # Find nodes without embeddings
      pending_nodes = HTM::Models::Node.where(embedding: nil)
      total = pending_nodes.count

      if total.zero?
        puts "No pending embedding jobs"
        HTM::ActiveRecordConfig.disconnect!
        exit 0
      end

      puts "Processing #{total} pending embedding jobs..."

      processed = 0
      failed = 0

      pending_nodes.find_each do |node|
        begin
          # Use the service class directly (same as job)
          result = HTM::EmbeddingService.generate(node.content)
          node.update!(embedding: result[:storage_embedding])
          processed += 1
          print "\rProcessed: #{processed}/#{total}"
        rescue StandardError => e
          failed += 1
          HTM.logger.error "Failed to process node #{node.id}: #{e.message}"
        end
      end

      puts "\n\nCompleted:"
      puts "  Processed: #{processed}"
      puts "  Failed: #{failed}"

      HTM::ActiveRecordConfig.disconnect!
    end

    desc "Process pending tag extraction jobs for nodes without tags"
    task :process_tags => :environment do
      require 'htm'

      # Establish connection and configure HTM
      HTM::ActiveRecordConfig.establish_connection!
      HTM.configure  # Use default configuration

      # Find nodes without any tags
      nodes_without_tags = HTM::Models::Node
        .left_joins(:node_tags)
        .where(node_tags: { id: nil })

      total = nodes_without_tags.count

      if total.zero?
        puts "No pending tag extraction jobs"
        HTM::ActiveRecordConfig.disconnect!
        exit 0
      end

      puts "Processing #{total} pending tag extraction jobs..."

      processed = 0
      failed = 0

      nodes_without_tags.find_each do |node|
        begin
          # Use the service class directly (same as job)
          existing_ontology = HTM::Models::Tag.order(created_at: :desc).limit(100).pluck(:name)
          tag_names = HTM::TagService.extract(node.content, existing_ontology: existing_ontology)

          tag_names.each do |tag_name|
            tag = HTM::Models::Tag.find_or_create_by!(name: tag_name)
            HTM::Models::NodeTag.find_or_create_by!(node_id: node.id, tag_id: tag.id)
          end

          processed += 1
          print "\rProcessed: #{processed}/#{total}"
        rescue StandardError => e
          failed += 1
          HTM.logger.error "Failed to process node #{node.id}: #{e.message}"
        end
      end

      puts "\n\nCompleted:"
      puts "  Processed: #{processed}"
      puts "  Failed: #{failed}"

      HTM::ActiveRecordConfig.disconnect!
    end

    desc "Process all pending jobs (embeddings and tags)"
    task :process_all => [:process_embeddings, :process_tags] do
      puts "\nAll pending jobs processed!"
    end

    desc "Reprocess embeddings for all nodes (force regeneration)"
    task :reprocess_embeddings => :environment do
      require 'htm'

      print "This will regenerate embeddings for ALL nodes. Are you sure? (yes/no): "
      confirmation = $stdin.gets.chomp

      unless confirmation.downcase == 'yes'
        puts "Cancelled."
        exit 0
      end

      # Establish connection and configure HTM
      HTM::ActiveRecordConfig.establish_connection!
      HTM.configure  # Use default configuration

      total = HTM::Models::Node.count

      puts "Reprocessing embeddings for #{total} nodes..."

      processed = 0
      failed = 0

      HTM::Models::Node.find_each do |node|
        begin
          # Use the service class directly to regenerate
          result = HTM::EmbeddingService.generate(node.content)
          node.update!(embedding: result[:storage_embedding])
          processed += 1
          print "\rProcessed: #{processed}/#{total}"
        rescue StandardError => e
          failed += 1
          HTM.logger.error "Failed to reprocess node #{node.id}: #{e.message}"
        end
      end

      puts "\n\nCompleted:"
      puts "  Processed: #{processed}"
      puts "  Failed: #{failed}"

      HTM::ActiveRecordConfig.disconnect!
    end

    desc "Show nodes that failed async processing"
    task :failed => :environment do
      require 'htm'

      HTM::ActiveRecordConfig.establish_connection!

      puts "Nodes with Processing Issues"
      puts "=" * 60

      # Old nodes without embeddings (created more than 1 hour ago)
      old_without_embeddings = HTM::Models::Node
        .where(embedding: nil)
        .where('created_at < ?', 1.hour.ago)

      if old_without_embeddings.any?
        puts "\nNodes without embeddings (>1 hour old):"
        old_without_embeddings.limit(10).each do |node|
          puts "  Node #{node.id}: created #{time_ago(node.created_at)}"
        end

        if old_without_embeddings.count > 10
          puts "  ... and #{old_without_embeddings.count - 10} more"
        end
      else
        puts "\n✓ No old nodes without embeddings"
      end

      # Old nodes without tags
      old_without_tags = HTM::Models::Node
        .left_joins(:node_tags)
        .where(node_tags: { id: nil })
        .where('nodes.created_at < ?', 1.hour.ago)

      if old_without_tags.any?
        puts "\nNodes without tags (>1 hour old):"
        old_without_tags.limit(10).each do |node|
          puts "  Node #{node.id}: created #{time_ago(node.created_at)}"
        end

        if old_without_tags.count > 10
          puts "  ... and #{old_without_tags.count - 10} more"
        end
      else
        puts "\n✓ No old nodes without tags"
      end

      HTM::ActiveRecordConfig.disconnect!
    end

    desc "Clear all embeddings and tags (for testing/development)"
    task :clear_all => :environment do
      require 'htm'

      print "This will clear ALL embeddings and tags. Are you sure? (yes/no): "
      confirmation = $stdin.gets.chomp

      unless confirmation.downcase == 'yes'
        puts "Cancelled."
        exit 0
      end

      HTM::ActiveRecordConfig.establish_connection!

      puts "Clearing embeddings..."
      HTM::Models::Node.update_all(embedding: nil)

      puts "Clearing tags..."
      HTM::Models::NodeTag.delete_all
      HTM::Models::Tag.delete_all

      puts "Done! All embeddings and tags cleared."

      HTM::ActiveRecordConfig.disconnect!
    end

    # Helper methods
    def percentage(part, whole)
      return 0 if whole.zero?
      ((part.to_f / whole) * 100).round(1)
    end

    def time_ago(time)
      seconds = Time.now - time
      case seconds
      when 0..59
        "#{seconds.to_i} seconds ago"
      when 60..3599
        "#{(seconds / 60).to_i} minutes ago"
      when 3600..86399
        "#{(seconds / 3600).to_i} hours ago"
      else
        "#{(seconds / 86400).to_i} days ago"
      end
    end
  end
end

# Add :environment task if not already defined (for standalone usage)
unless Rake::Task.task_defined?(:environment)
  task :environment do
    # No-op for standalone usage
    # Applications can override this to set up their environment
  end
end
