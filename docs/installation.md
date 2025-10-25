# Installation Guide

This guide will walk you through setting up HTM and all its dependencies.

## Prerequisites

Before installing HTM, ensure you have:

- **Ruby 3.0 or higher** - HTM requires modern Ruby features
- **PostgreSQL 17+** - For the database backend
- **TimescaleDB** - PostgreSQL extension for time-series optimization
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

HTM requires PostgreSQL with TimescaleDB extensions. You have two options:

### Option A: TimescaleDB Cloud (Recommended for Quick Start)

The easiest way to get started is using [TimescaleDB Cloud](https://www.timescale.com/):

1. **Create a Free Account**: Sign up at [https://www.timescale.com/](https://www.timescale.com/)

2. **Create a Service**:
   - Click "Create Service"
   - Select your region (choose closest to you)
   - Choose the free tier or your preferred plan
   - Wait for provisioning (2-3 minutes)

3. **Get Connection Details**:
   - Click on your service
   - Copy the connection string (looks like `postgres://username:password@host:port/database?sslmode=require`)

4. **Save Connection URL**:

```bash
# Add to ~/.bashrc__tiger (or your preferred config file)
export TIGER_DBURL="postgres://username:password@host:port/tsdb?sslmode=require"
export TIGER_DBNAME="tsdb"
export TIGER_DBUSER="tsdbadmin"
export TIGER_DBPASS="your_password"
export TIGER_DBPORT="37807"
export TIGER_SERVICE_NAME="your_service_name"

# Load the configuration
source ~/.bashrc__tiger
```

!!! tip "Environment Configuration"
    HTM automatically uses the `TIGER_DBURL` environment variable if available. You can also pass database configuration directly to `HTM.new()`.

### Option B: Local PostgreSQL Installation

If you prefer running PostgreSQL locally:

#### macOS (using Homebrew)

```bash
# Install PostgreSQL
brew install postgresql@17

# Start PostgreSQL service
brew services start postgresql@17

# Install TimescaleDB
brew tap timescale/tap
brew install timescaledb

# Run TimescaleDB setup
timescaledb-tune --quiet --yes

# Restart PostgreSQL
brew services restart postgresql@17
```

#### Linux (Ubuntu/Debian)

```bash
# Add PostgreSQL repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Install PostgreSQL
sudo apt-get update
sudo apt-get install postgresql-17 postgresql-client-17

# Add TimescaleDB repository
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list

# Install TimescaleDB
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
sudo apt-get update
sudo apt-get install timescaledb-2-postgresql-17

# Configure TimescaleDB
sudo timescaledb-tune

# Restart PostgreSQL
sudo systemctl restart postgresql
```

#### Create Database

```bash
# Create database and user
createdb htm_db
psql htm_db

# In psql console:
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

Set environment variable:

```bash
export TIGER_DBURL="postgres://localhost/htm_db"
```

## Step 3: Enable PostgreSQL Extensions

HTM requires three PostgreSQL extensions:

- **TimescaleDB**: Time-series optimization
- **pgvector**: Vector similarity search
- **pg_trgm**: Full-text search

### Verify Extensions

Test your database connection and verify extensions:

```bash
# Download or use the included test script
cd /path/to/your/project
ruby -e "
require 'pg'
conn = PG.connect(ENV['TIGER_DBURL'])
result = conn.exec('SELECT extname, extversion FROM pg_extension ORDER BY extname')
result.each { |row| puts \"✓ #{row['extname']}: Version #{row['extversion']}\" }
conn.close
"
```

Expected output:

```
✓ pg_trgm: Version 1.6
✓ pgvector: Version 0.8.1
✓ timescaledb: Version 2.22.1
```

!!! warning "Missing Extensions"
    If extensions are missing, contact your database administrator or TimescaleDB Cloud support. Most cloud services include these extensions by default.

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

### Option A: Using Ruby

```ruby
require 'htm'

# Run database setup
HTM::Database.setup
```

### Option B: Using Command Line

```bash
ruby -r ./lib/htm -e "HTM::Database.setup"
```

### Option C: Using Rake Task (if available)

```bash
rake db:setup
```

This creates the following tables:

- **`nodes`**: Main memory storage with vector embeddings
- **`relationships`**: Knowledge graph connections
- **`tags`**: Flexible categorization
- **`robots`**: Robot registry
- **`operations_log`**: Audit trail (TimescaleDB hypertable)

!!! success "Schema Created"
    You'll see confirmation messages as each table and index is created.

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
| `TIGER_DBURL` | PostgreSQL connection URL | - | Yes |
| `TIGER_DBNAME` | Database name | `tsdb` | No |
| `TIGER_DBUSER` | Database user | `tsdbadmin` | No |
| `TIGER_DBPASS` | Database password | - | No |
| `TIGER_DBPORT` | Database port | `5432` | No |
| `OLLAMA_URL` | Ollama API URL | `http://localhost:11434` | No |

### Example Configuration File

Create a configuration file for easy loading:

```bash
# ~/.bashrc__htm
export TIGER_DBURL="postgres://user:pass@host:port/db?sslmode=require"
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
# 1. Verify TIGER_DBURL is set
echo $TIGER_DBURL

# 2. Test connection manually
psql $TIGER_DBURL

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
# For TimescaleDB Cloud users:
# Extensions should be pre-installed. Contact support if missing.

# For local installations:
# Install pgvector
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install

# Enable in database
psql $TIGER_DBURL -c "CREATE EXTENSION IF NOT EXISTS pgvector;"
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
psql $TIGER_DBURL -c "
  GRANT ALL PRIVILEGES ON DATABASE your_db TO your_user;
  GRANT ALL ON ALL TABLES IN SCHEMA public TO your_user;
"
```

## Next Steps

Now that HTM is installed, you're ready to start building:

1. **[Quick Start Guide](quick-start.md)**: Build your first HTM application in 5 minutes
2. **[User Guide](guides/getting-started.md)**: Learn all HTM features in depth
3. **[API Reference](api/htm.md)**: Explore the complete API documentation
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
- **TimescaleDB Documentation**: [https://docs.timescale.com/](https://docs.timescale.com/)
- **pgvector Documentation**: [https://github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)
- **PostgreSQL Documentation**: [https://www.postgresql.org/docs/](https://www.postgresql.org/docs/)
- **RubyLLM Documentation**: [https://github.com/madbomber/ruby_llm](https://github.com/madbomber/ruby_llm)
