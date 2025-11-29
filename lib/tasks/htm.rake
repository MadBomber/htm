# frozen_string_literal: true

# HTM Database Management Tasks
#
# These tasks are available to any application using the HTM gem.
# Add to your application's Rakefile:
#
#   require 'htm/tasks'
#

# Add lib directory to load path for development
# This allows the tasks to work both during gem development and when installed
lib_path = File.expand_path('../../lib', __dir__)
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)

namespace :htm do
  namespace :db do
    desc "Set up HTM database schema and run migrations (set DUMP_SCHEMA=true to auto-dump schema after)"
    task :setup do
      require 'htm'
      dump_schema = ENV['DUMP_SCHEMA'] == 'true'
      HTM::Database.setup(dump_schema: dump_schema)
    end

    desc "Run pending database migrations"
    task :migrate do
      require 'htm'
      HTM::Database.migrate
    end

    desc "Show migration status"
    task :status do
      require 'htm'
      HTM::Database.migration_status
    end

    desc "Drop all HTM tables (WARNING: destructive! Set CONFIRM=yes to skip prompt)"
    task :drop do
      require 'htm'
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
      require 'htm'
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

    desc "Test database connection"
    task :test do
      require 'htm'
      config = HTM::Database.default_config
      raise "Database not configured. Set HTM_DBURL environment variable." unless config

      puts "Testing HTM database connection..."
      puts "  Host: #{config[:host]}"
      puts "  Port: #{config[:port]}"
      puts "  Database: #{config[:dbname]}"
      puts "  User: #{config[:user]}"

      begin
        require 'pg'
        conn = PG.connect(config)

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

    desc "Open PostgreSQL console"
    task :console do
      require 'htm'
      config = HTM::Database.default_config
      raise "Database not configured. Set HTM_DBURL environment variable." unless config

      exec "psql", "-h", config[:host],
                   "-p", config[:port].to_s,
                   "-U", config[:user],
                   "-d", config[:dbname]
    end

    desc "Seed database with sample data"
    task :seed do
      require 'htm'
      HTM::Database.seed
    end

    desc "Show database info (size, tables, extensions)"
    task :info do
      require 'htm'
      HTM::Database.info
    end

    desc "Show record counts for all HTM tables"
    task :stats do
      require 'htm'

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
        require 'htm'
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
        cleared = HTM::Models::Node.where.not(embedding: nil).update_all(embedding: nil, embedding_dimension: nil)
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

            node.update!(
              embedding: result[:storage_embedding],
              embedding_dimension: result[:dimension]
            )
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
    end

    namespace :schema do
      desc "Dump current schema to db/schema.sql"
      task :dump do
        require 'htm'
        HTM::Database.dump_schema
      end

      desc "Load schema from db/schema.sql"
      task :load do
        require 'htm'
        HTM::Database.load_schema
      end
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
      require 'htm'
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

    desc "Generate DB docs, build site, and serve locally"
    task :all => [:db, :build, :serve]
  end
end
