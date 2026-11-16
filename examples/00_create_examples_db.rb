#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates and sets up the htm_examples database
#
# This script should be run before any other examples to ensure
# the examples database exists and has the correct schema.
#
# Run via:
#   ruby examples/00_create_examples_db.rb
#   # or
#   ./examples/00_create_examples_db.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Set examples environment BEFORE loading HTM
ENV['HTM_ENV'] = 'examples'

service_name = ENV['HTM_SERVICE__NAME'] || 'htm'
db_name = "#{service_name}_examples"
db_url = "postgresql://#{ENV['USER']}@localhost:5432/#{db_name}"

ENV['HTM_DATABASE__URL'] = db_url

# Point psql/createdb at the same server HTM will connect to,
# not whatever libpq defaults to (PGHOST, PGPORT, Unix socket)
require 'uri'
db_uri = URI.parse(db_url)
pg_conn_args = []
pg_conn_args.push('-h', db_uri.host) if db_uri.host
pg_conn_args.push('-p', db_uri.port.to_s) if db_uri.port
pg_conn_args.push('-U', URI.decode_uri_component(db_uri.user)) if db_uri.user

puts <<~HEADER

  ==========================================
  == HTM Examples Database Setup ==
  ==========================================

  Database: #{db_name}

HEADER

# Step 1: Create database if it doesn't exist
puts "1. Checking if database exists..."

db_list = begin
  IO.popen(['psql', *pg_conn_args, '-lqt'], err: File::NULL, &:read)
rescue Errno::ENOENT
  ''
end
db_exists = db_list.lines.any? { |line| line.split('|').first.to_s.strip == db_name }

if db_exists
  puts "   Database '#{db_name}' already exists."
else
  puts "   Creating database '#{db_name}'..."
  unless system('createdb', *pg_conn_args, db_name)
    abort "   ERROR: Failed to create database '#{db_name}'"
  end
  puts "   Database created."
end

# Step 2: Enable extensions
puts "\n2. Enabling PostgreSQL extensions..."

extensions_sql = <<~SQL
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
SQL

unless system('psql', *pg_conn_args, '-d', db_name, '-c', extensions_sql, out: File::NULL, err: File::NULL)
  abort "   ERROR: Failed to enable extensions"
end
puts "   Extensions enabled (pgvector, pg_trgm)."

# Step 3: Run migrations
puts "\n3. Running schema migrations..."

require "htm"

HTM.configure do |config|
  config.job.backend = :inline
  config.log_level = :info
  config.telemetry_enabled = false
end

begin
  HTM::SequelConfig.establish_connection!
  HTM::Database.setup
  puts "   Schema setup complete."
rescue => e
  abort "   ERROR: #{e.message}"
end

puts <<~FOOTER

  ==========================================
  Examples database is ready!

  You can now run examples:
    ruby examples/01_basic_usage.rb
    rake examples:basic
    rake examples:all
  ==========================================

FOOTER
