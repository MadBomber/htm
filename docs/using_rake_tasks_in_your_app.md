# Using HTM Rake Tasks in Your Application

HTM provides a set of database management rake tasks that can be easily integrated into any application using the gem.

## Quick Setup

Add this **single line** to your application's `Rakefile`:

```ruby
require 'htm/tasks'
```

That's it! All HTM database tasks are now available in your application.

## Example Rakefile

```ruby
# Your application's Rakefile

require 'bundler/setup'

# Load HTM database tasks
require 'htm/tasks'

# Your application's custom tasks
namespace :app do
  desc "Run your app"
  task :run do
    # your code here
  end
end

task default: :run
```

## Available Tasks

Once `require 'htm/tasks'` is added, you have access to all HTM database tasks:

```bash
# List all HTM tasks
rake -T htm

# Database management
rake htm:db:setup      # Set up HTM database schema and run migrations
rake htm:db:migrate    # Run pending database migrations
rake htm:db:status     # Show migration status
rake htm:db:info       # Show database info
rake htm:db:test       # Test database connection
rake htm:db:console    # Open PostgreSQL console
rake htm:db:seed       # Seed database with sample data
rake htm:db:drop       # Drop all HTM tables (destructive!)
rake htm:db:reset      # Drop and recreate database (destructive!)
```

## Environment Configuration

HTM tasks require database configuration via environment variables. You have several options:

### Option 1: Using direnv (Recommended)

Create a `.envrc` file in your application's root:

```bash
# .envrc
export HTM_DBURL="postgresql://user:password@host:port/dbname?sslmode=require"

# Or use individual parameters
export HTM_DBHOST="your-host.tsdb.cloud.timescale.com"
export HTM_DBPORT="37807"
export HTM_DBNAME="tsdb"
export HTM_DBUSER="tsdbadmin"
export HTM_DBPASS="your_password"

# Embedding configuration
export HTM_EMBEDDINGS_PROVIDER=ollama
export HTM_EMBEDDINGS_MODEL=nomic-embed-text
export HTM_EMBEDDINGS_BASE_URL=http://localhost:11434
export HTM_EMBEDDINGS_DIMENSION=768

# Topic extraction configuration
export HTM_TOPIC_PROVIDER=ollama
export HTM_TOPIC_MODEL=llama3
export HTM_TOPIC_BASE_URL=http://localhost:11434
```

Then enable direnv:

```bash
direnv allow
```

### Option 2: Export in Shell

```bash
export HTM_DBURL="postgresql://user:password@host:port/dbname?sslmode=require"
rake htm:db:info
```

### Option 3: In Your Rakefile

```ruby
# Rakefile

# Set environment variables programmatically
ENV['HTM_DBURL'] = "postgresql://user:password@host:port/dbname?sslmode=require"

# Then load tasks
require 'htm/tasks'
```

### Option 4: Use dotenv gem

```ruby
# Gemfile
gem 'dotenv'

# Rakefile
require 'dotenv/load'  # Loads .env file
require 'htm/tasks'
```

```bash
# .env
HTM_DBURL=postgresql://user:password@host:port/dbname?sslmode=require
```

## Real-World Example

Here's a complete example for a Rails-like application:

```ruby
# Rakefile for MyApp

require 'bundler/setup'
require 'dotenv/load'  # Load .env file

# Load HTM database tasks
require 'htm/tasks'

# Application tasks
namespace :app do
  desc "Start the application"
  task :start do
    require_relative 'lib/my_app'
    MyApp.start
  end

  desc "Run database migrations and start app"
  task :bootstrap => ['htm:db:setup', :start]
end

# Default task
task default: 'app:start'

# Development helper
namespace :dev do
  desc "Reset database and restart (development only!)"
  task :reset => ['htm:db:reset', 'htm:db:seed', 'app:start']
end
```

Usage:

