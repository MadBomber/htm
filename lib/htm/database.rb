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
        require 'active_record'
        require_relative 'active_record_config'

        # Establish ActiveRecord connection
        HTM::ActiveRecordConfig.establish_connection!

        # Run migrations using ActiveRecord
        if run_migrations
          puts "Running ActiveRecord migrations..."
          run_activerecord_migrations
        end

        # Convert tables to hypertables for time-series optimization (if TimescaleDB available)
        config = parse_connection_url(db_url || ENV['HTM_DBURL'])
        if config
          conn = PG.connect(config)
          begin
            setup_hypertables(conn)
          ensure
            conn.close
          end
        end

        puts "✓ HTM database schema created successfully"
      end

      # Run pending database migrations
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def migrate(db_url = nil)
        require 'active_record'
        require_relative 'active_record_config'

        # Establish ActiveRecord connection
        HTM::ActiveRecordConfig.establish_connection!

        run_activerecord_migrations

        puts "✓ Database migrations completed"
      end

      # Show migration status
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def migration_status(db_url = nil)
        require 'active_record'
        require_relative 'active_record_config'

        # Establish ActiveRecord connection
        HTM::ActiveRecordConfig.establish_connection!

        migrations_path = File.expand_path('../../db/migrate', __dir__)

        # Get available migrations from files
        available_migrations = Dir.glob(File.join(migrations_path, '*.rb')).map do |file|
          {
            version: File.basename(file).split('_').first,
            name: File.basename(file, '.rb')
          }
        end.sort_by { |m| m[:version] }

        # Get applied migrations from database
        applied_versions = begin
          ActiveRecord::Base.connection.select_values('SELECT version FROM schema_migrations ORDER BY version')
        rescue ActiveRecord::StatementInvalid
          []
        end

        puts "\nMigration Status"
        puts "=" * 100

        if available_migrations.empty?
          puts "No migration files found in db/migrate/"
        else
          available_migrations.each do |migration|
            status = applied_versions.include?(migration[:version])
            status_mark = status ? "✓" : "✗"

            puts "#{status_mark} #{migration[:name]}"
          end
        end

        applied_count = applied_versions.length
        pending_count = available_migrations.length - applied_count

        puts "\nSummary: #{applied_count} applied, #{pending_count} pending"
        puts "=" * 100
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
        puts "Note: This requires Ollama to be running locally for embedding generation."
        puts

        # Use real HTM initialization with actual EmbeddingService
        # Embeddings will be generated client-side via EmbeddingService
        htm = HTM.new(
          robot_name: "Sample Robot"
        )

        # Add sample conversation messages
        puts "  Creating sample conversation..."

        htm.add_message(
          "What is TimescaleDB good for?",
          speaker: "user",
          type: :question,
          importance: 5.0,
          tags: ["database", "timescaledb"]
        )

        htm.add_message(
          "PostgreSQL with TimescaleDB provides efficient time-series data storage and querying capabilities.",
          speaker: "Sample Robot",
          type: :fact,
          importance: 8.0,
          tags: ["database", "timescaledb"]
        )

        htm.add_message(
          "How much training data do ML models need?",
          speaker: "user",
          type: :question,
          importance: 6.0,
          tags: ["ai", "machine-learning"]
        )

        htm.add_message(
          "Machine learning models require large amounts of training data to achieve good performance.",
          speaker: "Sample Robot",
          type: :fact,
          importance: 7.0,
          tags: ["ai", "machine-learning"]
        )

        htm.add_message(
          "Tell me about Ruby on Rails",
          speaker: "user",
          type: :question,
          importance: 5.0,
          tags: ["ruby", "web-development"]
        )

        htm.add_message(
          "Ruby on Rails is a web framework for building database-backed applications.",
          speaker: "Sample Robot",
          type: :fact,
          importance: 6.0,
          tags: ["ruby", "web-development"]
        )

        htm.shutdown

        puts "✓ Database seeded with 6 conversation messages (3 exchanges)"
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

      # Run ActiveRecord migrations from db/migrate/
      #
      # @return [void]
      #
      def run_activerecord_migrations
        migrations_path = File.expand_path('../../db/migrate', __dir__)

        unless Dir.exist?(migrations_path)
          puts "⚠ No migrations directory found at #{migrations_path}"
          return
        end

        conn = ActiveRecord::Base.connection

        # Create schema_migrations table if it doesn't exist
        unless conn.table_exists?('schema_migrations')
          conn.create_table(:schema_migrations, id: false) do |t|
            t.string :version, null: false, primary_key: true
          end
        end

        # Get list of migration files
        migration_files = Dir.glob("#{migrations_path}/*.rb").sort
        puts "Found #{migration_files.length} migration files"

        # Run each migration
        migration_files.each do |file|
          version = File.basename(file).split('_').first
          name = File.basename(file, '.rb')

          # Check if already run
          already_run = conn.select_value(
            "SELECT COUNT(*) FROM schema_migrations WHERE version = '#{version}'"
          ).to_i > 0

          if already_run
            puts "  ✓ #{name} (already migrated)"
          else
            puts "  → Running #{name}..."
            require file

            # Get the migration class
            class_name = name.split('_')[1..].map(&:capitalize).join
            migration_class = Object.const_get(class_name)

            # Run the migration
            migration = migration_class.new
            migration.migrate(:up)

            # Record in schema_migrations
            conn.execute(
              "INSERT INTO schema_migrations (version) VALUES ('#{version}')"
            )

            puts "    ✓ Completed"
          end
        end

        puts "✓ All migrations completed"
      end

      # Old methods removed - now using ActiveRecord migrations
      # def run_schema(conn) - REMOVED
      # def run_migrations_if_needed(conn) - REMOVED (see run_activerecord_migrations above)

      def setup_hypertables(conn)
        # All tables use simple PRIMARY KEY (id), no hypertable conversions
        # Time-range queries use indexed timestamp columns:
        # - nodes: indexed created_at column
        # - operations_log: indexed timestamp column
      end
    end
  end
end
