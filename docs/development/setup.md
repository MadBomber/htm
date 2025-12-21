# Development Setup Guide

This guide will walk you through setting up a complete HTM development environment from scratch.

## Overview

Setting up HTM for development involves:

1. Cloning the repository
2. Installing Ruby and system dependencies
3. Installing Ruby gem dependencies
4. Setting up TimescaleDB database
5. Configuring Ollama for embeddings
6. Verifying your setup
7. Running tests and examples

Let's get started!

## Prerequisites

Before you begin, ensure you have:

- **macOS, Linux, or WSL2** (Windows Subsystem for Linux)
- **Git** installed (`git --version`)
- **Ruby 3.0 or higher** (we'll install this)
- **Internet connection** (for downloading dependencies)

## Step 1: Clone the Repository

### Fork the Repository (Recommended for Contributors)

If you plan to submit pull requests, fork the repository first:

1. Visit [https://github.com/madbomber/htm](https://github.com/madbomber/htm)
2. Click the "Fork" button in the upper right
3. Clone your fork:

```bash
git clone https://github.com/YOUR_USERNAME/htm.git
cd htm
```

### Or Clone Directly (For Read-Only Access)

```bash
git clone https://github.com/madbomber/htm.git
cd htm
```

### Add Upstream Remote (For Forked Repos)

If you forked, add the original repository as upstream:

```bash
git remote add upstream https://github.com/madbomber/htm.git
git fetch upstream
```

## Step 2: Install Ruby

HTM requires Ruby 3.0 or higher. We recommend using **rbenv** for managing Ruby versions.

### Check Current Ruby Version

```bash
ruby --version
# Example output: ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin23]
```

If you already have Ruby 3.0+, you can skip to Step 3.

### Install rbenv (macOS)

```bash
# Install rbenv and ruby-build
brew install rbenv ruby-build

# Initialize rbenv in your shell
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
rbenv --version
```

### Install rbenv (Linux)

```bash
# Clone rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv

# Add to PATH
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc

# Install ruby-build
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
```

### Install Ruby 3.3 (Latest Stable)

```bash
# List available Ruby versions
rbenv install --list

# Install Ruby 3.3.0 (or latest 3.x version)
rbenv install 3.3.0

# Set as global default
rbenv global 3.3.0

# Verify installation
ruby --version
# Should show: ruby 3.3.0
```

## Step 3: Install Ruby Dependencies

HTM uses Bundler to manage Ruby gem dependencies.

### Install Bundler

```bash
gem install bundler

# Verify installation
bundle --version
```

### Install Project Dependencies

```bash
# From the htm directory
bundle install
```

This will install:

- **pg**: PostgreSQL adapter
- **pgvector**: Vector similarity search support
- **connection_pool**: Database connection pooling
- **tiktoken_ruby**: Token counting for working memory
- **ruby_llm**: LLM client for embeddings
- **rake**: Task automation
- **minitest**: Testing framework
- **minitest-reporters**: Test output formatting
- **debug_me**: Debugging utility

### Verify Installation

```bash
bundle exec ruby -e "require 'htm'; puts HTM::VERSION"
# Should output: 0.1.0 (or current version)
```

## Step 4: Set Up TimescaleDB Database

HTM requires PostgreSQL with TimescaleDB and pgvector extensions. You have two options:

### Option A: TimescaleDB Cloud (Recommended for Quick Start)

This is the fastest way to get a working database:

#### 1. Create Account

Visit [https://www.timescale.com/](https://www.timescale.com/) and sign up for a free account.

#### 2. Create Service

- Click "Create Service"
- Select your region (choose closest to you)
- Choose the **Free Tier** (or your preferred plan)
- Click "Create Service"
- Wait 2-3 minutes for provisioning

#### 3. Get Connection Details

- Click on your new service
- Click "Connection Info"
- Copy the full connection string (looks like `postgres://username:password@host:port/database?sslmode=require`)

#### 4. Configure Environment Variables

Create or edit `~/.bashrc__tiger`:

```bash
# TimescaleDB Connection Configuration
export HTM_SERVICE_NAME="db-67977"  # Your service name
export HTM_DATABASE__NAME="tsdb"
export HTM_DATABASE__USER="tsdbadmin"
export HTM_DATABASE__PASSWORD="your_password_here"
export HTM_DATABASE__PORT="37807"  # Your port number
export HTM_DATABASE__URL="postgres://tsdbadmin:your_password@host:port/tsdb?sslmode=require"
```

Replace the placeholders with your actual connection details.

#### 5. Load Environment Variables

```bash
# Load configuration
source ~/.bashrc__tiger

# Optionally, add to your ~/.bashrc for automatic loading
echo 'source ~/.bashrc__tiger' >> ~/.bashrc
```

### Option B: Local PostgreSQL with Docker (Advanced)

For local development with Docker:

```bash
# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  timescaledb:
    image: timescale/timescaledb-ha:pg17
    environment:
      POSTGRES_USER: tsdbadmin
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: tsdb
    ports:
      - "5432:5432"
    volumes:
      - timescale_data:/var/lib/postgresql/data

volumes:
  timescale_data:
EOF

# Start TimescaleDB
docker-compose up -d

# Configure environment variables
cat > ~/.bashrc__tiger <<'EOF'
export HTM_SERVICE_NAME="local-dev"
export HTM_DATABASE__NAME="tsdb"
export HTM_DATABASE__USER="tsdbadmin"
export HTM_DATABASE__PASSWORD="devpassword"
export HTM_DATABASE__PORT="5432"
export HTM_DATABASE__URL="postgres://tsdbadmin:devpassword@localhost:5432/tsdb?sslmode=disable"
EOF

source ~/.bashrc__tiger
```

### Verify Database Connection

Test your database connection:

```bash
# From the htm directory
ruby test_connection.rb
```

Expected output:

```
Connected successfully!
TimescaleDB Extension: Version 2.22.1
pgvector Extension: Version 0.8.1
pg_trgm Extension: Version 1.6
```

### Enable Required Extensions

Run the extension setup script:

```bash
ruby enable_extensions.rb
```

This ensures that TimescaleDB, pgvector, and pg_trgm extensions are enabled.

## Step 5: Set Up Ollama for Embeddings

HTM uses Ollama (via RubyLLM) to generate vector embeddings for semantic search.

### Install Ollama

#### macOS

```bash
# Download and install from official site
curl https://ollama.ai/install.sh | sh

# Or using Homebrew
brew install ollama
```

#### Linux

```bash
curl https://ollama.ai/install.sh | sh
```

### Start Ollama Service

Ollama typically starts automatically after installation. Verify it's running:

```bash
# Check if Ollama is running
curl http://localhost:11434/api/version

# Expected output:
# {"version":"0.1.x"}
```

If not running, start it manually:

```bash
# macOS - Ollama runs as a background service
# Check Activity Monitor or start from Applications

# Linux
ollama serve &
```

### Pull the gpt-oss Model

HTM uses the `gpt-oss` model by default:

```bash
# Pull the model (downloads ~4GB)
ollama pull gpt-oss

# Verify the model is available
ollama list
# Should show gpt-oss in the list
```

### Test Embedding Generation

```bash
# Test that embeddings work
ollama run gpt-oss "Hello, HTM!"
```

### Optional: Configure Custom Ollama URL

If Ollama is running on a different host or port:

```bash
# Add to ~/.bashrc__tiger
export OLLAMA_URL="http://custom-host:11434"
```

## Step 6: Initialize Database Schema

Now that everything is set up, initialize the HTM database schema:

```bash
# Run database setup
rake db_setup
```

This creates all required tables, indexes, views, and triggers. See the [Schema Documentation](schema.md) for details.

### Alternative: Manual Setup

You can also run the schema SQL directly:

```bash
# Using psql
psql $HTM_DATABASE__URL -f sql/schema.sql

# Or using Ruby
ruby -r ./lib/htm -e "HTM::Database.setup"
```

## Step 7: Verify Your Setup

Let's make sure everything is working correctly.

### Run the Test Suite

```bash
# Run all tests
rake test
```

Expected output:

```
HTMTest
  test_version_exists                             PASS (0.00s)
  test_version_format                             PASS (0.00s)
  test_htm_class_exists                           PASS (0.00s)
  ...

Finished in 0.05s
12 tests, 0 failures, 0 errors, 0 skips
```

### Run Integration Tests

Integration tests require a working database:

```bash
ruby test/integration_test.rb
```

### Run the Example

Test the full workflow with a real example:

```bash
rake example

# Or directly
ruby examples/basic_usage.rb
```

Expected output:

```
HTM Basic Usage Example
============================================================

1. Initializing HTM for 'Code Helper' robot...
   Using RubyLLM with Ollama provider and gpt-oss model for embeddings
✓ HTM initialized
  Robot ID: robot-abc123
  Robot Name: Code Helper
  Embedding Service: Ollama (gpt-oss via RubyLLM)

2. Adding memory nodes...
✓ Added decision about database choice
✓ Added decision about RAG approach
✓ Added fact about user preferences
...
```

## Development Tools

HTM includes several Rake tasks to streamline development:

### Available Rake Tasks

```bash
# Show all available tasks
rake --tasks

# Output:
# rake db_setup    # Run database setup
# rake db_test     # Test database connection
# rake example     # Run example
# rake stats       # Show gem statistics
# rake test        # Run tests
```

### Common Development Commands

```bash
# Run all tests
rake test

# Test database connection
rake db_test

# Run example
rake example

# Show code statistics
rake stats

# Setup database schema
rake db_setup
```

## Environment Configuration

HTM uses environment variables for configuration. Here's a complete reference:

### Database Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `HTM_DATABASE__URL` | Full PostgreSQL connection URL (preferred) | `postgres://user:pass@host:port/db?sslmode=require` |
| `HTM_DATABASE__NAME` | Database name | `tsdb` |
| `HTM_DATABASE__USER` | Database username | `tsdbadmin` |
| `HTM_DATABASE__PASSWORD` | Database password | `your_password` |
| `HTM_DATABASE__PORT` | Database port | `37807` |
| `HTM_SERVICE_NAME` | Service identifier (informational) | `db-67977` |

### Ollama Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OLLAMA_URL` | Ollama API URL (optional) | `http://localhost:11434` |

### Managing Environment Files

You can organize your environment variables using multiple files:

```bash
# ~/.bashrc__tiger - Database configuration
# ~/.bashrc__ollama - Ollama configuration (if needed)

# Load all configuration files in ~/.bashrc
source ~/.bashrc__tiger
```

## Troubleshooting

### Common Setup Issues

#### "Cannot connect to database"

**Symptoms**: Connection refused or timeout errors

**Solutions**:

```bash
# Verify environment variables are set
echo $HTM_DATABASE__URL

# Test connection directly with psql
psql $HTM_DATABASE__URL

# Check if service is running (TimescaleDB Cloud)
# Visit your Timescale Cloud dashboard

# For Docker, check if container is running
docker ps | grep timescale
```

#### "Ollama connection refused"

**Symptoms**: Embedding generation fails

**Solutions**:

```bash
# Verify Ollama is running
curl http://localhost:11434/api/version

# Start Ollama service
# macOS: Start from Applications or Activity Monitor
# Linux: ollama serve &

# Check if model is downloaded
ollama list | grep gpt-oss

# Pull model if missing
ollama pull gpt-oss
```

#### "Extension not available"

**Symptoms**: Errors about missing TimescaleDB or pgvector

**Solutions**:

```bash
# Re-run extension setup
ruby enable_extensions.rb

# Check extension status
psql $HTM_DATABASE__URL -c "SELECT extname, extversion FROM pg_extension ORDER BY extname"

# For TimescaleDB Cloud, extensions should be pre-installed
# For local PostgreSQL, ensure you're using timescale/timescaledb-ha image
```

#### "Bundle install fails"

**Symptoms**: Gem installation errors

**Solutions**:

```bash
# Ensure you have development tools
# macOS:
xcode-select --install

# Linux (Ubuntu/Debian):
sudo apt-get install build-essential libpq-dev

# Update RubyGems and Bundler
gem update --system
gem install bundler

# Clear bundle cache and retry
bundle clean --force
bundle install
```

#### "Test failures"

**Symptoms**: Tests fail with database or connection errors

**Solutions**:

```bash
# Ensure database is set up
rake db_setup

# Verify environment variables
source ~/.bashrc__tiger
env | grep TIGER

# Check Ollama is running
curl http://localhost:11434/api/version

# Run tests with verbose output
rake test TESTOPTS="-v"
```

### SSL/TLS Issues

If you see SSL certificate errors:

```bash
# Ensure sslmode is set in connection URL
echo $HTM_DATABASE__URL | grep sslmode
# Should show: sslmode=require

# For local development without SSL
export HTM_DATABASE__URL="postgres://user:pass@localhost:5432/tsdb?sslmode=disable"
```

### Ruby Version Issues

If you see Ruby version errors:

```bash
# Check Ruby version
ruby --version

# Update to Ruby 3.3
rbenv install 3.3.0
rbenv global 3.3.0

# Reinstall gems
bundle install
```

## Development Best Practices

### Keep Your Fork Updated

If you forked the repository, regularly sync with upstream:

```bash
# Fetch upstream changes
git fetch upstream

# Merge into your main branch
git checkout main
git merge upstream/main

# Push to your fork
git push origin main
```

### Use Feature Branches

Always create a branch for your changes:

```bash
# Create and switch to feature branch
git checkout -b feature/my-new-feature

# Make changes, commit, push
git add .
git commit -m "Add my new feature"
git push origin feature/my-new-feature
```

### Run Tests Before Committing

Always run the test suite before committing:

```bash
# Run all tests
rake test

# If tests pass, commit
git commit -m "Your commit message"
```

### Use debug_me for Debugging

HTM uses the `debug_me` gem for debugging. Don't use `puts` statements:

```ruby
require 'debug_me'

def some_method(param)
  debug_me { [ :param ] }  # Outputs: param = "value"

  # For simple strings
  debug_me "Reached this point in execution"

  # Your code here
end
```

## Next Steps

Now that your development environment is set up:

1. **[Learn about Testing](testing.md)**: Understand HTM's test suite and write your own tests
2. **[Read Contributing Guide](contributing.md)**: Learn our workflow and submit your first PR
3. **[Explore the Schema](schema.md)**: Understand the database architecture
4. **[Check the Roadmap](../architecture/index.md)**: See what features are planned

## Getting Help

If you encounter issues not covered here:

- **Check existing issues**: [GitHub Issues](https://github.com/madbomber/htm/issues)
- **Ask in discussions**: [GitHub Discussions](https://github.com/madbomber/htm/discussions)
- **Review planning docs**: See `htm_teamwork.md` for design decisions

Happy developing! We look forward to your contributions.
