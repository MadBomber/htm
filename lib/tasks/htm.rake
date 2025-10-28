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

    desc "Drop all HTM tables (WARNING: destructive!)"
    task :drop do
      require 'htm'
      print "Are you sure you want to drop all tables? This cannot be undone! (yes/no): "
      response = STDIN.gets.chomp
      if response.downcase == 'yes'
        HTM::Database.drop
      else
        puts "Cancelled."
      end
    end

    desc "Drop and recreate database (WARNING: destructive!)"
    task :reset do
      require 'htm'
      print "Are you sure you want to drop all tables? This cannot be undone! (yes/no): "
      response = STDIN.gets.chomp
      if response.downcase == 'yes'
        HTM::Database.drop
        HTM::Database.setup(dump_schema: true)
      else
        puts "Cancelled."
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

    desc "Generate/update database documentation in dbdoc/"
    task :doc do
      require 'htm'
      HTM::Database.generate_docs
    end
  end
end
