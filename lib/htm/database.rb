# frozen_string_literal: true

require 'pg'
require 'uri'
require 'set'

class HTM
  # Database setup and configuration for HTM
  # Handles schema creation and TimescaleDB hypertable setup
  class Database
    class << self
      # Set up the HTM database schema
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @param run_migrations [Boolean] Whether to run migrations (default: true)
      # @return [void]
      #
      def setup(db_url = nil, run_migrations: true)
        config = parse_connection_url(db_url || ENV['HTM_DBURL'])

        raise "Database configuration not found. Please source ~/.bashrc__tiger" unless config

        conn = PG.connect(config)

        # Verify TimescaleDB is available
        verify_extensions(conn)

        # Run schema
        run_schema(conn)

        # Run migrations if requested
        run_migrations_if_needed(conn) if run_migrations

        # Convert tables to hypertables for time-series optimization
        setup_hypertables(conn)

        conn.close
        puts "✓ HTM database schema created successfully"
      end

      # Run pending database migrations
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def migrate(db_url = nil)
        config = parse_connection_url(db_url || ENV['HTM_DBURL'])

        raise "Database configuration not found. Please source ~/.bashrc__tiger" unless config

        conn = PG.connect(config)

        run_migrations_if_needed(conn)

        conn.close
        puts "✓ Database migrations completed"
      end

      # Show migration status
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def migration_status(db_url = nil)
        config = parse_connection_url(db_url || ENV['HTM_DBURL'])
        raise "Database configuration not found" unless config

        conn = PG.connect(config)

        # Get applied migrations
        begin
          applied = conn.exec("SELECT version, applied_at FROM schema_migrations ORDER BY applied_at").to_a
        rescue PG::UndefinedTable
          applied = []
        end

        # Get available migrations
        migrations_dir = File.expand_path('../../sql/migrations', __dir__)
        available = if Dir.exist?(migrations_dir)
          Dir.glob(File.join(migrations_dir, '*.sql')).map { |f| File.basename(f, '.sql') }.sort
        else
          []
        end

        conn.close

        puts "\nMigration Status"
        puts "=" * 80

        if available.empty?
          puts "No migration files found in sql/migrations/"
        else
          available.each do |version|
            status = applied.any? { |a| a['version'] == version }
            status_mark = status ? "✓" : "✗"
            applied_at = applied.find { |a| a['version'] == version }&.dig('applied_at')

            print "#{status_mark} #{version}"
            print " (applied: #{applied_at})" if applied_at
            puts
          end
        end

        puts "\nSummary: #{applied.length} applied, #{available.length - applied.length} pending"
        puts "=" * 80
      end

      # Drop all HTM tables
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def drop(db_url = nil)
        config = parse_connection_url(db_url || ENV['HTM_DBURL'])
        raise "Database configuration not found" unless config

        conn = PG.connect(config)

        tables = ['nodes', 'tags', 'robots', 'operations_log', 'schema_migrations']

        puts "Dropping HTM tables..."
        tables.each do |table|
          begin
            conn.exec("DROP TABLE IF EXISTS #{table} CASCADE")
            puts "  ✓ Dropped #{table}"
          rescue PG::Error => e
            puts "  ✗ Error dropping #{table}: #{e.message}"
          end
        end

        # Drop functions and triggers
        begin
          conn.exec("DROP FUNCTION IF EXISTS extract_ontology_topics() CASCADE")
          puts "  ✓ Dropped ontology functions and triggers"
        rescue PG::Error => e
          puts "  ✗ Error dropping functions: #{e.message}"
        end

        # Drop views
        begin
          conn.exec("DROP VIEW IF EXISTS ontology_structure CASCADE")
          conn.exec("DROP VIEW IF EXISTS topic_relationships CASCADE")
          puts "  ✓ Dropped ontology views"
        rescue PG::Error => e
          puts "  ✗ Error dropping views: #{e.message}"
        end

        conn.close
        puts "✓ All HTM tables dropped"
      end

      # Seed database with sample data
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def seed(db_url = nil)
        require_relative '../htm'

        puts "Seeding database with sample data..."
        puts "Note: This requires Ollama to be accessible from your database server."
        puts "      For cloud databases, ensure Ollama endpoint is publicly reachable."
        puts

        # Use real HTM initialization with actual EmbeddingService
        # Embeddings will be generated by database triggers via pgai
        htm = HTM.new(
          robot_name: "Sample Robot"
        )

        # Add sample nodes
        puts "  Creating sample nodes..."

        htm.add_node(
          "sample_001",
          "PostgreSQL with TimescaleDB provides efficient time-series data storage",
          type: :fact,
          importance: 8.0,
          tags: ["database", "timescaledb"]
        )

        htm.add_node(
          "sample_002",
          "Machine learning models require large amounts of training data",
          type: :fact,
          importance: 7.0,
          tags: ["ai", "machine-learning"]
        )

        htm.add_node(
          "sample_003",
          "Ruby on Rails is a web framework for building database-backed applications",
          type: :fact,
          importance: 6.0,
          tags: ["ruby", "web-development"]
        )

        htm.shutdown

        puts "✓ Database seeded with 3 sample nodes"
      end

      # Show database info
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def info(db_url = nil)
        config = parse_connection_url(db_url || ENV['HTM_DBURL'])
        raise "Database configuration not found" unless config

        conn = PG.connect(config)

        puts "\nHTM Database Information"
        puts "=" * 80

        # Connection info
        puts "\nConnection:"
        puts "  Host: #{config[:host]}"
        puts "  Port: #{config[:port]}"
        puts "  Database: #{config[:dbname]}"
        puts "  User: #{config[:user]}"

        # PostgreSQL version
        version = conn.exec("SELECT version()").first['version']
        puts "\nPostgreSQL Version:"
        puts "  #{version.split(',').first}"

        # Extensions
        puts "\nExtensions:"
        extensions = conn.exec("SELECT extname, extversion FROM pg_extension ORDER BY extname").to_a
        extensions.each do |ext|
          puts "  #{ext['extname']} (#{ext['extversion']})"
        end

        # Table info
        puts "\nHTM Tables:"
        tables = ['nodes', 'tags', 'robots', 'operations_log', 'schema_migrations']
        tables.each do |table|
          begin
            count = conn.exec("SELECT COUNT(*) FROM #{table}").first['count']
            puts "  #{table}: #{count} rows"
          rescue PG::UndefinedTable
            puts "  #{table}: not created"
          end
        end

        # Database size
        db_size = conn.exec(
          "SELECT pg_size_pretty(pg_database_size($1)) AS size",
          [config[:dbname]]
        ).first['size']
        puts "\nDatabase Size: #{db_size}"

        conn.close
        puts "=" * 80
      end

      # Parse database connection URL
      #
      # @param url [String] Connection URL
      # @return [Hash, nil] Connection configuration hash
      #
      def parse_connection_url(url)
        return nil unless url

        uri = URI.parse(url)
        params = URI.decode_www_form(uri.query || '').to_h

        {
          host: uri.host,
          port: uri.port,
          dbname: uri.path[1..-1],  # Remove leading /
          user: uri.user,
          password: uri.password,
          sslmode: params['sslmode'] || 'prefer'
        }
      end

      # Build config from individual environment variables
      #
      # @return [Hash, nil] Connection configuration hash
      #
      def parse_connection_params
        return nil unless ENV['HTM_DBNAME']

        {
          host: ENV['HTM_DBHOST'] || 'cw7rxj91bm.srbbwwxn56.tsdb.cloud.timescale.com',
          port: (ENV['HTM_DBPORT'] || 37807).to_i,
          dbname: ENV['HTM_DBNAME'],
          user: ENV['HTM_DBUSER'],
          password: ENV['HTM_DBPASS'],
          sslmode: 'require'
        }
      end

      # Get default database configuration
      #
      # @return [Hash, nil] Connection configuration hash
      #
      def default_config
        # Prefer HTM_DBURL if available
        if ENV['HTM_DBURL']
          parse_connection_url(ENV['HTM_DBURL'])
        elsif ENV['HTM_DBNAME']
          parse_connection_params
        else
          nil
        end
      end

      private

      def verify_extensions(conn)
        # Check TimescaleDB
        timescale = conn.exec("SELECT extversion FROM pg_extension WHERE extname='timescaledb'").first
        if timescale
          puts "✓ TimescaleDB version: #{timescale['extversion']}"
        else
          puts "⚠ Warning: TimescaleDB extension not found"
        end

        # Check pgvector
        pgvector = conn.exec("SELECT extversion FROM pg_extension WHERE extname='vector'").first
        if pgvector
          puts "✓ pgvector version: #{pgvector['extversion']}"
        else
          puts "⚠ Warning: pgvector extension not found"
        end

        # Check pg_trgm
        pg_trgm = conn.exec("SELECT extversion FROM pg_extension WHERE extname='pg_trgm'").first
        if pg_trgm
          puts "✓ pg_trgm version: #{pg_trgm['extversion']}"
        else
          puts "⚠ Warning: pg_trgm extension not found"
        end
      end

      def run_schema(conn)
        # Check if user wants to use pgai via environment variable
        use_pgai = ENV['HTM_USE_PGAI'] == 'true'

        if use_pgai
          # Verify pgai extension is actually available
          pgai_available = conn.exec("SELECT 1 FROM pg_available_extensions WHERE name='ai'").ntuples > 0
          unless pgai_available
            raise HTM::DatabaseError, "HTM_USE_PGAI=true but pgai extension is not available in the database"
          end
          schema_path = File.expand_path('../../sql/schema.sql', __dir__)
          puts "Creating HTM schema with pgai support..."
        else
          schema_path = File.expand_path('../../sql/schema_no_pgai.sql', __dir__)
          puts "Creating HTM schema (client-side embeddings)..."
          puts "Note: Embeddings will be generated client-side. Set HTM_USE_PGAI=true to use pgai."
        end

        schema_sql = File.read(schema_path)

        # Remove extension creation lines - extensions are already available on TimescaleDB Cloud
        # This avoids path issues with control files
        schema_sql_filtered = schema_sql.lines.reject { |line|
          line.strip.start_with?('CREATE EXTENSION')
        }.join

        begin
          conn.exec(schema_sql_filtered)
          puts "✓ Schema created"
        rescue PG::Error => e
          # If schema already exists, that's OK
          if e.message.match?(/already exists/)
            puts "✓ Schema already exists (updated if needed)"
          else
            raise e
          end
        end
      end

      def run_migrations_if_needed(conn)
        # Create migrations tracking table if it doesn't exist
        conn.exec(<<~SQL)
          CREATE TABLE IF NOT EXISTS schema_migrations (
            version TEXT PRIMARY KEY,
            applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
          );
        SQL

        # Get list of applied migrations
        applied = conn.exec("SELECT version FROM schema_migrations").map { |r| r['version'] }.to_set

        # Get list of available migrations
        migrations_dir = File.expand_path('../../sql/migrations', __dir__)
        return unless Dir.exist?(migrations_dir)

        migration_files = Dir.glob(File.join(migrations_dir, '*.sql')).sort

        migration_files.each do |file|
          version = File.basename(file, '.sql')

          next if applied.include?(version)

          puts "Running migration: #{version}"
          migration_sql = File.read(file)

          begin
            conn.exec(migration_sql)
            conn.exec_params("INSERT INTO schema_migrations (version) VALUES ($1)", [version])
            puts "  ✓ Migration #{version} applied"
          rescue PG::Error => e
            puts "  ✗ Migration #{version} failed: #{e.message}"
            raise e
          end
        end
      end

      def setup_hypertables(conn)
        # Convert operations_log to hypertable for time-series optimization
        begin
          conn.exec(
            "SELECT create_hypertable('operations_log', 'timestamp',
             if_not_exists => TRUE,
             migrate_data => TRUE)"
          )
          puts "✓ Created hypertable for operations_log"
        rescue PG::Error => e
          puts "Note: operations_log hypertable: #{e.message}" if e.message !~ /already a hypertable/
        end

        # Optionally convert nodes table to hypertable partitioned by created_at
        begin
          conn.exec(
            "SELECT create_hypertable('nodes', 'created_at',
             if_not_exists => TRUE,
             migrate_data => TRUE)"
          )
          puts "✓ Created hypertable for nodes"

          # Enable compression for older data
          conn.exec(
            "ALTER TABLE nodes SET (
             timescaledb.compress,
             timescaledb.compress_segmentby = 'robot_id,type'
            )"
          )

          # Add compression policy: compress chunks older than 30 days
          conn.exec(
            "SELECT add_compression_policy('nodes', INTERVAL '30 days',
             if_not_exists => TRUE)"
          )
          puts "✓ Enabled compression for nodes older than 30 days"
        rescue PG::Error => e
          puts "Note: nodes hypertable: #{e.message}" if e.message !~ /already a hypertable/
        end
      end
    end
  end
end
