# Installation Guide

This guide will walk you through setting up HTM and all its dependencies.

## Prerequisites

Before installing HTM, ensure you have:

- **Ruby 3.0 or higher** - HTM requires modern Ruby features
- **PostgreSQL 17+** - For the database backend
- **Ollama** - For generating vector embeddings (via RubyLLM)

### Check Your Ruby Version

```bash
ruby --version
# Should show: ruby 3.0.0 or higher
```

If you need to install or upgrade Ruby, we recommend using [rbenv](https://github.com/rbenv/rbenv):

```bash
# Install rbenv (macOS)
brew install rbenv ruby-build

# Install Ruby 3.3 (latest stable)
rbenv install 3.3.0
rbenv global 3.3.0
```

## Step 1: Install the HTM Gem

### Option A: Install via Bundler (Recommended)

Add HTM to your application's `Gemfile`:

```ruby
# Gemfile
source 'https://rubygems.org'

gem 'htm'
```

Then install:

```bash
bundle install
```

### Option B: Install Directly

Install HTM directly via RubyGems:

```bash
gem install htm
```

## Step 2: Database Setup

HTM requires PostgreSQL 17+ with the pgvector extension.

### Option A: Local PostgreSQL Installation

#### macOS (using Homebrew)

```bash
# Install PostgreSQL
brew install postgresql@17

# Start PostgreSQL service
brew services start postgresql@17
```

#### Linux (Ubuntu/Debian)

```bash
# Add PostgreSQL repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Install PostgreSQL
sudo apt-get update
sudo apt-get install postgresql-17 postgresql-client-17

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Create Database

```bash
# Create database and user
createdb htm_db
psql htm_db

# In psql console:
CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### Configure Environment Variables

```bash
# Add to ~/.bashrc or your preferred config file
export HTM_DBURL="postgres://username:password@localhost:5432/htm_db"
export HTM_DBNAME="htm_db"
export HTM_DBUSER="your_username"
export HTM_DBPASS="your_password"
export HTM_DBPORT="5432"
export HTM_DBHOST="localhost"

# Load the configuration
source ~/.bashrc
```

!!! tip "Environment Configuration"
    HTM automatically uses the `HTM_DBURL` environment variable if available. You can also pass database configuration directly to `HTM.new()`.

Set environment variable:

```bash
export HTM_DBURL="postgres://localhost/htm_db"
```

## Step 3: Enable PostgreSQL Extensions

HTM requires two PostgreSQL extensions:

- **pgvector**: Vector similarity search
- **pg_trgm**: Full-text search

### Verify Extensions

Test your database connection and verify extensions:

```bash
# Download or use the included test script
cd /path/to/your/project
ruby -e "
require 'pg'
conn = PG.connect(ENV['HTM_DBURL'])
result = conn.exec('SELECT extname, extversion FROM pg_extension ORDER BY extname')
result.each { |row| puts \"✓ #{row['extname']}: Version #{row['extversion']}\" }
conn.close
"
```

Expected output:

```
✓ pg_trgm: Version 1.6
✓ pgvector: Version 0.8.1
```

!!! warning "Missing Extensions"
    If extensions are missing, you may need to install them. On Debian/Ubuntu: `sudo apt-get install postgresql-17-pgvector`. On macOS: `brew install pgvector`.

## Step 4: Install Ollama

HTM uses [Ollama](https://ollama.ai/) via RubyLLM for generating vector embeddings.

### Install Ollama

#### macOS

```bash
# Option 1: Direct download
curl https://ollama.ai/install.sh | sh

# Option 2: Homebrew
brew install ollama
```

#### Linux

```bash
curl https://ollama.ai/install.sh | sh
```

#### Windows

Download the installer from [https://ollama.ai/download](https://ollama.ai/download)

### Start Ollama Service

```bash
# Ollama typically starts automatically
# Verify it's running:
curl http://localhost:11434/api/version
```

Expected output:

```json
{"version":"0.1.x"}
```

### Pull the gpt-oss Model

HTM uses the `gpt-oss` model by default:

```bash
# Download the model
ollama pull gpt-oss

# Verify the model is available
ollama list
```

You should see `gpt-oss` in the list.

### Test Embedding Generation

```bash
# Test that embeddings work
ollama run gpt-oss "Hello, world!"
```

### Custom Ollama URL (Optional)

If Ollama is running on a different host or port:

```bash
export OLLAMA_URL="http://custom-host:11434"
```

!!! tip "Ollama Model Selection"
    HTM defaults to `gpt-oss`, but you can use any embedding model supported by Ollama. Just pass `embedding_model: 'your-model'` to `HTM.new()`.

## Step 5: Initialize HTM Database Schema

Run the database setup to create HTM's tables and schema:

### Option A: Using htm_mcp CLI (Recommended)

```bash
# Initialize the database schema
htm_mcp setup

# Verify the setup
htm_mcp verify
```

### Option B: Using Ruby

```ruby
require 'htm'

# Run database setup
HTM::Database.setup
```

### Option C: Using Rake Task (if available)

```bash
rake htm:db:setup
```

This creates the following tables:

- **`nodes`**: Main memory storage with vector embeddings
- **`tags`**: Hierarchical categorization
- **`robots`**: Robot registry
- **`file_sources`**: Source file metadata for loaded documents

!!! success "Schema Created"
    You'll see confirmation messages as each table and index is created.

### htm_mcp CLI Commands

The `htm_mcp` executable provides commands for database management:

| Command | Description |
|---------|-------------|
| `htm_mcp setup` | Initialize database schema |
| `htm_mcp verify` | Verify connection, extensions, and migrations |
| `htm_mcp stats` | Show memory statistics |
| `htm_mcp help` | Show all commands and environment variables |
| `htm_mcp` | Start the MCP server |

```bash
# Check statistics after setup
htm_mcp stats
```

## Step 6: Verify Installation

Create a test script to verify everything works:

```ruby
# test_htm_setup.rb
require 'htm'

puts "Testing HTM Installation..."

# Initialize HTM
htm = HTM.new(
  robot_name: "Test Robot",
  working_memory_size: 128_000,
  embedding_service: :ollama,
  embedding_model: 'gpt-oss'
)

puts "✓ HTM initialized successfully"
puts "  Robot ID: #{htm.robot_id}"
puts "  Robot Name: #{htm.robot_name}"

# Add a test memory
htm.add_node(
  "test_001",
  "This is a test memory to verify HTM installation.",
  type: :fact,
  importance: 5.0,
  tags: ["test"]
)

puts "✓ Memory node added successfully"

# Retrieve the memory
node = htm.retrieve("test_001")
if node
  puts "✓ Memory retrieval works"
  puts "  Content: #{node['value']}"
else
  puts "✗ Failed to retrieve memory"
end

# Get stats
stats = htm.memory_stats
puts "✓ Memory stats:"
puts "  Total nodes: #{stats[:total_nodes]}"
puts "  Working memory: #{stats[:working_memory][:node_count]} nodes"

# Clean up test data
htm.forget("test_001", confirm: :confirmed)
puts "✓ Memory deletion works"

puts "\n" + "=" * 60
puts "✓ HTM installation verified successfully!"
```

Run the test:

```bash
ruby test_htm_setup.rb
```

## Environment Variables Reference

HTM uses the following environment variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HTM_DBURL` | PostgreSQL connection URL | - | Yes |
| `HTM_DBNAME` | Database name | `htm_db` | No |
| `HTM_DBUSER` | Database user | `postgres` | No |
| `HTM_DBPASS` | Database password | - | No |
| `HTM_DBPORT` | Database port | `5432` | No |
| `OLLAMA_URL` | Ollama API URL | `http://localhost:11434` | No |

### Example Configuration File

Create a configuration file for easy loading:

```bash
# ~/.bashrc__htm
export HTM_DBURL="postgres://user:pass@host:port/db?sslmode=require"
export OLLAMA_URL="http://localhost:11434"
```

Load it in your shell:

```bash
# Add to ~/.bashrc or ~/.zshrc
source ~/.bashrc__htm
```

## Troubleshooting

### Database Connection Issues

**Error**: `PG::ConnectionBad: connection failed`

**Solutions**:

```bash
# 1. Verify HTM_DBURL is set
echo $HTM_DBURL

# 2. Test connection manually
psql $HTM_DBURL

# 3. Check if PostgreSQL is running (local installs)
pg_ctl status

# 4. Verify SSL mode for cloud databases
# Ensure URL includes: ?sslmode=require
```

### Ollama Connection Issues

**Error**: `Connection refused - connect(2) for localhost:11434`

**Solutions**:

```bash
# 1. Check if Ollama is running
curl http://localhost:11434/api/version

# 2. Start Ollama (macOS)
# Check Activity Monitor or menu bar

# 3. Restart Ollama service
killall ollama
ollama serve

# 4. Verify gpt-oss model is installed
ollama list | grep gpt-oss
```

### Missing Extensions

**Error**: `PG::UndefinedObject: extension "pgvector" is not available`

**Solutions**:

```bash
# Install pgvector
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install

# Enable in database
psql $HTM_DBURL -c "CREATE EXTENSION IF NOT EXISTS pgvector;"
```

### Ruby Version Issues

**Error**: `htm requires Ruby version >= 3.0.0`

**Solutions**:

```bash
# Check current version
ruby --version

# Install newer Ruby via rbenv
rbenv install 3.3.0
rbenv global 3.3.0

# Verify
ruby --version
```

### Permission Issues

**Error**: `PG::InsufficientPrivilege: permission denied`

**Solutions**:

```bash
# Ensure your database user has necessary permissions
psql $HTM_DBURL -c "
  GRANT ALL PRIVILEGES ON DATABASE your_db TO your_user;
  GRANT ALL ON ALL TABLES IN SCHEMA public TO your_user;
"
```

## Next Steps

Now that HTM is installed, you're ready to start building:

1. **[Quick Start Guide](quick-start.md)**: Build your first HTM application in 5 minutes
2. **[User Guide](../guides/getting-started.md)**: Learn all HTM features in depth
3. **[API Reference](../api/htm.md)**: Explore the complete API documentation
4. **[Examples](https://github.com/madbomber/htm/tree/main/examples)**: See real-world usage examples

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review [GitHub Issues](https://github.com/madbomber/htm/issues)
3. Open a new issue with:
   - Your Ruby version (`ruby --version`)
   - Your PostgreSQL version (`psql --version`)
   - Error messages and stack traces
   - Steps to reproduce

## Additional Resources

- **Ollama Documentation**: [https://ollama.ai/](https://ollama.ai/)
- **pgvector Documentation**: [https://github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)
- **PostgreSQL Documentation**: [https://www.postgresql.org/docs/](https://www.postgresql.org/docs/)
- **RubyLLM Documentation**: [https://github.com/madbomber/ruby_llm](https://github.com/madbomber/ruby_llm)
