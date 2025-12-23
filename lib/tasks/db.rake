# frozen_string_literal: true

namespace :db do
  desc "Run database migrations"
  task :migrate do

    HTM::Database.migrate
    puts "Database migrations completed successfully"
  end

  desc "Setup database schema (includes migrations)"
  task :setup do

    HTM::Database.setup
    puts "Database setup completed successfully"
  end
end
