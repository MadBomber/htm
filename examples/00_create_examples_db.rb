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

puts <<~HEADER

  ==========================================
  == HTM Examples Database Setup ==
  ==========================================

  Database: #{db_name}

HEADER

# Step 1: Create database if it doesn't exist
puts "1. Checking if database exists..."

check_cmd = "psql -lqt | cut -d \\| -f 1 | grep -qw #{db_name}"
db_exists = system(check_cmd)

if db_exists
  puts "   Database '#{db_name}' already exists."
else
  puts "   Creating database '#{db_name}'..."
  unless system("createdb #{db_name}")
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

unless system("psql -d #{db_name} -c \"#{extensions_sql}\" > /dev/null 2>&1")
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
    ruby examples/basic_usage.rb
    rake examples:basic
    rake examples:all
  ==========================================

FOOTER
