# HTM Setup Guide

## Prerequisites

1. **Ruby** (version 3.0 or higher)
2. **PostgreSQL** (14+ with pgvector and pg_trgm extensions)
3. **Ollama** (for embeddings via RubyLLM)

## PostgreSQL Setup

### 1. Install PostgreSQL

**macOS (via Homebrew):**
```bash
brew install postgresql@17
brew services start postgresql@17
```

**Ubuntu/Debian:**
```bash
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
```

### 2. Install pgvector Extension

**macOS:**
```bash
brew install pgvector
```

**Ubuntu/Debian:**
```bash
sudo apt install postgresql-17-pgvector
```

**From source:**
```bash
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

### 3. Create Database and Enable Extensions

```bash
# Create the development database
createdb htm_development

# Enable required extensions
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql htm_development -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# Verify extensions
psql htm_development -c "SELECT extname, extversion FROM pg_extension;"
```

### 4. Set Environment Variable

```bash
# Add to your ~/.bashrc or ~/.zshrc
export HTM_DATABASE__URL="postgresql://postgres@localhost:5432/htm_development"

# Or for a specific user with password
export HTM_DATABASE__URL="postgresql://username:password@localhost:5432/htm_development"
```

### 5. Verify Connection

```bash
cd /path/to/HTM
ruby test_connection.rb
```

You should see:
```
✓ Connected successfully!
✓ pgvector Extension: Version 0.8.x
✓ pg_trgm Extension: Version 1.6
```

## Ollama Setup

HTM uses RubyLLM with the Ollama provider for generating embeddings. You need to install and run Ollama locally.

### 1. Install Ollama

**macOS:**
```bash
curl https://ollama.ai/install.sh | sh
```

**Or download from:** https://ollama.ai/download

### 2. Start Ollama Service

```bash
# Ollama typically starts automatically after installation
# Verify it's running:
curl http://localhost:11434/api/version
```

### 3. Pull Required Models

```bash
# Pull the embedding model
ollama pull nomic-embed-text

# Pull the chat model (for tag extraction)
ollama pull llama3

# Verify models are available
ollama list
```

### 4. Test Embedding Generation

```bash
# Test that embeddings work
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text",
  "prompt": "Hello, world!"
}'
```

### Optional: Custom Ollama URL

If Ollama is running on a different host/port, set the environment variable:

```bash
export OLLAMA_URL="http://custom-host:11434"
```

## Environment Variables Reference

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `HTM_DATABASE__URL` | Full PostgreSQL connection URL (preferred) | `postgresql://postgres@localhost:5432/htm_development` |
| `HTM_DATABASE__NAME` | Database name (fallback) | `htm_development` |
| `HTM_DATABASE__USER` | Database user (fallback) | `postgres` |
| `HTM_DATABASE__PASSWORD` | Database password (fallback) | `` |
| `HTM_DATABASE__HOST` | Database host (fallback) | `localhost` |
| `HTM_DATABASE__PORT` | Database port (fallback) | `5432` |
| `OLLAMA_URL` | Ollama server URL | `http://localhost:11434` |

## Development Workflow

### Quick Start

```bash
# 1. Set database URL (if not in shell config)
export HTM_DATABASE__URL="postgresql://postgres@localhost:5432/htm_development"

# 2. Install dependencies
bundle install

# 3. Initialize database schema
rake db_setup

# 4. Run tests
rake test

# 5. Try the basic example
ruby examples/basic_usage.rb
```

### Testing

HTM uses Minitest for testing:

```bash
# Run all tests
rake test

# Run specific test file
ruby test/htm_test.rb
ruby test/embedding_service_test.rb

# Run integration tests (requires database)
ruby test/integration_test.rb
```

## Project Structure

```
HTM/
├── lib/
│   ├── htm.rb                    # Main HTM class
│   ├── htm/
│   │   ├── database.rb           # Database setup and schema
│   │   ├── long_term_memory.rb   # PostgreSQL-backed storage
│   │   ├── working_memory.rb     # In-memory active context
│   │   ├── embedding_service.rb  # RubyLLM embedding generation
│   │   ├── tag_service.rb        # Hierarchical tag extraction
│   │   ├── configuration.rb      # Multi-provider LLM config
│   │   └── version.rb            # Version constant
├── config/
│   └── defaults.yml              # Default configuration values
├── db/
│   └── schema.sql                # Database schema
├── test/
│   ├── test_helper.rb            # Minitest configuration
│   ├── htm_test.rb               # Basic HTM tests
│   ├── embedding_service_test.rb # Embedding tests
│   └── integration_test.rb       # Full integration tests
├── examples/
│   └── basic_usage.rb            # Basic usage example
├── test_connection.rb            # Verify database connection
├── enable_extensions.rb          # Enable PostgreSQL extensions
├── SETUP.md                      # This file
├── README.md                     # Project overview
├── CLAUDE.md                     # AI assistant instructions
├── Gemfile
├── htm.gemspec
└── Rakefile                      # Rake tasks
```

## Troubleshooting

### Ollama Issues

If you encounter embedding errors:

```bash
# Verify Ollama is running
curl http://localhost:11434/api/version

# Check if models are available
ollama list

# Test embedding generation
curl http://localhost:11434/api/embeddings -d '{"model": "nomic-embed-text", "prompt": "Test"}'

# View Ollama logs (macOS)
# Check Console.app or Activity Monitor
```

**Common Ollama Errors:**

- **"connection refused"**: Ollama service is not running. Start Ollama from Applications or via CLI.
- **"model not found"**: Run `ollama pull nomic-embed-text` to download the model.
- **Custom URL not working**: Ensure `OLLAMA_URL` environment variable is set correctly.

### Database Connection Issues

If you get connection errors:

```bash
# Verify environment variable is set
echo $HTM_DATABASE__URL

# Test connection manually
psql $HTM_DATABASE__URL -c "SELECT 1"

# Check PostgreSQL is running
brew services list | grep postgresql  # macOS
systemctl status postgresql           # Linux
```

### Extension Issues

If extensions aren't available:

```bash
# Check if pgvector is installed
psql htm_development -c "SELECT * FROM pg_available_extensions WHERE name = 'vector';"

# Re-run extension setup
ruby enable_extensions.rb

# Check extension status
psql htm_development -c "SELECT extname, extversion FROM pg_extension ORDER BY extname"
```

### Test Database

For running tests, create a separate test database:

```bash
createdb htm_development_test
psql htm_development_test -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pg_trgm;"
```

## Resources

- **Ollama**: https://ollama.ai/
- **RubyLLM**: https://github.com/crmne/ruby_llm
- **pgvector Docs**: https://github.com/pgvector/pgvector
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **Planning Document**: `htm_teamwork.md`

## Support

For issues or questions:
1. Check `htm_teamwork.md` for design decisions
2. Review examples in `examples/` directory
3. Run tests with `rake test` (Minitest framework)
4. Check Ollama status for embedding issues
