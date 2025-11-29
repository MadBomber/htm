# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

task default: :test

# Load HTM database tasks from lib/tasks/htm.rake
# This uses the same loader that external applications use
require_relative "lib/htm/tasks"

# Legacy tasks for backwards compatibility
desc "Run database setup (deprecated: use htm:db:setup)"
task :db_setup => "htm:db:setup"

desc "Test database connection (deprecated: use htm:db:test)"
task :db_test => "htm:db:test"

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
