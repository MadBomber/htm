# Configuration Files Example

This example demonstrates HTM's flexible, layered configuration management using the `anyway_config` gem.

**Source:** [`examples/config_file_example/`](https://github.com/madbomber/htm/tree/main/examples/config_file_example)

## Overview

The configuration example shows:

- Configuration source hierarchy and priority
- Using `htm_mcp config` to generate config files
- Environment-specific configuration sections
- Environment variable overrides with `HTM_*`
- Custom config file paths with `HTM_CONF`
- Programmatic configuration with `HTM.configure`

## Configuration Priority

HTM loads configuration from multiple sources, merged in priority order:

| Priority | Source | Location |
|----------|--------|----------|
| 1 (lowest) | Bundled Defaults | `lib/htm/config/defaults.yml` |
| 2 | XDG User Config | `~/.config/htm/htm.yml` |
| 3 | Project Config | `./config/htm.yml` |
| 4 | Local Overrides | `./config/htm.local.yml` |
| 5 | HTM_CONF File | Path in `HTM_CONF` env var |
| 6 | Environment Variables | `HTM_*` |
| 7 (highest) | Code Block | `HTM.configure { }` |

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

## Generating Config Files

Use the `htm_mcp config` command to output the complete default configuration:

```bash
# Create a project config file
htm_mcp config > ./config/htm.yml

# Create a local overrides file (add to .gitignore)
htm_mcp config > ./config/htm.local.yml

# Create a user-wide XDG config
mkdir -p ~/.config/htm
htm_mcp config > ~/.config/htm/htm.yml
```

## Example Config Files

### Project Config with Environment Sections

```yaml
# ./config/htm.yml
defaults:
  database:
    host: localhost
    port: 5432

development:
  database:
    name: myapp_development
  log_level: debug

production:
  database:
    name: myapp_production
    pool_size: 25
  telemetry_enabled: true
```

### Local Overrides (Gitignored)

```yaml
# ./config/htm.local.yml
database:
  name: my_local_db

providers:
  openai:
    api_key: sk-your-actual-key

log_level: debug
```

## Environment Variables

Use double underscores (`__`) for nested values:

```bash
# Database configuration
export HTM_DATABASE__URL="postgresql://user:pass@host:5432/dbname"
export HTM_DATABASE__POOL_SIZE=25

# Embedding configuration
export HTM_EMBEDDING__PROVIDER=openai
export HTM_EMBEDDING__MODEL=text-embedding-3-small

# Provider credentials
export HTM_PROVIDERS__OPENAI__API_KEY=sk-your-key
```

## Example Output

The `show_config.rb` script displays loaded configuration with source tracing:

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
...
```

## Files in This Example

```
config_file_example/
├── README.md              # Detailed documentation
├── show_config.rb         # Demo script with source tracing
├── custom_config.yml      # Example for HTM_CONF usage
└── config/
    └── htm.local.yml      # Auto-loaded local overrides
```

## See Also

- [Configuration Guide](../guides/configuration.md)
- [anyway_config Documentation](https://github.com/palkan/anyway_config)
