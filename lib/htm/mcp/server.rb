# frozen_string_literal: true

require 'logger'
require 'fast_mcp'
require 'ruby_llm'

require_relative 'tools'
require_relative 'group_tools'
require_relative 'resources'

class HTM
  module MCP
    # MCP Server setup and lifecycle management
    module Server
      module_function

      def start
        check_database_config!
        verify_database_connection!
        configure_logging!
        configure_htm!

        server = create_server
        register_tools(server)
        register_resources(server)

        server.start
      end

      def check_database_config!
        unless ENV['HTM_DATABASE__URL'] || ENV['HTM_DATABASE__NAME']
          warn "Error: Database not configured."
          warn "Set HTM_DATABASE__URL or HTM_DATABASE__NAME environment variable."
          warn "Run 'htm_mcp help' for details."
          exit 1
        end
      end

      def verify_database_connection!
        HTM::ActiveRecordConfig.establish_connection!
        # Quick connectivity test
        ActiveRecord::Base.connection.execute("SELECT 1")
      rescue => e
        warn "Error: Cannot connect to database."
        warn e.message
        CLI.print_error_suggestion(e.message)
        exit 1
      end

      def configure_logging!
        # IMPORTANT: MCP uses STDIO for JSON-RPC communication.
        # ALL logging must go to STDERR to avoid corrupting the protocol.
        @stderr_logger = Logger.new($stderr)
        @stderr_logger.level = Logger::INFO
        @stderr_logger.formatter = proc do |severity, datetime, _progname, msg|
          "[MCP #{severity}] #{datetime.strftime('%H:%M:%S')} #{msg}\n"
        end

        # Silent logger for RubyLLM/HTM internals (prevents STDOUT corruption)
        @silent_logger = Logger.new(IO::NULL)

        # Configure RubyLLM to not log to STDOUT (corrupts MCP protocol)
        RubyLLM.configure do |config|
          config.logger = @silent_logger
        end

        # Set logger for MCP session
        Session.logger = @stderr_logger
      end

      def configure_htm!
        HTM.configure do |config|
          # Job backend now comes from config (defaults to :fiber)
          # Use HTM_JOB__BACKEND=inline or config file to override
          config.logger = @silent_logger  # Silent logging for MCP
        end
      end

      def create_server
        FastMcp::Server.new(
          name:    'htm-memory-server',
          version: HTM::VERSION
        )
      end

      def register_tools(server)
        # Register individual robot/memory tools
        TOOLS.each { |tool| server.register_tool(tool) }

        # Register group tools
        GROUP_TOOLS.each { |tool| server.register_tool(tool) }
      end

      def register_resources(server)
        RESOURCES.each { |resource| server.register_resource(resource) }
      end
    end
  end
end
