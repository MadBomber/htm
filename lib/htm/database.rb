# frozen_string_literal: true

require 'pg'
require 'uri'
require 'set'

class HTM
  # Database setup and configuration for HTM
  # Handles schema creation and database initialization
  class Database
    class << self
      # Set up the HTM database schema
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @param run_migrations [Boolean] Whether to run migrations (default: true)
      # @param dump_schema [Boolean] Whether to dump schema to db/schema.sql after setup (default: false)
      # @return [void]
      #
      def setup(db_url = nil, run_migrations: true, dump_schema: false)
        require 'active_record'
        require_relative 'active_record_config'

        # Establish ActiveRecord connection
        HTM::ActiveRecordConfig.establish_connection!

        # Run migrations using ActiveRecord
        if run_migrations
          puts "Running ActiveRecord migrations..."
          run_activerecord_migrations
        end

        puts "✓ HTM database schema created successfully"

        # Optionally dump schema
        if dump_schema
          puts ""
          self.dump_schema(db_url)
        end
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

      # Drop all HTM tables (respects RAILS_ENV)
      #
      # @param db_url [String] Database connection URL (uses default_config if not provided)
      # @return [void]
      #
      def drop(db_url = nil)
        config = db_url ? parse_connection_url(db_url) : default_config
        raise "Database configuration not found" unless config

        puts "Environment: #{HTM.env}"
        puts "Database: #{config[:dbname]}"

        conn = PG.connect(config)

        tables = ['nodes', 'node_tags', 'tags', 'robots', 'robot_nodes', 'file_sources', 'schema_migrations']

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
      # Loads and executes db/seeds.rb file following Rails conventions.
      # All seeding logic is contained in db/seeds.rb and reads data
      # from markdown files in db/seed_data/ directory.
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def seed(db_url = nil)
        seeds_file = File.expand_path('../../db/seeds.rb', __dir__)

        unless File.exist?(seeds_file)
          puts "✗ Error: Seeds file not found at #{seeds_file}"
          puts "  Please create db/seeds.rb with your seeding logic"
          exit 1
        end

        # Load and execute seeds.rb
        load seeds_file
      end

      # Dump current database schema to db/schema.sql (respects RAILS_ENV)
      #
      # Uses pg_dump to create a clean SQL schema file without data
      #
      # @param db_url [String] Database connection URL (uses default_config if not provided)
      # @return [void]
      #
      def dump_schema(db_url = nil)
        config = db_url ? parse_connection_url(db_url) : default_config
        raise "Database configuration not found" unless config

        schema_file = File.expand_path('../../db/schema.sql', __dir__)

        puts "Dumping schema to #{schema_file}..."

        # Build pg_dump command
        # --schema-only: only dump schema, not data
        # --no-owner: don't set ownership
        # --no-privileges: don't dump access privileges
        # --no-tablespaces: don't dump tablespace assignments
        # --exclude-schema=_timescaledb_*: exclude TimescaleDB internal schemas
        env = {
          'PGPASSWORD' => config[:password]
        }

        cmd = [
          'pg_dump',
          '--schema-only',
          '--no-owner',
          '--no-privileges',
          '--no-tablespaces',
          '--exclude-schema=_timescaledb_*',
          '--exclude-schema=information_schema',
          '--exclude-schema=pg_catalog',
          '-h', config[:host],
          '-p', config[:port].to_s,
          '-U', config[:user],
          '-d', config[:dbname]
        ]

        # Execute pg_dump and capture output
        require 'open3'
        stdout, stderr, status = Open3.capture3(env, *cmd)

        unless status.success?
          puts "✗ Error dumping schema:"
          puts stderr
          exit 1
        end

        # Clean up the output
        cleaned_schema = clean_schema_dump(stdout)

        # Write to file
        File.write(schema_file, cleaned_schema)

        puts "✓ Schema dumped successfully to #{schema_file}"
        puts "  Size: #{File.size(schema_file)} bytes"
      end

      # Load schema from db/schema.sql (respects RAILS_ENV)
      #
      # Uses psql to load the schema file
      #
      # @param db_url [String] Database connection URL (uses default_config if not provided)
      # @return [void]
      #
      def load_schema(db_url = nil)
        config = db_url ? parse_connection_url(db_url) : default_config
        raise "Database configuration not found" unless config

        schema_file = File.expand_path('../../db/schema.sql', __dir__)

        unless File.exist?(schema_file)
          puts "✗ Schema file not found: #{schema_file}"
          puts "  Run 'rake htm:db:schema:dump' first to create it"
          exit 1
        end

        puts "Loading schema from #{schema_file}..."

        # Build psql command
        env = {
          'PGPASSWORD' => config[:password]
        }

        cmd = [
          'psql',
          '-h', config[:host],
          '-p', config[:port].to_s,
          '-U', config[:user],
          '-d', config[:dbname],
          '-f', schema_file,
          '--quiet'
        ]

        # Execute psql
        require 'open3'
        stdout, stderr, status = Open3.capture3(env, *cmd)

        unless status.success?
          puts "✗ Error loading schema:"
          puts stderr
          exit 1
        end

        puts "✓ Schema loaded successfully"
      end

      # Generate database documentation using tbls
      #
      # Uses .tbls.yml configuration file for output directory and settings.
      # Creates comprehensive database documentation including:
      # - Entity-relationship diagrams
      # - Table schemas with comments
      # - Index information
      # - Relationship diagrams
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)
      # @return [void]
      #
      def generate_docs(db_url = nil)
        # Check if tbls is installed
        unless system('which tbls > /dev/null 2>&1')
          puts "✗ Error: 'tbls' is not installed"
          puts ""
          puts "Install tbls:"
          puts "  brew install k1LoW/tap/tbls"
          puts "  # or"
          puts "  go install github.com/k1LoW/tbls@latest"
          puts ""
          puts "See: https://github.com/k1LoW/tbls"
          exit 1
        end

        # Find the project root (where .tbls.yml should be)
        project_root = File.expand_path('../..', __dir__)
        tbls_config = File.join(project_root, '.tbls.yml')

        unless File.exist?(tbls_config)
          puts "✗ Error: .tbls.yml not found at #{tbls_config}"
          exit 1
        end

        # Get database URL
        dsn = db_url || ENV['HTM_DBURL']
        raise "Database configuration not found. Set HTM_DBURL environment variable." unless dsn

        # Ensure sslmode is set for local development (tbls requires it)
        unless dsn.include?('sslmode=')
          separator = dsn.include?('?') ? '&' : '?'
          dsn = "#{dsn}#{separator}sslmode=disable"
        end

        puts "Generating database documentation using #{tbls_config}..."

        # Run tbls doc command with config file and DSN override
        # The --dsn flag overrides the dsn in .tbls.yml but other settings are preserved
        require 'open3'
        cmd = ['tbls', 'doc', '--config', tbls_config, '--dsn', dsn, '--force']

        stdout, stderr, status = Open3.capture3(*cmd)

        unless status.success?
          puts "✗ Error generating documentation:"
          puts stderr
          puts stdout
          exit 1
        end

        puts stdout if stdout && !stdout.empty?

        # Read docPath from config to show correct output location
        doc_path = 'docs/database'  # default from .tbls.yml
        puts "✓ Database documentation generated successfully"
        puts ""
        puts "Documentation files:"
        puts "  #{doc_path}/README.md       - Main documentation"
        puts "  #{doc_path}/schema.svg      - ER diagram"
        puts "  #{doc_path}/*.md            - Individual table documentation"
        puts ""
        puts "View documentation:"
        puts "  open #{doc_path}/README.md"
      end

      # Show database info (respects RAILS_ENV)
      #
      # @param db_url [String] Database connection URL (uses default_config if not provided)
      # @return [void]
      #
      def info(db_url = nil)
        config = db_url ? parse_connection_url(db_url) : default_config
        raise "Database configuration not found" unless config

        conn = PG.connect(config)

        puts "\nHTM Database Information (#{HTM.env})"
        puts "=" * 80

        # Connection info
        puts "\nConnection:"
        puts "  Environment: #{HTM.env}"
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
        tables = ['nodes', 'node_tags', 'tags', 'robots', 'robot_nodes', 'file_sources', 'schema_migrations']
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
      # @param url [String] Connection URL (e.g., postgresql://user:pass@host:port/dbname)
      # @return [Hash, nil] Connection configuration hash
      # @raise [ArgumentError] If URL format is invalid
      #
      def parse_connection_url(url)
        return nil unless url

        uri = URI.parse(url)

        # Validate URL format
        unless uri.scheme&.match?(/\Apostgres(?:ql)?\z/i)
          raise ArgumentError, "Invalid database URL scheme: #{uri.scheme}. Expected 'postgresql' or 'postgres'."
        end

        unless uri.host && !uri.host.empty?
          raise ArgumentError, "Database URL must include a host"
        end

        dbname = uri.path&.slice(1..-1)  # Remove leading /
        if dbname.nil? || dbname.empty?
          raise ArgumentError, "Database URL must include a database name (path segment)"
        end

        params = URI.decode_www_form(uri.query || '').to_h

        {
          host: uri.host,
          port: uri.port || 5432,
          dbname: dbname,
          user: uri.user,
          password: uri.password,
          sslmode: params['sslmode'] || 'prefer'
        }
      rescue URI::InvalidURIError => e
        raise ArgumentError, "Invalid database URL format: #{e.message}"
      end

      # Build config from individual environment variables
      #
      # @return [Hash, nil] Connection configuration hash
      #
      def parse_connection_params
        return nil unless ENV['HTM_DBNAME']

        {
          host: ENV['HTM_DBHOST'] || 'localhost',
          port: (ENV['HTM_DBPORT'] || 5432).to_i,
          dbname: ENV['HTM_DBNAME'],
          user: ENV['HTM_DBUSER'],
          password: ENV['HTM_DBPASS'],
          sslmode: ENV['HTM_DBSSLMODE'] || 'prefer'
        }
      end

      # Get default database configuration (respects RAILS_ENV)
      #
      # Uses ActiveRecordConfig which reads from config/database.yml
      # and respects RAILS_ENV for environment-specific database selection.
      #
      # @return [Hash, nil] Connection configuration hash with PG-style keys
      #
      def default_config
        require_relative 'active_record_config'

        begin
          ar_config = HTM::ActiveRecordConfig.load_database_config

          # Convert ActiveRecord config keys to PG-style keys
          {
            host: ar_config[:host],
            port: ar_config[:port],
            dbname: ar_config[:database],
            user: ar_config[:username],
            password: ar_config[:password],
            sslmode: ar_config[:sslmode] || 'prefer'
          }
        rescue StandardError
          # Fallback to legacy behavior if ActiveRecordConfig fails
          if ENV['HTM_DBURL']
            parse_connection_url(ENV['HTM_DBURL'])
          elsif ENV['HTM_DBNAME']
            parse_connection_params
          end
        end
      end

      private

      def verify_extensions(conn)
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

          # Check if already run (use parameterized query to prevent SQL injection)
          already_run = conn.select_value(
            ActiveRecord::Base.sanitize_sql_array(
              ["SELECT COUNT(*) FROM schema_migrations WHERE version = ?", version]
            )
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

            # Record in schema_migrations (use parameterized query to prevent SQL injection)
            conn.execute(
              ActiveRecord::Base.sanitize_sql_array(
                ["INSERT INTO schema_migrations (version) VALUES (?)", version]
              )
            )

            puts "    ✓ Completed"
          end
        end

        puts "✓ All migrations completed"
      end

      # Clean up pg_dump output to make it more readable
      #
      # @param schema_dump [String] Raw pg_dump output
      # @return [String] Cleaned schema
      #
      def clean_schema_dump(schema_dump)
        lines = schema_dump.split("\n")
        cleaned = []

        # Add header
        cleaned << "-- HTM Database Schema"
        cleaned << "-- Auto-generated from database using pg_dump"
        cleaned << "-- DO NOT EDIT THIS FILE MANUALLY"
        cleaned << "-- Run 'rake htm:db:schema:dump' to regenerate"
        cleaned << ""

        # Skip pg_dump header comments
        skip_until_content = true

        lines.each do |line|
          # Skip header comments
          if skip_until_content
            if line =~ /^(SET|CREATE|ALTER|--\s*Name:|COMMENT)/
              skip_until_content = false
            else
              next
            end
          end

          # Skip SET commands (session-specific settings)
          next if line =~ /^SET /

          # Skip SELECT pg_catalog.set_config
          next if line =~ /^SELECT pg_catalog\.set_config/

          # Skip extension comments (we keep extension creation)
          next if line =~ /^COMMENT ON EXTENSION/

          # Keep everything else
          cleaned << line
        end

        # Remove multiple blank lines
        result = cleaned.join("\n")
        result.gsub!(/\n{3,}/, "\n\n")

        result
      end

      # Old methods removed - now using ActiveRecord migrations
      # def run_schema(conn) - REMOVED
      # def run_migrations_if_needed(conn) - REMOVED (see run_activerecord_migrations above)
    end
  end
end