```bash
# First time setup
rake app:bootstrap              # Sets up HTM database + starts app

# Development reset
rake dev:reset                  # Drops/recreates database + seeds data

# Normal start
rake                            # Runs default task (app:start)

# Database management
rake htm:db:info                # Check database status
rake htm:db:migrate             # Run new migrations
```

## Task Composition

You can compose HTM tasks with your own:

```ruby
# Your Rakefile

require 'htm/tasks'

namespace :deploy do
  desc "Deploy application to production"
  task :production do
    # Run HTM migrations first
    Rake::Task['htm:db:migrate'].invoke

    # Then deploy your app
    sh "git push production main"
    sh "ssh production 'systemctl restart myapp'"
  end
end
```

## Rails Integration

For Rails applications, add to your `Rakefile`:

```ruby
# Rakefile (Rails)

require_relative 'config/application'

Rails.application.load_tasks

# Load HTM tasks
require 'htm/tasks'
```

Now you have both Rails tasks and HTM tasks:

```bash
rake db:migrate            # Rails migrations
rake htm:db:migrate        # HTM migrations

rake db:seed               # Rails seed
rake htm:db:seed           # HTM seed
```

## Sinatra Integration

```ruby
# Rakefile (Sinatra)

require './app'  # Your Sinatra app
require 'htm/tasks'

namespace :server do
  desc "Start Sinatra server"
  task :start do
    App.run!
  end
end

task default: 'server:start'
```

## Testing Integration

Add HTM database setup to your test tasks:

```ruby
# Rakefile

require 'rake/testtask'
require 'htm/tasks'

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end

# Set up test database before running tests
task :test => 'htm:db:setup'
```

## CI/CD Pipeline

Example GitHub Actions workflow:

```yaml
# .github/workflows/test.yml

name: Tests
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: timescale/timescaledb-ha:pg17
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v2

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3
          bundler-cache: true

      - name: Setup database
        env:
          HTM_DBURL: postgresql://postgres:postgres@localhost:5432/test
        run: |
          bundle exec rake htm:db:setup

      - name: Run tests
        env:
          HTM_DBURL: postgresql://postgres:postgres@localhost:5432/test
        run: |
          bundle exec rake test
```

## Docker Integration

In your `docker-compose.yml`:

```yaml
services:
  app:
    build: .
    environment:
      - HTM_DBURL=postgresql://postgres:postgres@db:5432/myapp
    depends_on:
      - db
    command: bash -c "rake htm:db:setup && rake app:start"

  db:
    image: timescale/timescaledb-ha:pg17
    environment:
      - POSTGRES_PASSWORD=postgres
```

## Troubleshooting

### Tasks not available

```bash
rake -T
# If you don't see htm:db tasks, check:
```

1. Verify `require 'htm/tasks'` is in your Rakefile
2. Check that `htm` gem is in your Gemfile
3. Run `bundle install`

### Database not configured

```
Error: Database configuration not found
```

Solution: Set `HTM_DBURL` environment variable

```bash
export HTM_DBURL="postgresql://user:password@host:port/dbname"
rake htm:db:info
```

### Permission errors

```
Error: permission denied for table nodes
```

Solution: Ensure your database user has proper permissions

```sql
GRANT ALL ON ALL TABLES IN SCHEMA public TO your_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO your_user;
```

## Best Practices

1. **Always use environment variables** for database configuration (never hardcode credentials)
2. **Use `htm:db:migrate`** instead of `htm:db:setup` in production (setup drops tables)
3. **Run `htm:db:status`** before deploying to check migration state
4. **Never use `htm:db:reset`** or `htm:db:drop` in production
5. **Compose tasks** rather than duplicating functionality
6. **Test migrations** on staging before production

## See Also

- [Database Rake Tasks Reference](database_rake_tasks.md) - Complete task documentation
- [README.md](https://github.com/madbomber/htm/blob/main/README.md) - HTM gem overview
- [SETUP.md](https://github.com/madbomber/htm/blob/main/SETUP.md) - Initial setup guide
