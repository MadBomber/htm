# Configuration

HTM uses the [anyway_config](https://github.com/palkan/anyway_config) gem for flexible, layered configuration. The source of truth for the configuration schema and defaults is [`lib/htm/config/defaults.yml`](https://github.com/madbomber/htm/blob/main/lib/htm/config/defaults.yml).

## Configuration Hierarchy

HTM loads configuration from multiple sources, with later sources overriding earlier ones:

1. **Bundled defaults** (`lib/htm/config/defaults.yml`) - Gem defaults
2. **XDG user config** (`~/.config/htm/htm.yml`) - User-wide settings
3. **Project config** (`./config/htm.yml`) - Project-specific settings
4. **Local overrides** (`./config/htm.local.yml`) - Gitignored local settings
5. **Environment variables** (`HTM_*`) - Runtime overrides
6. **Programmatic** (`HTM.configure` block) - Code-level configuration

## Important Environment Variables

### Configuration Control

| Variable | Description |
|----------|-------------|
| `HTM_ENV` | Environment name (`development`, `test`, `production`). Falls back to `RAILS_ENV`, then `RACK_ENV`, then `development`. |
| `HTM_CONF` | Path to a custom YAML config file to load instead of default locations. |

```bash
# Use test environment settings
export HTM_ENV=test

# Load config from a specific file
export HTM_CONF=/path/to/my/htm.yml
```

## Getting Started with Config Files

### Dump Default Configuration

Use the `htm_mcp config` command to output the default configuration schema:

```bash
# Print defaults to stdout
htm_mcp config

# Save to a config file
htm_mcp config > config/htm.yml

# Save to XDG location
htm_mcp config > ~/.config/htm/htm.yml
```

### Minimal Config File

```yaml
# config/htm.yml
database:
  url: postgresql://user@localhost:5432/htm_development

embedding:
  provider: ollama
  model: nomic-embed-text:latest

tag:
  provider: ollama
  model: gemma3:latest
```

### Environment-Specific Overrides

The config file supports environment sections:

```yaml
# Shared defaults
defaults:
  embedding:
    provider: ollama
    model: nomic-embed-text:latest

# Development overrides
development:
  database:
    name: htm_development
  log_level: debug

# Test overrides
test:
  database:
    name: htm_test
  job:
    backend: inline

# Production overrides
production:
  database:
    pool_size: 25
    sslmode: require
  telemetry_enabled: true
```

## Configuration Sections

### Database Configuration

Access: `HTM.config.database.host`, `HTM.config.database.port`, etc.

```yaml
database:
  url: ~                    # Full connection URL (overrides individual settings)
  host: localhost
  port: 5432
  name: ~
  user: ~
  password: ~
  pool_size: 10
  timeout: 5000
  sslmode: prefer
```

**Environment variables:**
```bash
HTM_DATABASE__URL=postgresql://user:pass@localhost:5432/htm_dev
HTM_DATABASE__HOST=localhost
HTM_DATABASE__PORT=5432
HTM_DATABASE__NAME=htm_development
HTM_DATABASE__USER=postgres
HTM_DATABASE__PASSWORD=secret
HTM_DATABASE__POOL_SIZE=10
```

### Embedding Configuration

Access: `HTM.config.embedding.provider`, `HTM.config.embedding.model`, etc.

```yaml
embedding:
  provider: ollama          # LLM provider for embeddings
  model: nomic-embed-text:latest
  dimensions: 768           # Vector dimensions
  timeout: 120              # Request timeout (seconds)
  max_dimension: 2000       # Maximum supported dimensions
```

**Environment variables:**
```bash
HTM_EMBEDDING__PROVIDER=openai
HTM_EMBEDDING__MODEL=text-embedding-3-small
HTM_EMBEDDING__DIMENSIONS=1536
HTM_EMBEDDING__TIMEOUT=120
```

### Tag Extraction Configuration

Access: `HTM.config.tag.provider`, `HTM.config.tag.model`, etc.

```yaml
tag:
  provider: ollama
  model: gemma3:latest
  timeout: 180
  max_depth: 4              # Maximum tag hierarchy depth

  # Prompt templates (use %{placeholder} for interpolation)
  system_prompt: |
    You are a taxonomy classifier...

  user_prompt_template: |
    Extract classification tags for this text...
    TEXT: %{text}
    ...

  taxonomy_context_existing: "Existing taxonomy paths: %{sample_tags}..."
  taxonomy_context_empty: "This is a new taxonomy..."
```

**Environment variables:**
```bash
HTM_TAG__PROVIDER=openai
HTM_TAG__MODEL=gpt-4o-mini
HTM_TAG__TIMEOUT=180
HTM_TAG__MAX_DEPTH=4
```

### Proposition Extraction Configuration

Access: `HTM.config.proposition.provider`, `HTM.config.proposition.enabled`, etc.

```yaml
proposition:
  provider: ollama
  model: gemma3:latest
  timeout: 180
  enabled: false            # Enable atomic fact extraction

  system_prompt: |
    You are an atomic fact extraction system...

  user_prompt_template: |
    Extract all ATOMIC factual propositions...
    TEXT: %{text}
    ...
```

**Environment variables:**
```bash
HTM_PROPOSITION__ENABLED=true
HTM_PROPOSITION__PROVIDER=openai
HTM_PROPOSITION__MODEL=gpt-4o-mini
```

### Chunking Configuration

Access: `HTM.config.chunking.size`, `HTM.config.chunking.overlap`

```yaml
chunking:
  size: 1024                # Characters per chunk
  overlap: 64               # Overlap between chunks
```

**Environment variables:**
```bash
HTM_CHUNKING__SIZE=512
HTM_CHUNKING__OVERLAP=50
```

### Job Backend Configuration

Access: `HTM.config.job.backend`

```yaml
job:
  backend: ~                # nil = auto-detect, or: inline, thread, sidekiq, active_job
```

**Environment variables:**
```bash
HTM_JOB__BACKEND=sidekiq
```

| Backend | Behavior | Use Case |
|---------|----------|----------|
| `~` (nil) | Auto-detect | Default |
| `inline` | Synchronous | Testing |
| `thread` | Background threads | Development |
| `sidekiq` | Sidekiq workers | Production |
| `active_job` | Rails ActiveJob | Rails apps |

### Circuit Breaker Configuration

Access: `HTM.config.circuit_breaker.failure_threshold`, etc.

```yaml
circuit_breaker:
  failure_threshold: 5      # Failures before circuit opens
  reset_timeout: 60         # Seconds before half-open state
  half_open_max_calls: 3    # Successes needed to close
```

### Relevance Scoring Configuration

Access: `HTM.config.relevance.semantic_weight`, etc.

```yaml
relevance:
  semantic_weight: 0.5      # Vector similarity weight
  tag_weight: 0.3           # Tag overlap weight
  recency_weight: 0.1       # Temporal freshness weight
  access_weight: 0.1        # Access frequency weight
  recency_half_life_hours: 168.0  # Decay half-life (1 week)
```

### Provider Credentials

Access: `HTM.config.providers.openai.api_key`, etc.

```yaml
providers:
  openai:
    api_key: ~
    organization: ~
    project: ~

  anthropic:
    api_key: ~

  gemini:
    api_key: ~

  azure:
    api_key: ~
    endpoint: ~
    api_version: '2024-02-01'

  ollama:
    url: http://localhost:11434

  huggingface:
    api_key: ~

  openrouter:
    api_key: ~

  bedrock:
    access_key: ~
    secret_key: ~
    region: us-east-1

  deepseek:
    api_key: ~
```

### General Settings

```yaml
week_start: sunday          # For "last weekend" calculations
connection_timeout: 60      # General connection timeout
telemetry_enabled: false    # Enable OpenTelemetry metrics
log_level: info             # Logging level

service:
  name: htm                 # Service identifier
```

## Complete Environment Variables Reference

### Configuration Control

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_ENV` | Environment name | `development` |
| `HTM_CONF` | Custom config file path | - |

### Database

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_DATABASE__URL` | Full PostgreSQL connection URL | - |
| `HTM_DATABASE__HOST` | Database host | `localhost` |
| `HTM_DATABASE__PORT` | Database port | `5432` |
| `HTM_DATABASE__NAME` | Database name | - |
| `HTM_DATABASE__USER` | Database user | - |
| `HTM_DATABASE__PASSWORD` | Database password | - |
| `HTM_DATABASE__POOL_SIZE` | Connection pool size | `10` |
| `HTM_DATABASE__TIMEOUT` | Query timeout (ms) | `5000` |
| `HTM_DATABASE__SSLMODE` | SSL mode | `prefer` |

### Embedding

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_EMBEDDING__PROVIDER` | LLM provider | `ollama` |
| `HTM_EMBEDDING__MODEL` | Model name | `nomic-embed-text:latest` |
| `HTM_EMBEDDING__DIMENSIONS` | Vector dimensions | `768` |
| `HTM_EMBEDDING__TIMEOUT` | Timeout (seconds) | `120` |
| `HTM_EMBEDDING__MAX_DIMENSION` | Max dimensions | `2000` |

### Tag Extraction

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_TAG__PROVIDER` | LLM provider | `ollama` |
| `HTM_TAG__MODEL` | Model name | `gemma3:latest` |
| `HTM_TAG__TIMEOUT` | Timeout (seconds) | `180` |
| `HTM_TAG__MAX_DEPTH` | Max hierarchy depth | `4` |

### Proposition Extraction

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_PROPOSITION__ENABLED` | Enable extraction | `false` |
| `HTM_PROPOSITION__PROVIDER` | LLM provider | `ollama` |
| `HTM_PROPOSITION__MODEL` | Model name | `gemma3:latest` |
| `HTM_PROPOSITION__TIMEOUT` | Timeout (seconds) | `180` |

### Chunking

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_CHUNKING__SIZE` | Characters per chunk | `1024` |
| `HTM_CHUNKING__OVERLAP` | Overlap characters | `64` |

### Job Processing

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_JOB__BACKEND` | Job backend | - (auto) |

### Circuit Breaker

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_CIRCUIT_BREAKER__FAILURE_THRESHOLD` | Failures before open | `5` |
| `HTM_CIRCUIT_BREAKER__RESET_TIMEOUT` | Seconds to half-open | `60` |
| `HTM_CIRCUIT_BREAKER__HALF_OPEN_MAX_CALLS` | Successes to close | `3` |

### Relevance Scoring

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_RELEVANCE__SEMANTIC_WEIGHT` | Vector similarity weight | `0.5` |
| `HTM_RELEVANCE__TAG_WEIGHT` | Tag overlap weight | `0.3` |
| `HTM_RELEVANCE__RECENCY_WEIGHT` | Freshness weight | `0.1` |
| `HTM_RELEVANCE__ACCESS_WEIGHT` | Access frequency weight | `0.1` |
| `HTM_RELEVANCE__RECENCY_HALF_LIFE_HOURS` | Decay half-life | `168.0` |

### General

| Variable | Description | Default |
|----------|-------------|---------|
| `HTM_WEEK_START` | Week start day | `sunday` |
| `HTM_CONNECTION_TIMEOUT` | Connection timeout | `30` |
| `HTM_TELEMETRY_ENABLED` | Enable telemetry | `false` |
| `HTM_LOG_LEVEL` | Log level | `info` |
| `HTM_SERVICE__NAME` | Service name | `htm` |

### Provider API Keys

| Variable | Description |
|----------|-------------|
| `HTM_PROVIDERS__OPENAI__API_KEY` | OpenAI API key |
| `HTM_PROVIDERS__OPENAI__ORGANIZATION` | OpenAI organization |
| `HTM_PROVIDERS__ANTHROPIC__API_KEY` | Anthropic API key |
| `HTM_PROVIDERS__GEMINI__API_KEY` | Google Gemini API key |
| `HTM_PROVIDERS__AZURE__API_KEY` | Azure OpenAI API key |
| `HTM_PROVIDERS__AZURE__ENDPOINT` | Azure endpoint URL |
| `HTM_PROVIDERS__OLLAMA__URL` | Ollama server URL |
| `HTM_PROVIDERS__HUGGINGFACE__API_KEY` | HuggingFace API key |
| `HTM_PROVIDERS__OPENROUTER__API_KEY` | OpenRouter API key |
| `HTM_PROVIDERS__BEDROCK__ACCESS_KEY` | AWS access key |
| `HTM_PROVIDERS__BEDROCK__SECRET_KEY` | AWS secret key |
| `HTM_PROVIDERS__BEDROCK__REGION` | AWS region |
| `HTM_PROVIDERS__DEEPSEEK__API_KEY` | DeepSeek API key |

**Note:** Standard provider environment variables are also supported:

| Variable | Maps To |
|----------|---------|
| `OPENAI_API_KEY` | `HTM_PROVIDERS__OPENAI__API_KEY` |
| `ANTHROPIC_API_KEY` | `HTM_PROVIDERS__ANTHROPIC__API_KEY` |
| `GEMINI_API_KEY` | `HTM_PROVIDERS__GEMINI__API_KEY` |
| `OLLAMA_URL` | `HTM_PROVIDERS__OLLAMA__URL` |
| `AWS_ACCESS_KEY_ID` | `HTM_PROVIDERS__BEDROCK__ACCESS_KEY` |
| `AWS_SECRET_ACCESS_KEY` | `HTM_PROVIDERS__BEDROCK__SECRET_KEY` |
| `AWS_REGION` | `HTM_PROVIDERS__BEDROCK__REGION` |

## Programmatic Configuration

Override any setting in code:

```ruby
HTM.configure do |config|
  config.embedding.provider = :openai
  config.embedding.model = 'text-embedding-3-small'
  config.tag.provider = :openai
  config.tag.model = 'gpt-4o-mini'
  config.providers.openai.api_key = ENV['OPENAI_API_KEY']
end
```

### Custom LLM Functions

Provide your own embedding and tag extraction:

```ruby
HTM.configure do |config|
  config.embedding_generator = lambda do |text|
    MyService.embed(text)  # Must return Array<Float>
  end

  config.tag_extractor = lambda do |text, existing_ontology|
    MyService.extract_tags(text)  # Must return Array<String>
  end
end
```

## Accessing Configuration

```ruby
# Full config object
config = HTM.config

# Nested access
config.database.url
config.embedding.provider
config.providers.openai.api_key

# Check if database is configured
config.database_configured?

# Get current environment
HTM.env  # => "development"
```

## Config File Locations

HTM searches for config files in this order:

1. **Custom path** - `HTM_CONF` environment variable
2. **XDG config** - `~/.config/htm/htm.yml`
3. **Project config** - `./config/htm.yml`
4. **Local override** - `./config/htm.local.yml` (gitignored)

Create a local override for sensitive credentials:

```yaml
# config/htm.local.yml (add to .gitignore)
providers:
  openai:
    api_key: sk-your-actual-key
```

## See Also

- [defaults.yml Source](https://github.com/madbomber/htm/blob/main/lib/htm/config/defaults.yml) - Configuration schema and defaults
- [LLM Configuration Example](../examples/llm-configuration.md)
- [Configuration API Reference](../api/yard/HTM/Config.md)
- [anyway_config Documentation](https://github.com/palkan/anyway_config)
