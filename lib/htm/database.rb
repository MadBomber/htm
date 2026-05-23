# frozen_string_literal: true

require 'pg'
require 'uri'

class HTM
  # Database setup and configuration for HTM
  # Handles schema creation and database initialization using Sequel
  class Database
    class << self
      # Set up the HTM database schema
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
      # @param run_migrations [Boolean] Whether to run migrations (default: true)
      # @param dump_schema [Boolean] Whether to dump schema to db/schema.sql after setup (default: false)
      # @return [void]
      #
      def setup(db_url = nil, run_migrations: true, dump_schema: false)
        require 'sequel'
        require_relative 'sequel_config'

        # Establish Sequel connection (don't load models yet - tables may not exist)
        HTM::SequelConfig.establish_connection!(load_models: false)

        # Run migrations using Sequel
        if run_migrations
          puts "Running Sequel migrations..."
          run_sequel_migrations
        end

        # Now that tables exist, load models
        HTM::SequelConfig.ensure_models_loaded!

        puts "HTM database schema created successfully"

        # Optionally dump schema
        return unless dump_schema
        puts ""
        self.dump_schema(db_url)
      end

      # Run pending database migrations
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
      # @return [void]
      #
      def migrate(db_url = nil)
        require 'sequel'
        require_relative 'sequel_config'

        # Establish Sequel connection (don't load models - tables may not exist)
        HTM::SequelConfig.establish_connection!(load_models: false)

        run_sequel_migrations

        # Load models now that tables exist
        HTM::SequelConfig.ensure_models_loaded!

        puts "Database migrations completed"
      end

      # Show migration status
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
      # @return [void]
      #
      def migration_status(db_url = nil)
        require 'sequel'
        require_relative 'sequel_config'

        HTM::SequelConfig.establish_connection!(load_models: false)

        available = load_available_migrations
        applied   = load_applied_versions

        print_migration_status_table(available, applied)
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

        tables = %w[nodes node_tags tags robots robot_nodes file_sources schema_migrations]

        puts "Dropping HTM tables..."
        tables.each do |table|
          conn.exec("DROP TABLE IF EXISTS #{table} CASCADE")
          puts "  Dropped #{table}"
        rescue PG::Error => e
          puts "  Error dropping #{table}: #{e.message}"
        end

        # Drop functions and triggers
        begin
          conn.exec("DROP FUNCTION IF EXISTS extract_ontology_topics() CASCADE")
          puts "  Dropped ontology functions and triggers"
        rescue PG::Error => e
          puts "  Error dropping functions: #{e.message}"
        end

        # Drop views
        begin
          conn.exec("DROP VIEW IF EXISTS ontology_structure CASCADE")
          conn.exec("DROP VIEW IF EXISTS topic_relationships CASCADE")
          puts "  Dropped ontology views"
        rescue PG::Error => e
          puts "  Error dropping views: #{e.message}"
        end

        conn.close
        puts "All HTM tables dropped"
      end

      # Seed database with sample data
      #
      # Loads and executes db/seeds.rb file following Rails conventions.
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
      # @return [void]
      #
      def seed(db_url = nil)
        seeds_file = File.expand_path('../../db/seeds.rb', __dir__)

        unless File.exist?(seeds_file)
          puts "Error: Seeds file not found at #{seeds_file}"
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

        require 'open3'
        stdout, stderr, status = Open3.capture3(env, *cmd)

        unless status.success?
          puts "Error dumping schema:"
          puts stderr
          exit 1
        end

        cleaned_schema = clean_schema_dump(stdout)
        File.write(schema_file, cleaned_schema)

        puts "Schema dumped successfully to #{schema_file}"
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
          puts "Schema file not found: #{schema_file}"
          puts "  Run 'rake htm:db:schema:dump' first to create it"
          exit 1
        end

        puts "Loading schema from #{schema_file}..."

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

        require 'open3'
        _, stderr, status = Open3.capture3(env, *cmd)

        unless status.success?
          puts "Error loading schema:"
          puts stderr
          exit 1
        end

        puts "Schema loaded successfully"
      end

      # Generate database documentation using tbls
      #
      # @param db_url [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
      # @return [void]
      #
      def generate_docs(db_url = nil)
        check_tbls_installed!
        tbls_config = locate_tbls_config!
        dsn         = build_tbls_dsn(db_url)
        run_tbls_doc(tbls_config, dsn)
        print_tbls_doc_success
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
        print_connection_info(config)
        print_pg_version(conn)
        print_extensions_list(conn)
        print_table_counts(conn)
        print_db_size(conn, config[:dbname])
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
        validate_pg_uri!(uri)

        dbname = uri.path&.slice(1..-1)
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
        return nil unless ENV['HTM_DATABASE__NAME']

        {
          host: ENV['HTM_DATABASE__HOST'] || 'localhost',
          port: (ENV['HTM_DATABASE__PORT'] || 5432).to_i,
          dbname: ENV.fetch('HTM_DATABASE__NAME', nil),
          user: ENV.fetch('HTM_DATABASE__USER', nil),
          password: ENV.fetch('HTM_DATABASE__PASSWORD', nil),
          sslmode: ENV['HTM_DATABASE__SSLMODE'] || 'prefer'
        }
      end

      # Get default database configuration
      #
      # Uses HTM::Config for database settings.
      #
      # @return [Hash, nil] Connection configuration hash with PG-style keys
      #
      def default_config
        htm_config = HTM.config

        if htm_config.database_configured?
          db_config = htm_config.database_config

          # Convert to PG-style keys
          {
            host: db_config[:host],
            port: db_config[:port],
            dbname: db_config[:database],
            user: db_config[:username],
            password: db_config[:password],
            sslmode: db_config[:sslmode] || 'prefer'
          }
        elsif ENV['HTM_DATABASE__URL']
          parse_connection_url(ENV['HTM_DATABASE__URL'])
        elsif ENV['HTM_DATABASE__NAME']
          parse_connection_params
        end
      end

      private

      def print_connection_info(config)
        puts "\nConnection:"
        puts "  Environment: #{HTM.env}"
        puts "  Host: #{config[:host]}"
        puts "  Port: #{config[:port]}"
        puts "  Database: #{config[:dbname]}"
        puts "  User: #{config[:user]}"
      end

      def print_pg_version(conn)
        version = conn.exec("SELECT version()").first['version']
        puts "\nPostgreSQL Version:"
        puts "  #{version.split(',').first}"
      end

      def print_extensions_list(conn)
        puts "\nExtensions:"
        conn.exec("SELECT extname, extversion FROM pg_extension ORDER BY extname").each do |ext|
          puts "  #{ext['extname']} (#{ext['extversion']})"
        end
      end

      def print_table_counts(conn)
        puts "\nHTM Tables:"
        %w[nodes node_tags tags robots robot_nodes file_sources schema_migrations].each do |table|
          count = conn.exec("SELECT COUNT(*) FROM #{table}").first['count']
          puts "  #{table}: #{count} rows"
        rescue PG::UndefinedTable
          puts "  #{table}: not created"
        end
      end

      def print_db_size(conn, dbname)
        size = conn.exec("SELECT pg_size_pretty(pg_database_size($1)) AS size", [dbname]).first['size']
        puts "\nDatabase Size: #{size}"
      end

      def ensure_schema_migrations_table(db)
        return if db.table_exists?(:schema_migrations)
        db.create_table(:schema_migrations) { String :version, primary_key: true, null: false }
      end

      def run_migration_file(file, db)
        version = File.basename(file).split('_').first
        name    = File.basename(file, '.rb')

        if db[:schema_migrations].where(version: version).any?
          puts "  [x] #{name} (already migrated)"
        else
          puts "  --> Running #{name}..."
          require file
          class_name = name.split('_')[1..].map(&:capitalize).join
          migration_class = Object.const_get(class_name)
          migration_class.new(db).up
          db[:schema_migrations].insert(version: version)
          puts "      Completed"
        end
      end

      def verify_extensions(conn)
        # Check pgvector
        pgvector = conn.exec("SELECT extversion FROM pg_extension WHERE extname='vector'").first
        if pgvector
          puts "pgvector version: #{pgvector['extversion']}"
        else
          puts "Warning: pgvector extension not found"
        end

        # Check pg_trgm
        pg_trgm = conn.exec("SELECT extversion FROM pg_extension WHERE extname='pg_trgm'").first
        if pg_trgm
          puts "pg_trgm version: #{pg_trgm['extversion']}"
        else
          puts "Warning: pg_trgm extension not found"
        end

        # Check pg_search (BM25 full-text search)
        pg_search = conn.exec("SELECT extversion FROM pg_extension WHERE extname='pg_search'").first
        if pg_search
          puts "pg_search version: #{pg_search['extversion']}"
        else
          puts "Warning: pg_search extension not found"
        end
      end

      # Run Sequel migrations from db/migrate/
      #
      # @return [void]
      #
      def run_sequel_migrations
        migrations_path = File.expand_path('../../db/migrate', __dir__)
        unless Dir.exist?(migrations_path)
          puts "No migrations directory found at #{migrations_path}"
          return
        end

        db = HTM.db
        ensure_schema_migrations_table(db)

        migration_files = Dir.glob("#{migrations_path}/*.rb")
        puts "Found #{migration_files.length} migration files"
        migration_files.each { |file| run_migration_file(file, db) }
        puts "All migrations completed"
      end

      # Clean up pg_dump output to make it more readable
      #
      # @param schema_dump [String] Raw pg_dump output
      # @return [String] Cleaned schema
      #
      def clean_schema_dump(schema_dump)
        lines = schema_dump.split("\n")
        cleaned = []

        cleaned << "-- HTM Database Schema"
        cleaned << "-- Auto-generated from database using pg_dump"
        cleaned << "-- DO NOT EDIT THIS FILE MANUALLY"
        cleaned << "-- Run 'rake htm:db:schema:dump' to regenerate"
        cleaned << ""

        skip_until_content = true

        lines.each do |line|
          if skip_until_content
            next unless line =~ /^(SET|CREATE|ALTER|--\s*Name:|COMMENT)/
            skip_until_content = false

          end

          next if line =~ /^SET /
          next if line =~ /^SELECT pg_catalog\.set_config/
          next if line =~ /^COMMENT ON EXTENSION/

          cleaned << line
        end

        result = cleaned.join("\n")
        result.gsub!(/\n{3,}/, "\n\n")

        result
      end

      def load_available_migrations
        migrations_path = File.expand_path('../../db/migrate', __dir__)
        migrations = Dir.glob(File.join(migrations_path, '*.rb')).map do |file|
          { version: File.basename(file).split('_').first.to_i, name: File.basename(file, '.rb') }
        end
        migrations.sort_by { |m| m[:version] }
      end

      def load_applied_versions
        HTM.db[:schema_migrations].select_map(:version).map(&:to_i)
      rescue Sequel::DatabaseError
        []
      end

      def print_migration_status_table(available, applied)
        puts "\nMigration Status"
        puts "=" * 100
        if available.empty?
          puts "No migration files found in db/migrate/"
        else
          available.each do |m|
            mark = applied.include?(m[:version]) ? "[x]" : "[ ]"
            puts "#{mark} #{m[:name]}"
          end
        end
        pending = available.length - applied.length
        puts "\nSummary: #{applied.length} applied, #{pending} pending"
        puts "=" * 100
      end

      def check_tbls_installed!
        return if system('which tbls > /dev/null 2>&1')

        puts <<~MSG
          Error: 'tbls' is not installed

          Install tbls:
            brew install k1LoW/tap/tbls
            # or
            go install github.com/k1LoW/tbls@latest

          See: https://github.com/k1LoW/tbls
        MSG
        exit 1
      end

      def locate_tbls_config!
        project_root = File.expand_path('../..', __dir__)
        config_path  = File.join(project_root, '.tbls.yml')
        return config_path if File.exist?(config_path)

        puts "Error: .tbls.yml not found at #{config_path}"
        exit 1
      end

      def build_tbls_dsn(db_url)
        dsn = db_url || ENV.fetch('HTM_DATABASE__URL', nil)
        raise "Database configuration not found. Set HTM_DATABASE__URL environment variable." unless dsn

        return dsn if dsn.include?('sslmode=')

        separator = dsn.include?('?') ? '&' : '?'
        "#{dsn}#{separator}sslmode=disable"
      end

      def run_tbls_doc(tbls_config, dsn)
        require 'open3'
        puts "Generating database documentation using #{tbls_config}..."
        stdout, stderr, status = Open3.capture3('tbls', 'doc', '--config', tbls_config, '--dsn', dsn, '--force')
        return puts(stdout) if status.success? && stdout && !stdout.empty?

        puts "Error generating documentation:"
        puts stderr
        puts stdout
        exit 1
      end

      def print_tbls_doc_success
        doc_path = 'docs/database'
        puts <<~MSG
          Database documentation generated successfully

          Documentation files:
            #{doc_path}/README.md       - Main documentation
            #{doc_path}/schema.svg      - ER diagram
            #{doc_path}/*.md            - Individual table documentation

          View documentation:
            open #{doc_path}/README.md
        MSG
      end

      def validate_pg_uri!(uri)
        unless uri.scheme&.match?(/\Apostgres(?:ql)?\z/i)
          raise ArgumentError, "Invalid database URL scheme: #{uri.scheme}. Expected 'postgresql' or 'postgres'."
        end
        raise ArgumentError, "Database URL must include a host"    if uri.host.nil? || uri.host.empty?

        dbname = uri.path&.slice(1..-1)
        raise ArgumentError, "Database URL must include a database name (path segment)" if dbname.nil? || dbname.empty?
      end
    end
  end
end
