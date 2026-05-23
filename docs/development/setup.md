# Development Setup Guide

This guide will walk you through setting up a complete HTM development environment from scratch.

## Overview

Setting up HTM for development involves:

1. Cloning the repository
2. Installing Ruby and system dependencies
3. Installing Ruby gem dependencies
4. Setting up PostgreSQL database
5. Configuring an LLM provider (Ollama, OpenAI, etc.)
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

## Step 4: Set Up PostgreSQL Database

HTM requires PostgreSQL 16+ with pgvector and pg_trgm extensions. You have two options:

### Option A: Local PostgreSQL (macOS/Homebrew)

```bash
# Install PostgreSQL 17
brew install postgresql@17
brew services start postgresql@17

# Create development database
createdb htm_development

# Enable required extensions
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# Configure environment variables
export HTM_DATABASE__URL="postgresql://$(whoami)@localhost:5432/htm_development"
```

### Option B: Local PostgreSQL with Docker

For Docker-based development:

```bash
# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  postgres:
    image: pgvector/pgvector:pg17
    environment:
      POSTGRES_USER: htm
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: htm_development
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data

volumes:
  pg_data:
EOF

# Start PostgreSQL
docker-compose up -d

# Configure environment variables
export HTM_DATABASE__URL="postgresql://htm:devpassword@localhost:5432/htm_development"
```

### Verify Database Connection

Test your database connection:

```bash
# From the htm directory
rake htm:db:verify
```

Expected output:

```
Connected successfully!
pgvector Extension: Version 0.8.0+
pg_trgm Extension: Version 1.6
```

### Enable Required Extensions

Run the extension setup script if needed:

```bash
ruby enable_extensions.rb
```

This ensures that pgvector and pg_trgm extensions are enabled.

## Step 5: Configure LLM Provider

HTM uses RubyLLM to generate vector embeddings and extract tags. RubyLLM supports multiple providers, so you can choose what works best for your development environment.

### Supported Providers

| Provider | Best For | Setup Required |
|----------|----------|----------------|
| **Ollama** (default) | Local development, privacy | Install Ollama + models |
| **OpenAI** | Production, high-quality | API key only |
| **Anthropic** | Claude models for tags | API key only |
| **Gemini** | Google Cloud users | API key only |

### Option A: Ollama (Recommended for Development)

Ollama runs locally with no API costs.

#### Install Ollama

**macOS:**
```bash
# Direct download
curl https://ollama.ai/install.sh | sh

# Or using Homebrew
brew install ollama
```

**Linux:**
```bash
curl https://ollama.ai/install.sh | sh
```

#### Start Ollama Service

Ollama typically starts automatically. Verify it's running:

```bash
curl http://localhost:11434/api/version
```

If not running:

```bash
# macOS - Check Activity Monitor or start from Applications
# Linux
ollama serve &
```

#### Pull Required Models

```bash
# Pull embedding model
ollama pull nomic-embed-text

# Pull tag extraction model
ollama pull gemma3:latest

# Verify models
ollama list
```

#### Configure Custom URL (Optional)

```bash
export OLLAMA_URL="http://custom-host:11434"
```

### Option B: OpenAI (Recommended for Production)

```bash
export OPENAI_API_KEY="sk-..."
```

Configure in your code:
```ruby
HTM.configure do |config|
  config.embedding.provider = :openai
  config.embedding.model = 'text-embedding-3-small'
end
```

### Option C: Other Providers

Set the appropriate API key:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export GEMINI_API_KEY="..."
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
   Using RubyLLM with configured provider for embeddings
✓ HTM initialized
  Robot ID: robot-abc123
  Robot Name: Code Helper
  Embedding Service: Configured provider via RubyLLM

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
| `HTM_DATABASE__URL` | Full PostgreSQL connection URL (preferred) | `postgresql://user:pass@localhost:5432/htm_development` |
| `HTM_DATABASE__NAME` | Database name | `htm_development` |
| `HTM_DATABASE__USER` | Database username | `postgres` |
| `HTM_DATABASE__PASSWORD` | Database password | `your_password` |
| `HTM_DATABASE__PORT` | Database port | `5432` |
| `HTM_SERVICE__NAME` | Service identifier (for DB naming) | `htm` |

### LLM Provider Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OLLAMA_URL` | Ollama API URL (if using Ollama) | `http://localhost:11434` |
| `OPENAI_API_KEY` | OpenAI API key (if using OpenAI) | `sk-...` |
| `ANTHROPIC_API_KEY` | Anthropic API key (if using Anthropic) | `sk-ant-...` |
| `GEMINI_API_KEY` | Gemini API key (if using Gemini) | `...` |

### Managing Environment Files

You can organize your environment variables using multiple files:

```bash
# ~/.bashrc__tiger - Database configuration
# LLM provider environment variables (set based on your chosen provider)

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

# For Docker, check if container is running
docker ps | grep postgres
```

#### "LLM provider connection failed"

**Symptoms**: Embedding generation fails

**Solutions for Ollama**:

```bash
# Verify Ollama is running
curl http://localhost:11434/api/version

# Start Ollama service
# macOS: Start from Applications or Activity Monitor
# Linux: ollama serve &

# Check if models are downloaded
ollama list | grep nomic-embed-text

# Pull models if missing
ollama pull nomic-embed-text
ollama pull gemma3:latest
```

**Solutions for Cloud Providers**:

```bash
# Verify API key is set
echo $OPENAI_API_KEY
echo $ANTHROPIC_API_KEY

# Test API connectivity
curl https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"
```

#### "Extension not available"

**Symptoms**: Errors about missing pgvector or pg_trgm

**Solutions**:

```bash
# Re-run extension setup
ruby enable_extensions.rb

# Check extension status
psql $HTM_DATABASE__URL -c "SELECT extname, extversion FROM pg_extension ORDER BY extname"

# For local PostgreSQL, install extensions manually:
psql $HTM_DATABASE__URL -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql $HTM_DATABASE__URL -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
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

# Check LLM provider (if using Ollama)
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

# For local development
export HTM_DATABASE__URL="postgresql://user:pass@localhost:5432/htm_development"
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
