# frozen_string_literal: true

namespace :db do
  desc "Run database migrations"
  task :migrate do
    require_relative '../htm'

    HTM::Database.migrate
    puts "Database migrations completed successfully"
  end

  desc "Setup database schema (includes migrations)"
  task :setup do
    require_relative '../htm'

    HTM::Database.setup
    puts "Database setup completed successfully"
  end
end
