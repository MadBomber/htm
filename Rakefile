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

desc "Run example"
task :example do
  ruby "examples/basic_usage.rb"
end

desc "Run timeframe demo"
task :timeframe_demo do
  ruby "examples/timeframe_demo.rb"
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
