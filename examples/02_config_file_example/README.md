# HTM Configuration Example

This example demonstrates how HTM uses the `anyway_config` gem for flexible, layered configuration management.

## Configuration Sources (Priority Order)

HTM loads configuration from multiple sources, merged in order from lowest to highest priority:

| Priority | Source | Location | Description |
|----------|--------|----------|-------------|
| 1 | Bundled Defaults | `lib/htm/config/defaults.yml` | Ships with the gem, defines schema |
| 2 | XDG User Config | `~/.config/htm/htm.yml` | User-wide settings |
| 3 | Project Config | `./config/htm.yml` | Project-specific settings |
| 4 | Local Overrides | `./config/htm.local.yml` | Local dev settings (gitignored) |
| 5 | HTM_CONF File | Path in `HTM_CONF` env var | Custom config file path |
| 6 | Environment Variables | `HTM_*` | Runtime overrides |
| 7 | Code Block | `HTM.configure { }` | Programmatic configuration |

Higher priority sources override values from lower priority sources.

## Generating a Config File

> **Tip:** Use the `htm_mcp config` command to output the complete default configuration to STDOUT. Redirect it to any location with any filename:
>
> ```bash
> # Create a project config file
> htm_mcp config > ./config/htm.yml
>
> # Create a local overrides file
> htm_mcp config > ./config/htm.local.yml
>
> # Create a user-wide XDG config
> mkdir -p ~/.config/htm
> htm_mcp config > ~/.config/htm/htm.yml
>
> # Create a custom config for HTM_CONF
> htm_mcp config > /path/to/my_custom_config.yml
> ```
>
> This gives you a complete, documented template with all available settings that you can customize for your needs.

## Standard Config File Locations

### 1. Bundled Defaults (`lib/htm/config/defaults.yml`)

The gem ships with a defaults file that defines the complete configuration schema and sensible defaults. This is always loaded first.

### 2. XDG User Config (`~/.config/htm/htm.yml`)

User-wide configuration following the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html). On macOS, also checks `~/Library/Application Support/htm/htm.yml`.

```yaml
# ~/.config/htm/htm.yml
embedding:
  provider: openai
  model: text-embedding-3-small

providers:
  openai:
    api_key: sk-your-api-key
```

### 3. Project Config (`./config/htm.yml`)

Project-specific configuration. Supports environment-specific sections:

```yaml
# ./config/htm.yml
defaults:
  database:
    host: localhost
    port: 5432

development:
  database:
    name: myapp_development

production:
  database:
    name: myapp_production
    pool_size: 25
```

### 4. Local Overrides (`./config/htm.local.yml`)

Developer-specific overrides, typically added to `.gitignore`:

```yaml
# ./config/htm.local.yml
database:
  name: my_local_db

log_level: debug
```

## Using HTM_CONF for Custom Config Files

The `HTM_CONF` environment variable lets you specify any YAML file path:

```bash
# Relative path
HTM_CONF=./custom_config.yml ruby show_config.rb

# Absolute path
HTM_CONF=/etc/htm/production.yml ruby show_config.rb

# Different config per environment
HTM_CONF=./config/staging.yml HTM_ENV=staging ruby show_config.rb
```

This is useful for:
- Testing different configurations
- CI/CD pipelines with config files in non-standard locations
- Docker deployments with mounted config files

## Environment Variables

Environment variables use double underscores (`__`) for nested values:

```bash
# Database configuration
export HTM_DATABASE__URL="postgresql://user:pass@host:5432/dbname"
export HTM_DATABASE__POOL_SIZE=25

# Embedding configuration
export HTM_EMBEDDING__PROVIDER=openai
export HTM_EMBEDDING__MODEL=text-embedding-3-small
export HTM_EMBEDDING__DIMENSIONS=1536

# Provider credentials
export HTM_PROVIDERS__OPENAI__API_KEY=sk-your-key
export HTM_PROVIDERS__OLLAMA__URL=http://localhost:11434

# General settings
export HTM_LOG_LEVEL=debug
export HTM_TELEMETRY_ENABLED=true
```

## Code-Level Configuration

The highest priority configuration is done programmatically:

```ruby
require 'htm'

HTM.configure do |config|
  # Database
  config.database.host = 'localhost'
  config.database.name = 'my_database'

  # Embedding provider
  config.embedding.provider = :openai
  config.embedding.model = 'text-embedding-3-small'
  config.embedding.dimensions = 1536

  # Tag extraction
  config.tag.provider = :anthropic
  config.tag.model = 'claude-3-haiku-20240307'

  # Provider credentials
  config.providers.openai.api_key = ENV['OPENAI_API_KEY']

  # General settings
  config.log_level = :debug
  config.telemetry_enabled = false

  # Custom callables
  config.logger = Logger.new($stdout)
end
```

## Environment Selection

HTM detects the environment using these variables (in order):

1. `HTM_ENV`
2. `RAILS_ENV`
3. `RACK_ENV`
4. Defaults to `development`

```bash
HTM_ENV=production ruby show_config.rb
HTM_ENV=test ruby show_config.rb
```

## Running the Example

```bash
cd examples/config_file_example

# Basic usage - loads ./config/htm.local.yml automatically
ruby show_config.rb

# Different environment
HTM_ENV=production ruby show_config.rb

# Override with environment variable
HTM_EMBEDDING__MODEL=mxbai-embed-large ruby show_config.rb

# Use custom config file
HTM_CONF=./custom_config.yml ruby show_config.rb

# Combine multiple overrides
HTM_CONF=./custom_config.yml HTM_ENV=test HTM_LOG_LEVEL=warn ruby show_config.rb
```

## Example Output

The `show_config.rb` script displays the loaded configuration with source tracing:

```
HTM Configuration Example
============================================================

Environment: development

Config sources checked:
  - Bundled defaults: lib/htm/config/defaults.yml
  - XDG config: ~/.config/htm/htm.yml
  - Project config: ./config/htm.yml
  - Local overrides: ./config/htm.local.yml
  - HTM_CONF override: (not set)
  - Environment variables: HTM_*

------------------------------------------------------------
Configuration with Sources:
------------------------------------------------------------

database:
  host: "localhost"  # from: htm.local.yml
  port: 5432  # from: htm.local.yml
  name: "htm_example"  # from: htm.local.yml
  pool_size: 10  # from: bundled_defaults
embedding:
  provider: "ollama"  # from: htm.local.yml
  model: "nomic-embed-text:latest"  # from: htm.local.yml
  dimensions: 768  # from: bundled_defaults
...
```

## Files in This Example

```
config_file_example/
├── README.md              # This file
├── show_config.rb         # Demo script with source tracing
├── custom_config.yml      # Example for HTM_CONF usage
└── config/
    └── htm.local.yml      # Auto-loaded local overrides
```

## See Also

- [anyway_config documentation](https://github.com/palkan/anyway_config)
- [HTM Configuration Guide](../../docs/configuration.md)
- [HTM README](../../README.md)
