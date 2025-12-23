# frozen_string_literal: true

# Examples Helper - Ensures all examples use the htm_examples database
#
# This file must be required at the top of every example file before loading HTM.
# It enforces database isolation to prevent examples from polluting development
# or production databases.
#
# Usage:
#   require_relative 'examples_helper'  # For files in examples/
#   require_relative '../examples_helper'  # For files in examples/subdirectory/
#
# This sets:
#   - HTM_ENV=examples
#   - HTM_DATABASE__URL to point to htm_examples database
#
# Before running examples:
#   1. Create the examples database: createdb htm_examples
#   2. Set up schema: HTM_ENV=examples rake htm:db:setup
#   3. Run example: ruby examples/basic_usage.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Set examples environment BEFORE loading HTM
# This is critical because HTM::Config reads environment at load time
# Note: 'examples' is not in the gem's defaults.yml - it's configured here
ENV['HTM_ENV'] = 'examples'

# Build examples database name from service name + environment
# Uses HTM_SERVICE__NAME env var if set, otherwise defaults to 'htm'
service_name = ENV['HTM_SERVICE__NAME'] || 'htm'
examples_db_name = "#{service_name}_examples"

# Safety check: Refuse to run examples against non-examples databases
# Database name must end with _examples (e.g., htm_examples, myapp_examples)
if ENV['HTM_DATABASE__URL'] && !ENV['HTM_DATABASE__URL'].include?('_examples')
  abort <<~ERROR
    SAFETY CHECK FAILED: Examples must run against an examples database!

    HTM_DATABASE__URL is set to: #{ENV['HTM_DATABASE__URL']}

    This does not appear to be an examples database (must contain '_examples').
    Running examples against development or production databases can corrupt data.

    To fix, either:
      1. Unset HTM_DATABASE__URL and let this helper configure it
      2. Set: export HTM_DATABASE__URL="postgresql://#{ENV['USER']}@localhost:5432/#{examples_db_name}"

  ERROR
end

# ALWAYS use the examples database - never allow examples to run against other databases
examples_db_url = "postgresql://#{ENV['USER']}@localhost:5432/#{examples_db_name}"
ENV['HTM_DATABASE__URL'] = examples_db_url

# Load HTM first
require "htm"

# Configure HTM for examples environment
# This keeps the 'examples' environment configuration out of the gem's bundled defaults
HTM.configure do |config|
  # Use inline job backend for synchronous execution (clearer output)
  config.job.backend = :inline

  # Set log level for examples
  config.log_level = :info

  # Disable telemetry for examples
  config.telemetry_enabled = false
end

# Module with helper methods for examples
module ExamplesHelper
  # Check if database is available and configured
  #
  # @return [Boolean] true if database is ready
  def self.database_ready?
    return false unless HTM.config.database_configured?

    begin
      HTM::ActiveRecordConfig.establish_connection!
      HTM::ActiveRecordConfig.connected?
    rescue => e
      false
    end
  end

  # Verify database is ready or print helpful error message
  #
  # @return [void] exits with error if database not ready
  def self.require_database!
    unless database_ready?
      abort <<~ERROR
        ERROR: Examples database not available.

        Please set up the examples database:
          1. createdb htm_examples
          2. HTM_ENV=examples rake htm:db:setup

        Then run the example again.
      ERROR
    end
  end

  # Print a section header
  #
  # @param title [String] section title
  def self.section(title)
    border = "=" * (title.size + 6)
    puts
    puts border
    puts "== #{title} =="
    puts border
    puts
  end

  # Print a success message
  #
  # @param message [String] success message
  def self.success(message)
    puts "[OK] #{message}"
  end

  # Print an info message
  #
  # @param message [String] info message
  def self.info(message)
    puts "[..] #{message}"
  end

  # Print environment info
  def self.print_environment
    puts "Environment: #{HTM.config.environment}"
    puts "Database: #{HTM.config.actual_database_name}"
    puts "Job Backend: #{HTM.config.job.backend}"
  end
end
