# frozen_string_literal: true

class HTM
  module MCP
    # CLI commands for htm_mcp executable
    module CLI
      module_function

      def print_help
        puts <<~HELP
          HTM MCP Server - Memory management for AI assistants

          USAGE:
            htm_mcp [COMMAND]

          COMMANDS:
            server    Start the MCP server (default if no command given)
            stdio     Alias for server (for MCP client compatibility)
            setup     Initialize the database schema
            init      Alias for setup
            verify    Verify database connection and extensions
            stats     Show memory statistics
            version   Show HTM version
            help      Show this help message

          ENVIRONMENT VARIABLES:

            Note: Nested config uses double underscores (e.g., HTM_EMBEDDING__PROVIDER)

            Environment:
              HTM_ENV                       Environment name: development, test, production
                                            (priority: HTM_ENV > RAILS_ENV > RACK_ENV > 'development')

            Database:
              HTM_DATABASE__URL             PostgreSQL connection URL (preferred)
                                            Example: postgresql://user:pass@localhost:5432/htm_development
              HTM_DATABASE__HOST            Database host (default: localhost)
              HTM_DATABASE__PORT            Database port (default: 5432)
              HTM_DATABASE__NAME            Database name
              HTM_DATABASE__USER            Database username
              HTM_DATABASE__PASSWORD        Database password
              HTM_DATABASE__SSLMODE         SSL mode (default: prefer)
              HTM_DATABASE__POOL_SIZE       Connection pool size (default: 10)

            Embedding:
              HTM_EMBEDDING__PROVIDER       Provider (default: ollama)
              HTM_EMBEDDING__MODEL          Model (default: nomic-embed-text:latest)
              HTM_EMBEDDING__DIMENSIONS     Dimensions (default: 768)
              HTM_EMBEDDING__TIMEOUT        Timeout seconds (default: 120)
              HTM_EMBEDDING__MAX_DIMENSION  Max dimensions (default: 2000)

            Tag Extraction:
              HTM_TAG__PROVIDER             Provider (default: ollama)
              HTM_TAG__MODEL                Model (default: gemma3:latest)
              HTM_TAG__TIMEOUT              Timeout seconds (default: 180)
              HTM_TAG__MAX_DEPTH            Max hierarchy depth (default: 4)

            Proposition Extraction:
              HTM_PROPOSITION__PROVIDER     Provider (default: ollama)
              HTM_PROPOSITION__MODEL        Model (default: gemma3:latest)
              HTM_PROPOSITION__TIMEOUT      Timeout seconds (default: 180)
              HTM_PROPOSITION__ENABLED      Enable extraction (default: false)

            Chunking:
              HTM_CHUNKING__SIZE            Max chars per chunk (default: 1024)
              HTM_CHUNKING__OVERLAP         Chunk overlap chars (default: 64)

            Job Backend:
              HTM_JOB__BACKEND              Backend: inline, thread, active_job, sidekiq

            Provider API Keys:
              HTM_PROVIDERS__OLLAMA__URL           Ollama URL (default: http://localhost:11434)
              HTM_PROVIDERS__OPENAI__API_KEY       OpenAI API key
              HTM_PROVIDERS__ANTHROPIC__API_KEY    Anthropic API key
              HTM_PROVIDERS__GEMINI__API_KEY       Google Gemini API key
              HTM_PROVIDERS__AZURE__API_KEY        Azure OpenAI API key
              HTM_PROVIDERS__AZURE__ENDPOINT       Azure OpenAI endpoint

            Other:
              HTM_LOG_LEVEL                 Log level (default: info)
              HTM_CONNECTION_TIMEOUT        Connection timeout seconds (default: 30)
              HTM_TELEMETRY_ENABLED         Enable OpenTelemetry (default: false)

          OPTIONS:
            -c, --config [PATH]   Without PATH: output default config to STDOUT
                                  With PATH: load config from YAML file

          EXAMPLES:
            # Generate a config file template
            htm_mcp --config > my_config.yml

            # Start server with custom config
            htm_mcp --config my_config.yml

            # First-time setup
            export HTM_DATABASE__URL="postgresql://postgres@localhost:5432/htm"
            htm_mcp setup

            # Verify connection
            htm_mcp verify

            # Use test database
            HTM_ENV=test htm_mcp setup
            HTM_ENV=test htm_mcp stats

            # Start MCP server (for Claude Desktop)
            htm_mcp

          CLAUDE DESKTOP CONFIGURATION:
            Add to ~/.config/claude/claude_desktop_config.json:

            {
              "mcpServers": {
                "htm-memory": {
                  "command": "/path/to/htm_mcp",
                  "env": {
                    "HTM_DATABASE__URL": "postgresql://postgres@localhost:5432/htm_development"
                  }
                }
              }
            }
        HELP
      end

      def check_database_config!
        unless ENV['HTM_DATABASE__URL'] || ENV['HTM_DATABASE__NAME']
          warn "Error: Database not configured."
          warn "Set HTM_DATABASE__URL or HTM_DATABASE__NAME environment variable."
          warn "Run 'htm_mcp help' for details."
          exit 1
        end
      end

      def print_error_suggestion(error_message)
        msg = error_message.to_s.downcase

        warn ""
        if msg.include?("does not exist")
          warn "Suggestion: The database does not exist. Create it with:"
          warn "  createdb #{extract_dbname(ENV['HTM_DATABASE__URL'] || ENV['HTM_DATABASE__NAME'])}"
          warn "Then initialize the schema with:"
          warn "  htm_mcp setup"
        elsif msg.include?("password authentication failed") || msg.include?("no password supplied")
          warn "Suggestion: Check your database credentials."
          warn "Verify HTM_DATABASE__URL has correct username and password:"
          warn "  postgresql://USER:PASSWORD@localhost:5432/DATABASE"
        elsif msg.include?("connection refused") || msg.include?("could not connect")
          warn "Suggestion: PostgreSQL server is not running or not accepting connections."
          warn "Start PostgreSQL with:"
          warn "  brew services start postgresql@17  # macOS with Homebrew"
          warn "  sudo systemctl start postgresql    # Linux"
        elsif msg.include?("role") && msg.include?("does not exist")
          warn "Suggestion: The database user does not exist. Create it with:"
          warn "  createuser -s YOUR_USERNAME"
        elsif msg.include?("permission denied")
          warn "Suggestion: The user lacks permission to access this database."
          warn "Grant access or use a different user with appropriate privileges."
        elsif msg.include?("timeout") || msg.include?("timed out")
          warn "Suggestion: Connection timed out. Check:"
          warn "  - PostgreSQL is running"
          warn "  - Firewall allows connections on port 5432"
          warn "  - Host address is correct"
        elsif msg.include?("extension") && msg.include?("vector")
          warn "Suggestion: pgvector extension is not installed. Install it with:"
          warn "  brew install pgvector  # macOS"
          warn "Then enable it in your database:"
          warn "  psql -d DATABASE -c 'CREATE EXTENSION vector;'"
        else
          warn "Suggestion: Run 'htm_mcp help' for configuration details."
        end
      end

      def extract_dbname(url_or_name)
        return url_or_name unless url_or_name&.include?("://")

        # Extract database name from URL like postgresql://user@host:port/dbname
        if url_or_name =~ %r{/([^/?]+)(?:\?|$)}
          $1
        else
          "htm_development"
        end
      end

      def run_setup
        puts "HTM Database Setup"
        puts "=================="
        puts

        check_database_config!

        begin
          HTM::Database.setup
          puts
          puts "Database initialized successfully!"
          puts "You can now start the MCP server with: htm_mcp"
        rescue => e
          warn "Setup failed: #{e.message}"
          print_error_suggestion(e.message)
          warn e.backtrace.first(5).join("\n") if ENV['DEBUG']
          exit 1
        end
      end

      def run_verify
        puts "HTM Database Verification"
        puts "========================="
        puts

        check_database_config!

        begin
          HTM::Database.info
          puts

          # Check migration status
          pending = check_migration_status
          puts

          if pending > 0
            warn "Warning: #{pending} pending migration(s) detected."
            warn "  Run 'htm_mcp setup' to apply pending migrations."
            puts
          end

          puts "Database connection verified!"
        rescue => e
          warn "Verification failed: #{e.message}"
          print_error_suggestion(e.message)
          warn e.backtrace.first(5).join("\n") if ENV['DEBUG']
          exit 1
        end
      end

      def check_migration_status
        migrations_path = File.expand_path('../../../db/migrate', __dir__)

        # Get available migrations from files
        available_migrations = Dir.glob(File.join(migrations_path, '*.rb')).map do |file|
          {
            version: File.basename(file).split('_').first,
            name: File.basename(file, '.rb')
          }
        end.sort_by { |m| m[:version] }

        # Ensure ActiveRecord connection for migration check
        HTM::ActiveRecordConfig.establish_connection!

        # Get applied migrations from database
        applied_versions = begin
          ActiveRecord::Base.connection.select_values('SELECT version FROM schema_migrations ORDER BY version')
        rescue ActiveRecord::StatementInvalid
          []
        end

        puts "Migration Status"
        puts "-" * 80

        if available_migrations.empty?
          puts "  No migration files found"
          return 0
        end

        available_migrations.each do |migration|
          applied = applied_versions.include?(migration[:version])
          status_mark = applied ? "+" : "-"
          puts "  #{status_mark} #{migration[:name]}"
        end

        applied_count = applied_versions.length
        pending_count = available_migrations.length - applied_count

        puts "-" * 80
        puts "  #{applied_count} applied, #{pending_count} pending"

        pending_count
      end

      def output_default_config
        defaults_path = File.expand_path('../../config/defaults.yml', __dir__)
        if File.exist?(defaults_path)
          puts File.read(defaults_path)
        else
          warn "Error: defaults.yml not found at #{defaults_path}"
          exit 1
        end
      end

      def load_config_file(path)
        unless File.exist?(path)
          warn "Error: Config file not found: #{path}"
          exit 1
        end

        begin
          require 'yaml'
          config_data = YAML.safe_load(
            File.read(path),
            permitted_classes: [Symbol],
            symbolize_names: true,
            aliases: true
          ) || {}

          # Determine which section to use based on environment
          env = HTM::Config.env.to_sym
          base = config_data[:defaults] || {}
          env_overrides = config_data[env] || {}

          # Merge base with environment-specific overrides
          merged = deep_merge(base, env_overrides)

          apply_config(merged)

          warn "Loaded configuration from: #{path}"
          warn "Environment: #{env}"
        rescue => e
          warn "Error loading config file: #{e.message}"
          warn e.backtrace.first(5).join("\n") if ENV['DEBUG']
          exit 1
        end
      end

      def deep_merge(base, override)
        base.merge(override) do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val.nil? ? old_val : new_val
          end
        end
      end

      def apply_config(config)
        HTM.configure do |c|
          # Apply nested sections
          apply_section(c, :database, config[:database])
          apply_section(c, :service, config[:service])
          apply_section(c, :embedding, config[:embedding])
          apply_section(c, :tag, config[:tag])
          apply_section(c, :proposition, config[:proposition])
          apply_section(c, :chunking, config[:chunking])
          apply_section(c, :circuit_breaker, config[:circuit_breaker])
          apply_section(c, :relevance, config[:relevance])
          apply_section(c, :job, config[:job])
          apply_section(c, :providers, config[:providers])

          # Apply top-level scalars
          c.week_start = config[:week_start] if config[:week_start]
          c.connection_timeout = config[:connection_timeout] if config[:connection_timeout]
          c.telemetry_enabled = config[:telemetry_enabled] unless config[:telemetry_enabled].nil?
          c.log_level = config[:log_level] if config[:log_level]
        end
      end

      def apply_section(config, section_name, values)
        return unless values.is_a?(Hash)

        section = config.send(section_name)
        values.each do |key, value|
          next if value.nil?

          if value.is_a?(Hash)
            # Handle nested sections (like providers.openai)
            subsection = section.send(key)
            value.each do |subkey, subvalue|
              subsection.send("#{subkey}=", subvalue) unless subvalue.nil?
            end
          else
            section.send("#{key}=", value)
          end
        end
      end

      def run_stats
        puts "HTM Memory Statistics"
        puts "====================="
        puts

        check_database_config!

        begin
          HTM::ActiveRecordConfig.establish_connection!

          total_nodes     = HTM::Models::Node.count
          deleted_nodes   = HTM::Models::Node.deleted.count
          with_embeddings = HTM::Models::Node.with_embeddings.count
          total_tags      = HTM::Models::Tag.count
          total_robots    = HTM::Models::Robot.count
          total_files     = HTM::Models::FileSource.count

          # Get database size
          db_size = ActiveRecord::Base.connection.execute(
            "SELECT pg_size_pretty(pg_database_size(current_database())) AS size"
          ).first['size']

          puts "Nodes:   #{total_nodes} active, #{deleted_nodes} deleted, #{with_embeddings} with embeddings"
          puts "Tags:    #{total_tags}"
          puts "Robots:  #{total_robots}"
          puts "Files:   #{total_files}"
          puts
          puts "Database size: #{db_size}"
        rescue => e
          warn "Stats failed: #{e.message}"
          print_error_suggestion(e.message)
          warn e.backtrace.first(5).join("\n") if ENV['DEBUG']
          exit 1
        end
      end

      def run(args)
        args = args.dup

        # Handle -c / --config option first (can be combined with other commands)
        config_loaded = handle_config_option(args)

        # Process remaining command
        case args[0]&.downcase
        when 'help', '-h', '--help'
          print_help
          exit 0
        when 'version', '-v', '--version'
          puts "HTM #{HTM::VERSION}"
          exit 0
        when 'setup', 'init'
          run_setup
          exit 0
        when 'verify'
          run_verify
          exit 0
        when 'stats'
          run_stats
          exit 0
        when 'server', 'stdio', nil
          # Return false to indicate server should start
          # 'stdio' is accepted for compatibility with MCP clients that pass it as an argument
          false
        when /^-/
          warn "Unknown option: #{args[0]}"
          warn "Run 'htm_mcp help' for usage."
          exit 1
        else
          warn "Unknown command: #{args[0]}"
          warn "Run 'htm_mcp help' for usage."
          exit 1
        end
      end

      # Handle -c / --config option, modifying args in place
      # Returns true if config was loaded, nil otherwise
      def handle_config_option(args)
        config_idx = args.index('-c') || args.index('--config')
        return nil unless config_idx

        # Remove the -c/--config flag
        args.delete_at(config_idx)

        # Check if next arg is a path (not another flag or command)
        next_arg = args[config_idx]

        if next_arg.nil? || next_arg.start_with?('-') || command?(next_arg)
          # No path provided - output default config and exit
          output_default_config
          exit 0
        else
          # Path provided - load config file
          config_path = args.delete_at(config_idx)
          load_config_file(config_path)
          true
        end
      end

      def command?(arg)
        %w[help version setup init verify stats server stdio].include?(arg.downcase)
      end
    end
  end
end
