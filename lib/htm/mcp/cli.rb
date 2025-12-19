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
            setup     Initialize the database schema
            init      Alias for setup
            verify    Verify database connection and extensions
            stats     Show memory statistics
            version   Show HTM version
            help      Show this help message

          ENVIRONMENT VARIABLES:

            Database (required):
              HTM_DBURL                     PostgreSQL connection URL
                                            Example: postgresql://user:pass@localhost:5432/htm_development

            Database (alternative to HTM_DBURL):
              HTM_DBNAME                    Database name
              HTM_DBHOST                    Database host (default: localhost)
              HTM_DBPORT                    Database port (default: 5432)
              HTM_DBUSER                    Database username
              HTM_DBPASS                    Database password
              HTM_DBSSLMODE                 SSL mode (default: prefer)

            LLM Providers:
              HTM_EMBEDDING_PROVIDER        Embedding provider (default: ollama)
              HTM_EMBEDDING_MODEL           Embedding model (default: nomic-embed-text:latest)
              HTM_EMBEDDING_DIMENSIONS      Embedding dimensions (default: 768)
              HTM_TAG_PROVIDER              Tag extraction provider (default: ollama)
              HTM_TAG_MODEL                 Tag model (default: gemma3:latest)
              HTM_PROPOSITION_PROVIDER      Proposition provider (default: ollama)
              HTM_PROPOSITION_MODEL         Proposition model (default: gemma3:latest)
              HTM_EXTRACT_PROPOSITIONS      Enable propositions (default: false)

            Ollama (default provider):
              HTM_OLLAMA_URL                Ollama server URL (default: http://localhost:11434)

            Other Providers (set API keys as needed):
              HTM_OPENAI_API_KEY            OpenAI API key
              HTM_ANTHROPIC_API_KEY         Anthropic API key
              HTM_GEMINI_API_KEY            Google Gemini API key
              HTM_AZURE_API_KEY             Azure OpenAI API key
              HTM_AZURE_ENDPOINT            Azure OpenAI endpoint

            Timeouts:
              HTM_EMBEDDING_TIMEOUT         Embedding timeout seconds (default: 120)
              HTM_TAG_TIMEOUT               Tag timeout seconds (default: 180)
              HTM_CONNECTION_TIMEOUT        Connection timeout seconds (default: 30)

            Chunking:
              HTM_CHUNK_SIZE                Max chars per chunk (default: 1024)
              HTM_CHUNK_OVERLAP             Chunk overlap chars (default: 64)

            Other:
              HTM_LOG_LEVEL                 Log level (default: INFO)
              HTM_JOB_BACKEND               Job backend: inline, thread, active_job, sidekiq
              HTM_TELEMETRY_ENABLED         Enable OpenTelemetry (default: false)
              HTM_MAX_EMBEDDING_DIMENSION   Max vector dimensions (default: 2000)
              HTM_MAX_TAG_DEPTH             Max tag hierarchy depth (default: 4)

          EXAMPLES:
            # First-time setup
            export HTM_DBURL="postgresql://postgres@localhost:5432/htm_development"
            htm_mcp setup

            # Verify connection
            htm_mcp verify

            # Start MCP server (for Claude Desktop)
            htm_mcp

          CLAUDE DESKTOP CONFIGURATION:
            Add to ~/.config/claude/claude_desktop_config.json:

            {
              "mcpServers": {
                "htm-memory": {
                  "command": "/path/to/htm_mcp",
                  "env": {
                    "HTM_DBURL": "postgresql://postgres@localhost:5432/htm_development"
                  }
                }
              }
            }
        HELP
      end

      def check_database_config!
        unless ENV['HTM_DBURL'] || ENV['HTM_DBNAME']
          warn "Error: Database not configured."
          warn "Set HTM_DBURL or HTM_DBNAME environment variable."
          warn "Run 'htm_mcp help' for details."
          exit 1
        end
      end

      def print_error_suggestion(error_message)
        msg = error_message.to_s.downcase

        warn ""
        if msg.include?("does not exist")
          warn "Suggestion: The database does not exist. Create it with:"
          warn "  createdb #{extract_dbname(ENV['HTM_DBURL'] || ENV['HTM_DBNAME'])}"
          warn "Then initialize the schema with:"
          warn "  htm_mcp setup"
        elsif msg.include?("password authentication failed") || msg.include?("no password supplied")
          warn "Suggestion: Check your database credentials."
          warn "Verify HTM_DBURL has correct username and password:"
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
        when 'server', nil
          # Return false to indicate server should start
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
    end
  end
end
