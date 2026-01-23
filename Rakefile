# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

# Prepend environment setup before test runs
Rake::Task[:test].enhance [:set_test_env]

task :set_test_env do
  ENV['HTM_ENV'] = 'test'

  # Build test database name from service name + environment
  # Uses HTM_SERVICE__NAME env var if set, otherwise defaults to 'htm'
  service_name = ENV['HTM_SERVICE__NAME'] || 'htm'
  test_db_name = "#{service_name}_test"

  # ALWAYS use the test database - never allow tests to run against other databases
  # This prevents accidental pollution of development/production data
  test_db_url = "postgresql://#{ENV['USER']}@localhost:5432/#{test_db_name}"

  if ENV['HTM_DATABASE__URL'] && !ENV['HTM_DATABASE__URL'].include?('_test')
    warn "WARNING: HTM_DATABASE__URL was set to '#{ENV['HTM_DATABASE__URL']}'"
    warn "         Overriding to use test database: #{test_db_url}"
  end

  ENV['HTM_DATABASE__URL'] = test_db_url
end

task default: :test

# Load HTM database tasks from lib/tasks/htm.rake
# This uses the same loader that external applications use
require_relative "lib/htm/tasks"

# =============================================================================
# Examples Tasks
# =============================================================================

# Prepend environment setup before running any example
task :set_examples_env do
  ENV['HTM_ENV'] = 'examples'

  # Build examples database name from service name + environment
  service_name = ENV['HTM_SERVICE__NAME'] || 'htm'
  examples_db_name = "#{service_name}_examples"

  # ALWAYS use the examples database
  examples_db_url = "postgresql://#{ENV['USER']}@localhost:5432/#{examples_db_name}"

  if ENV['HTM_DATABASE__URL'] && !ENV['HTM_DATABASE__URL'].include?('_examples')
    warn "WARNING: HTM_DATABASE__URL was set to '#{ENV['HTM_DATABASE__URL']}'"
    warn "         Overriding to use examples database: #{examples_db_url}"
  end

  ENV['HTM_DATABASE__URL'] = examples_db_url
end

namespace :examples do
  desc "Set up examples database (create + setup schema)"
  task setup: :set_examples_env do
    Rake::Task['htm:db:create'].invoke rescue nil
    Rake::Task['htm:db:setup'].invoke
  end

  desc "Reset examples database (drop + create + setup)"
  task reset: :set_examples_env do
    Rake::Task['htm:db:reset'].invoke
  end

  desc "Run basic_usage example"
  task basic: :set_examples_env do
    ruby "examples/01_basic_usage.rb"
  end

  desc "Run all standalone examples"
  task :all => :set_examples_env do
    examples = %w[
      examples/01_basic_usage.rb
      examples/03_custom_llm_configuration.rb
      examples/04_file_loader_usage.rb
      examples/05_timeframe_demo.rb
    ]
    examples.each do |example|
      if File.exist?(example)
        puts "\n#{'=' * 60}"
        puts "Running: #{example}"
        puts "#{'=' * 60}"
        ruby example
      end
    end
  end

  desc "Show examples database status"
  task status: :set_examples_env do
    require_relative 'lib/htm'
    puts "Examples Environment Status"
    puts "=" * 40
    puts "HTM_ENV: #{ENV['HTM_ENV']}"
    puts "Database URL: #{ENV['HTM_DATABASE__URL']}"
    puts "Expected database: #{HTM.config.expected_database_name}"
    if HTM.config.database_configured?
      puts "Database configured: Yes"
      begin
        HTM::ActiveRecordConfig.establish_connection!
        if HTM::ActiveRecordConfig.connected?
          puts "Database connected: Yes"
          puts "\nTable counts:"
          %w[nodes robots tags file_sources].each do |table|
            count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first['count']
            puts "  #{table}: #{count}"
          end
        else
          puts "Database connected: No"
        end
      rescue => e
        puts "Database connected: No (#{e.message})"
      end
    else
      puts "Database configured: No"
    end
  end
end

desc "Run example (alias for examples:basic)"
task :example => 'examples:basic'

desc "Run timeframe demo"
task :timeframe_demo do
  ruby "examples/05_timeframe_demo.rb"
end

desc "Show gem stats"
task :stats do
  puts "\nHTM Gem Statistics:"
  puts "=" * 60

  # Count lines of code
  lib_files = Dir.glob("lib/**/*.rb")
  lib_lines = lib_files.sum { |f| File.readlines(f).size }

  test_files = Dir.glob("test/**/*.rb")
  test_lines = test_files.sum { |f| File.readlines(f).size }

  puts "Library:"
  puts "  Files: #{lib_files.size}"
  puts "  Lines: #{lib_lines}"
  puts "\nTests:"
  puts "  Files: #{test_files.size}"
  puts "  Lines: #{test_lines}"
  puts "\nTotal lines: #{lib_lines + test_lines}"
  puts "=" * 60
end
