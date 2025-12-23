# frozen_string_literal: true

# HTM Database Management Tasks
#
# These tasks are available to any application using the HTM gem.
# Add to your application's Rakefile:
#
#   require 'htm/tasks'
#

namespace :htm do
  namespace :db do
    # Note: Database configuration validation (environment, URL/component reconciliation,
    # naming convention) happens automatically when HTM is required above.

    desc "Set up HTM database schema and run migrations (set DUMP_SCHEMA=true to auto-dump schema after)"
    task :setup do
      dump_schema = ENV['DUMP_SCHEMA'] == 'true'
      HTM::Database.setup(dump_schema: dump_schema)
    end

    desc "Run pending database migrations"
    task :migrate do
      HTM::Database.migrate
    end

    desc "Show migration status"
    task :status do
      HTM::Database.migration_status
    end

    desc "Drop all HTM tables (WARNING: destructive! Set CONFIRM=yes to skip prompt)"
    task :drop do
      if ENV['CONFIRM'] == 'yes'
        HTM::Database.drop
      else
        print "Are you sure you want to drop all tables? This cannot be undone! (yes/no): "
        response = STDIN.gets&.chomp
        if response&.downcase == 'yes'
          HTM::Database.drop
        else
          puts "Cancelled."
        end
      end
    end

    desc "Drop and recreate database (WARNING: destructive! Set CONFIRM=yes to skip prompt)"
    task :reset do
      if ENV['CONFIRM'] == 'yes'
        HTM::Database.drop
        HTM::Database.setup(dump_schema: true)
      else
        print "Are you sure you want to drop all tables? This cannot be undone! (yes/no): "
        response = STDIN.gets&.chomp
        if response&.downcase == 'yes'
          HTM::Database.drop
          HTM::Database.setup(dump_schema: true)
        else
          puts "Cancelled."
        end
      end
    end

    desc "Verify database connection (respects HTM_ENV/RAILS_ENV)"
    task :verify do
      config = HTM::ActiveRecordConfig.load_database_config

      puts "Verifying HTM database connection (#{HTM.env})..."
      puts "  Host: #{config[:host]}"
      puts "  Port: #{config[:port]}"
      puts "  Database: #{config[:database]}"
      puts "  User: #{config[:username]}"

      begin
        require 'pg'
        conn = PG.connect(
          host: config[:host],
          port: config[:port],
          dbname: config[:database],
          user: config[:username],
          password: config[:password]
        )

        # Check pgvector
        pgvector = conn.exec("SELECT extversion FROM pg_extension WHERE extname='vector'").first
        if pgvector
          puts "  ✓ pgvector version: #{pgvector['extversion']}"
        else
          puts "  ⚠ Warning: pgvector extension not found"
        end

        conn.close
        puts "✓ Connection successful!"
      rescue PG::Error => e
        puts "✗ Connection failed: #{e.message}"
        exit 1
      end
    end

    desc "Open PostgreSQL console (respects HTM_ENV/RAILS_ENV)"
    task :console do
      config = HTM::ActiveRecordConfig.load_database_config

      puts "Connecting to #{config[:database]} (#{HTM.env})..."
      exec "psql", "-h", config[:host],
                   "-p", config[:port].to_s,
                   "-U", config[:username],
                   "-d", config[:database]
    end

    desc "Seed database with sample data"
    task :seed do
      HTM::Database.seed
    end

    desc "Show database info (size, tables, extensions)"
    task :info do
      HTM::Database.info
    end

    desc "Show record counts for all HTM tables"
    task :stats do
      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      puts "\nHTM Database Statistics"
      puts "=" * 50

      # Define tables with their models and optional extra info
      tables = [
        { name: 'robots', model: HTM::Models::Robot },
        { name: 'nodes', model: HTM::Models::Node, extras: ->(m) {
          # Node uses default_scope for active nodes, so m.count is active count
          active = m.count
          deleted = m.deleted.count
          with_embedding = m.where.not(embedding: nil).count
          "  (active: #{active}, deleted: #{deleted}, with embeddings: #{with_embedding})"
        }},
        { name: 'tags', model: HTM::Models::Tag },
        { name: 'nodes_tags', model: HTM::Models::NodeTag },
        { name: 'file_sources', model: HTM::Models::FileSource }
      ]

      total = 0
      max_name_len = tables.map { |t| t[:name].length }.max

      tables.each do |table|
        count = table[:model].count
        total += count
        extras = table[:extras] ? table[:extras].call(table[:model]) : ''

        printf "  %-#{max_name_len}s  %8d%s\n", table[:name], count, extras
      end

      puts "-" * 50
      printf "  %-#{max_name_len}s  %8d\n", "Total", total

      # Additional stats
      puts "\nAdditional Statistics:"

      # Nodes per robot (via robot_nodes join table)
      robot_counts = HTM::Models::RobotNode
        .joins(:node)
        .where(nodes: { deleted_at: nil })
        .group(:robot_id)
        .count
        .transform_keys { |id| HTM::Models::Robot.find(id).name rescue "Unknown (#{id})" }
        .sort_by { |_, count| -count }
        .first(5)

      if robot_counts.any?
        puts "  Top robots by node count:"
        robot_counts.each do |name, count|
          puts "    #{name}: #{count}"
        end
      end

      # Tag distribution
      top_root_tags = HTM::Models::Tag
        .select("split_part(name, ':', 1) as root, count(*) as cnt")
        .group("split_part(name, ':', 1)")
        .order("cnt DESC")
        .limit(5)
        .map { |t| [t.root, t.cnt] }

      if top_root_tags.any?
        puts "  Top root tag categories:"
        top_root_tags.each do |root, count|
          puts "    #{root}: #{count}"
        end
      end

      puts
    end

    namespace :rebuild do
      desc "Rebuild embeddings for all nodes. Clears existing embeddings and regenerates via LLM."
      task :embeddings do
        require 'ruby-progressbar'

        # Ensure database connection
        HTM::ActiveRecordConfig.establish_connection!

        # Node uses default_scope for active (non-deleted) nodes
        node_count = HTM::Models::Node.count
        with_embeddings = HTM::Models::Node.where.not(embedding: nil).count
        without_embeddings = node_count - with_embeddings

        puts "\nHTM Embeddings Rebuild"
        puts "=" * 50
        puts "Current state:"
        puts "  Total active nodes: #{node_count}"
        puts "  With embeddings: #{with_embeddings}"
        puts "  Without embeddings: #{without_embeddings}"
        puts "\nThis will regenerate embeddings for ALL #{node_count} nodes."
        puts "This operation may take a long time depending on your LLM provider."
        print "\nType 'yes' to confirm: "

        confirmation = $stdin.gets&.strip
        unless confirmation == 'yes'
          puts "Aborted."
          next
        end

        puts "\nClearing existing embeddings..."
        cleared = HTM::Models::Node.where.not(embedding: nil).update_all(embedding: nil)
        puts "  Cleared #{cleared} embeddings"

        puts "\nGenerating embeddings for #{node_count} nodes..."
        puts "(This may take a while depending on your LLM provider)\n"

        # Create progress bar with ETA
        progressbar = ProgressBar.create(
          total: node_count,
          format: '%t: |%B| %c/%C (%p%%) %e',
          title: 'Embedding',
          output: $stdout,
          smoothing: 0.5
        )

        # Process each active node (default_scope excludes deleted)
        errors = 0
        success = 0

        HTM::Models::Node.find_each do |node|
          begin
            # Generate embedding directly (not via job since we cleared them)
            result = HTM::EmbeddingService.generate(node.content)

            node.update!(embedding: result[:storage_embedding])
            success += 1
          rescue StandardError => e
            errors += 1
            progressbar.log "  Error on node #{node.id}: #{e.message}"
          end

          progressbar.increment
        end

        progressbar.finish

        # Final stats
        final_with_embeddings = HTM::Models::Node.where.not(embedding: nil).count

        puts "\nRebuild complete!"
        puts "  Nodes processed: #{node_count}"
        puts "  Successful: #{success}"
        puts "  Errors: #{errors}"
        puts "  Nodes with embeddings: #{final_with_embeddings}"
      end

      desc "Rebuild propositions for all non-proposition nodes. Extracts atomic facts and creates new nodes."
      task :propositions do
        require 'ruby-progressbar'

        # Ensure database connection
        HTM::ActiveRecordConfig.establish_connection!

        # Find all non-proposition nodes (nodes that haven't been extracted from)
        source_nodes = HTM::Models::Node.non_propositions
        source_count = source_nodes.count

        # Count existing proposition nodes
        existing_propositions = HTM::Models::Node.propositions.count

        puts "\nHTM Propositions Rebuild"
        puts "=" * 50
        puts "Current state:"
        puts "  Source nodes (non-propositions): #{source_count}"
        puts "  Existing proposition nodes: #{existing_propositions}"
        puts "\nThis will extract propositions from ALL #{source_count} source nodes."
        puts "Existing proposition nodes will be deleted and regenerated."
        puts "This operation may take a long time depending on your LLM provider."
        print "\nType 'yes' to confirm: "

        confirmation = $stdin.gets&.strip
        unless confirmation == 'yes'
          puts "Aborted."
          next
        end

        # Delete existing proposition nodes
        if existing_propositions > 0
          puts "\nDeleting #{existing_propositions} existing proposition nodes..."
          deleted = HTM::Models::Node.propositions.delete_all
          puts "  Deleted #{deleted} proposition nodes"
        end

        puts "\nExtracting propositions from #{source_count} nodes..."
        puts "(This may take a while depending on your LLM provider)\n"

        # Get a robot ID for linking proposition nodes
        # Use the first robot or create a system robot
        robot = HTM::Models::Robot.first || HTM::Models::Robot.create!(name: 'proposition_rebuilder')

        # Create progress bar with ETA
        progressbar = ProgressBar.create(
          total: source_count,
          format: '%t: |%B| %c/%C (%p%%) %e',
          title: 'Extracting',
          output: $stdout,
          smoothing: 0.5
        )

        # Track stats
        errors = 0
        nodes_processed = 0
        propositions_created = 0

        source_nodes.find_each do |node|
          begin
            # Extract propositions
            propositions = HTM::PropositionService.extract(node.content)

            if propositions.any?
              propositions.each do |proposition_text|
                token_count = HTM.count_tokens(proposition_text)

                # Create proposition node
                prop_node = HTM::Models::Node.create!(
                  content: proposition_text,
                  token_count: token_count,
                  metadata: { is_proposition: true, source_node_id: node.id }
                )

                # Link to robot
                HTM::Models::RobotNode.find_or_create_by!(
                  robot_id: robot.id,
                  node_id: prop_node.id
                )

                # Generate embedding for proposition node
                begin
                  result = HTM::EmbeddingService.generate(proposition_text)
                  prop_node.update!(embedding: result[:storage_embedding])
                rescue StandardError => e
                  progressbar.log "  Warning: Embedding failed for proposition: #{e.message}"
                end

                propositions_created += 1
              end
            end

            nodes_processed += 1
          rescue StandardError => e
            errors += 1
            progressbar.log "  Error on node #{node.id}: #{e.message}"
          end

          progressbar.increment
        end

        progressbar.finish

        # Final stats
        final_proposition_count = HTM::Models::Node.propositions.count

        puts "\nRebuild complete!"
        puts "  Source nodes processed: #{nodes_processed}"
        puts "  Propositions created: #{propositions_created}"
        puts "  Errors: #{errors}"
        puts "  Total proposition nodes: #{final_proposition_count}"
      end
    end

    namespace :schema do
      desc "Dump current schema to db/schema.sql"
      task :dump do
        HTM::Database.dump_schema
      end

      desc "Load schema from db/schema.sql"
      task :load do
        HTM::Database.load_schema
      end
    end

    desc "Create database if it doesn't exist (respects HTM_ENV/RAILS_ENV)"
    task :create do
      config = HTM::ActiveRecordConfig.load_database_config
      db_name = config[:database]

      puts "Creating database: #{db_name} (#{HTM.env})"

      admin_config = config.dup
      admin_config[:database] = 'postgres'

      begin
        require 'pg'
        admin_conn = PG.connect(
          host: admin_config[:host],
          port: admin_config[:port],
          dbname: admin_config[:database],
          user: admin_config[:username],
          password: admin_config[:password]
        )

        result = admin_conn.exec_params(
          "SELECT 1 FROM pg_database WHERE datname = $1",
          [db_name]
        )

        if result.ntuples == 0
          admin_conn.exec("CREATE DATABASE #{PG::Connection.quote_ident(db_name)}")
          puts "✓ Database created: #{db_name}"

          # Connect to new database and enable extensions
          db_conn = PG.connect(
            host: config[:host],
            port: config[:port],
            dbname: db_name,
            user: config[:username],
            password: config[:password]
          )
          %w[vector pg_trgm].each do |ext|
            db_conn.exec("CREATE EXTENSION IF NOT EXISTS #{ext}")
          end
          db_conn.close
          puts "✓ Extensions enabled (pgvector, pg_trgm)"
        else
          puts "✓ Database already exists: #{db_name}"
        end

        admin_conn.close
      rescue PG::Error => e
        puts "✗ Error: #{e.message}"
        exit 1
      end
    end

    namespace :tags do
      desc "Soft delete orphaned tags and stale node_tags entries"
      task :cleanup do
        # Ensure database connection
        HTM::ActiveRecordConfig.establish_connection!

        puts "\nHTM Tag Cleanup"
        puts "=" * 50

        # Step 1: Find active node_tags pointing to soft-deleted or missing nodes
        stale_node_tags = HTM::Models::NodeTag
          .joins("LEFT JOIN nodes ON nodes.id = node_tags.node_id")
          .where("nodes.id IS NULL OR nodes.deleted_at IS NOT NULL")

        stale_count = stale_node_tags.count

        # Step 2: Find orphaned tags using the Tag.orphaned scope
        orphaned_tags = HTM::Models::Tag.orphaned
        orphan_count = orphaned_tags.count

        if stale_count == 0 && orphan_count == 0
          puts "No cleanup needed."
          puts "  Stale node_tags entries: 0"
          puts "  Orphaned tags: 0"
          next
        end

        puts "Found:"
        puts "  Stale node_tags entries: #{stale_count} (pointing to deleted/missing nodes)"
        puts "  Orphaned tags: #{orphan_count} (no active nodes)"

        if orphan_count > 0
          puts "\nOrphaned tags:"
          orphaned_tags.limit(20).pluck(:name).each do |name|
            puts "  - #{name}"
          end
          puts "  ... and #{orphan_count - 20} more" if orphan_count > 20
        end

        print "\nSoft delete these entries? (yes/no): "
        confirmation = $stdin.gets&.strip

        unless confirmation == 'yes'
          puts "Cancelled."
          next
        end

        now = Time.current

        # Soft delete stale node_tags first
        if stale_count > 0
          soft_deleted_node_tags = stale_node_tags.update_all(deleted_at: now)
          puts "\nSoft deleted #{soft_deleted_node_tags} stale node_tags entries."
        end

        # Then soft delete orphaned tags
        if orphan_count > 0
          soft_deleted_tags = orphaned_tags.update_all(deleted_at: now)
          puts "Soft deleted #{soft_deleted_tags} orphaned tags."
        end

        puts "\nCleanup complete (soft delete)."
      end
    end

    desc "Permanently delete all soft-deleted records from all tables (WARNING: irreversible!)"
    task :purge_all do
      # Ensure database connection
      HTM::ActiveRecordConfig.establish_connection!

      puts "\nHTM Purge All Soft-Deleted Records"
      puts "=" * 60

      # Count soft-deleted records in each table
      deleted_nodes = HTM::Models::Node.deleted.count
      deleted_node_tags = HTM::Models::NodeTag.deleted.count
      deleted_robot_nodes = HTM::Models::RobotNode.deleted.count

      # Find orphaned propositions (source_node_id no longer exists)
      # Get all source_node_ids from propositions
      proposition_source_ids = HTM::Models::Node
        .where("metadata->>'is_proposition' = ?", 'true')
        .where("metadata->>'source_node_id' IS NOT NULL")
        .pluck(Arel.sql("(metadata->>'source_node_id')::integer"))
        .uniq

      # Find which source nodes no longer exist (not even soft-deleted)
      existing_node_ids = HTM::Models::Node.unscoped
        .where(id: proposition_source_ids)
        .pluck(:id)

      missing_source_ids = proposition_source_ids - existing_node_ids

      orphaned_propositions = if missing_source_ids.any?
        HTM::Models::Node
          .where("metadata->>'is_proposition' = ?", 'true')
          .where("(metadata->>'source_node_id')::integer IN (?)", missing_source_ids)
          .count
      else
        0
      end

      # Find orphaned join table entries (pointing to non-existent nodes)
      orphaned_node_tags = HTM::Models::NodeTag.unscoped
        .joins("LEFT JOIN nodes ON nodes.id = node_tags.node_id")
        .where("nodes.id IS NULL")
        .count

      orphaned_robot_nodes = HTM::Models::RobotNode.unscoped
        .joins("LEFT JOIN nodes ON nodes.id = robot_nodes.node_id")
        .where("nodes.id IS NULL")
        .count

      # Find orphaned robots (no active memory nodes)
      orphaned_robots = HTM::Models::Robot
        .left_joins(:robot_nodes)
        .where(robot_nodes: { id: nil })
        .count

      # Display record counts by table
      puts "\nSoft-deleted records by table:"
      puts "  %-20s %8d" % ['nodes', deleted_nodes]
      puts "  %-20s %8d" % ['node_tags', deleted_node_tags]
      puts "  %-20s %8d" % ['robot_nodes', deleted_robot_nodes]

      puts "\nOrphaned records:"
      puts "  %-20s %8d  (source node no longer exists)" % ['propositions', orphaned_propositions]
      puts "  %-20s %8d  (pointing to missing nodes)" % ['node_tags', orphaned_node_tags]
      puts "  %-20s %8d  (pointing to missing nodes)" % ['robot_nodes', orphaned_robot_nodes]
      puts "  %-20s %8d  (no associated memory nodes)" % ['robots', orphaned_robots]

      total_to_delete = deleted_nodes + deleted_node_tags + deleted_robot_nodes +
                        orphaned_propositions + orphaned_node_tags + orphaned_robot_nodes + orphaned_robots

      puts "  " + "-" * 40
      puts "  %-20s %8d" % ['Total', total_to_delete]

      if total_to_delete == 0
        puts "\nNo records to purge."
        next
      end

      puts "\nWARNING: This permanently deletes records and cannot be undone!"
      print "Type 'yes' to continue with hard delete: "
      confirmation = $stdin.gets&.strip

      unless confirmation == 'yes'
        puts "Cancelled."
        next
      end

      puts "\nPurging records..."

      purged = {}

      # Delete in correct order to maintain referential integrity:
      # 1. Orphaned propositions first (creates orphaned join table entries)
      # 2. Join tables (node_tags, robot_nodes)
      # 3. Main tables last (nodes, robots)

      # Step 1: Delete orphaned propositions (source_node_id no longer exists)
      if missing_source_ids.any?
        purged[:orphaned_propositions] = HTM::Models::Node
          .where("metadata->>'is_proposition' = ?", 'true')
          .where("(metadata->>'source_node_id')::integer IN (?)", missing_source_ids)
          .delete_all
      else
        purged[:orphaned_propositions] = 0
      end

      # Step 2: Delete orphaned node_tags (pointing to non-existent nodes)
      # This now includes entries from deleted propositions
      purged[:orphaned_node_tags] = HTM::Models::NodeTag.unscoped
        .joins("LEFT JOIN nodes ON nodes.id = node_tags.node_id")
        .where("nodes.id IS NULL")
        .delete_all

      # Step 3: Delete soft-deleted node_tags
      purged[:deleted_node_tags] = HTM::Models::NodeTag.deleted.delete_all

      # Step 4: Delete orphaned robot_nodes (pointing to non-existent nodes)
      # This now includes entries from deleted propositions
      purged[:orphaned_robot_nodes] = HTM::Models::RobotNode.unscoped
        .joins("LEFT JOIN nodes ON nodes.id = robot_nodes.node_id")
        .where("nodes.id IS NULL")
        .delete_all

      # Step 5: Delete soft-deleted robot_nodes
      purged[:deleted_robot_nodes] = HTM::Models::RobotNode.deleted.delete_all

      # Step 6: Delete soft-deleted nodes
      purged[:deleted_nodes] = HTM::Models::Node.deleted.delete_all

      # Step 7: Delete orphaned robots (no associated memory nodes)
      purged[:orphaned_robots] = HTM::Models::Robot
        .left_joins(:robot_nodes)
        .where(robot_nodes: { id: nil })
        .delete_all

      puts "\nPurge complete!"
      puts "  Orphaned propositions purged: #{purged[:orphaned_propositions]}"
      puts "  Orphaned node_tags purged:    #{purged[:orphaned_node_tags]}"
      puts "  Deleted node_tags purged:     #{purged[:deleted_node_tags]}"
      puts "  Orphaned robot_nodes purged:  #{purged[:orphaned_robot_nodes]}"
      puts "  Deleted robot_nodes purged:   #{purged[:deleted_robot_nodes]}"
      puts "  Deleted nodes purged:         #{purged[:deleted_nodes]}"
      puts "  Orphaned robots purged:       #{purged[:orphaned_robots]}"
      puts "  " + "-" * 40
      puts "  Total records purged:         #{purged.values.sum}"
    end

  end

  namespace :doc do
    desc "Generate/update database documentation in docs/database/ (uses .tbls.yml)"
    task :db do
      unless system("which tbls > /dev/null 2>&1")
        puts "Error: 'tbls' is not installed."
        puts "Install it with: brew install tbls"
        exit 1
      end
      HTM::Database.generate_docs
    end

    desc "Build documentation site with MkDocs"
    task :build do
      unless system("which mkdocs > /dev/null 2>&1")
        puts "Error: 'mkdocs' is not installed."
        puts "Install it with: brew install mkdocs"
        exit 1
      end
      sh "mkdocs build"
    end

    desc "Serve documentation site locally with MkDocs"
    task :serve do
      unless system("which mkdocs > /dev/null 2>&1")
        puts "Error: 'mkdocs' is not installed."
        puts "Install it with: brew install mkdocs"
        exit 1
      end
      sh "mkdocs serve"
    end

    desc "Generate DB docs, YARD API docs, build site, and serve locally"
    task :all => [:db, :yard, :build, :serve]
  end
end
