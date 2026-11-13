# Class HTM::Config <a id="class-HTM-Config"></a>

|  |  |
| --- | --- |
| **Inherits** | MywayConfig::Base |
| **Includes** | [HTM::Config::Builder](Config/Builder.md), [HTM::Config::Database](Config/Database.md), [HTM::Config::Validator](Config/Validator.md) |
| **Defined in** | lib/htm/config.rb, lib/htm/config/builder.rb, lib/htm/config/database.rb, lib/htm/config/validator.rb |

HTM Configuration using Anyway Config

Schema is defined in lib/htm/config/defaults.yml (single source of truth)
Configuration uses nested sections for better organization:
    - HTM.config.database.host
    - HTM.config.embedding.provider
    - HTM.config.providers.openai.api_key

Configuration sources (lowest to highest priority):
1.  Bundled defaults: lib/htm/config/defaults.yml (ships with gem)
2.  XDG user config:
    *   ~/Library/Application Support/htm/htm.yml (macOS only)
    *   ~/.config/htm/htm.yml (XDG default)
    *   $XDG_CONFIG_HOME/htm/htm.yml (if XDG_CONFIG_HOME is set)
3.  Project config: ./config/htm.yml (environment-specific)
4.  Local overrides: ./config/htm.local.yml (gitignored)
5.  Environment variables (HTM_*)
6.  Explicit values passed to configure block

**@example Configure with environment variables**
```ruby
export HTM_EMBEDDING__PROVIDER=openai
export HTM_EMBEDDING__MODEL=text-embedding-3-small
export HTM_PROVIDERS__OPENAI__API_KEY=sk-xxx
```

**@example Configure with XDG user config (~/.config/htm/htm.yml)**
```ruby
embedding:
  provider: ollama
  model: nomic-embed-text:latest
providers:
  ollama:
    url: http://localhost:11434
```

**@example Configure with Ruby block**
```ruby
HTM.configure do |config|
  config.embedding.provider = :openai
  config.embedding.model = 'text-embedding-3-small'
end
```

## Constants
### `BOOLEAN_STRINGS` <a id="constant-BOOLEAN_STRINGS"></a> <a id="BOOLEAN_STRINGS-constant"></a>
String spellings accepted for nested boolean env vars

### `DEFAULT_DIMENSIONS` <a id="constant-DEFAULT_DIMENSIONS"></a> <a id="DEFAULT_DIMENSIONS-constant"></a>
Default embedding dimensions by provider

## Attributes
### `embedding_generator` [RW] <a id="attribute-i-embedding_generator"></a> <a id="embedding_generator-instance_method"></a>

Callable Accessors (not loaded from config sources)

### `logger` [RW] <a id="attribute-i-logger"></a> <a id="logger-instance_method"></a>

Callable Accessors (not loaded from config sources)

### `proposition_extractor` [RW] <a id="attribute-i-proposition_extractor"></a> <a id="proposition_extractor-instance_method"></a>

Callable Accessors (not loaded from config sources)

### `tag_extractor` [RW] <a id="attribute-i-tag_extractor"></a> <a id="tag_extractor-instance_method"></a>

Callable Accessors (not loaded from config sources)

### `token_counter` [RW] <a id="attribute-i-token_counter"></a> <a id="token_counter-instance_method"></a>

Callable Accessors (not loaded from config sources)

## Public Class Methods
### `active_xdg_config_file()` <a id="method-c-active_xdg_config_file"></a> <a id="active_xdg_config_file-class_method"></a>
Not documented.

### `env()` <a id="method-c-env"></a> <a id="env-class_method"></a>
Not documented.

### `valid_environment?()` <a id="method-c-valid_environment-3F"></a> <a id="valid_environment?-class_method"></a>
Check if current environment is valid (defined in config)
- **`@return`** [Boolean] true if environment has a config section

### `validate_environment!()` <a id="method-c-validate_environment-21"></a> <a id="validate_environment!-class_method"></a>
Validate that the current environment is configured
- **`@raise`** [HTM::ConfigurationError] if environment is invalid
- **`@return`** [true] if environment is valid

### `xdg_config_file()` <a id="method-c-xdg_config_file"></a> <a id="xdg_config_file-class_method"></a>
Not documented.

### `xdg_config_paths()` <a id="method-c-xdg_config_paths"></a> <a id="xdg_config_paths-class_method"></a>

XDG Config Path Helpers

## Public Instance Methods
### `actual_database_name()` <a id="method-i-actual_database_name"></a> <a id="actual_database_name-instance_method"></a>
Extract the actual database name from URL or config
- **`@return`** [String, nil] the database name

### `anthropic_api_key()` <a id="method-i-anthropic_api_key"></a> <a id="anthropic_api_key-instance_method"></a>
Not documented.

### `azure_api_key()` <a id="method-i-azure_api_key"></a> <a id="azure_api_key-instance_method"></a>
Not documented.

### `azure_api_version()` <a id="method-i-azure_api_version"></a> <a id="azure_api_version-instance_method"></a>
Not documented.

### `azure_endpoint()` <a id="method-i-azure_endpoint"></a> <a id="azure_endpoint-instance_method"></a>
Not documented.

### `bedrock_access_key()` <a id="method-i-bedrock_access_key"></a> <a id="bedrock_access_key-instance_method"></a>
Not documented.

### `bedrock_region()` <a id="method-i-bedrock_region"></a> <a id="bedrock_region-instance_method"></a>
Not documented.

### `bedrock_secret_key()` <a id="method-i-bedrock_secret_key"></a> <a id="bedrock_secret_key-instance_method"></a>
Not documented.

### `build_default_embedding_generator()` <a id="method-i-build_default_embedding_generator"></a> <a id="build_default_embedding_generator-instance_method"></a>
Not documented.

### `build_default_logger()` <a id="method-i-build_default_logger"></a> <a id="build_default_logger-instance_method"></a>
Not documented.

### `build_default_proposition_extractor()` <a id="method-i-build_default_proposition_extractor"></a> <a id="build_default_proposition_extractor-instance_method"></a>
Not documented.

### `build_default_tag_extractor()` <a id="method-i-build_default_tag_extractor"></a> <a id="build_default_tag_extractor-instance_method"></a>
Not documented.

### `build_default_token_counter()` <a id="method-i-build_default_token_counter"></a> <a id="build_default_token_counter-instance_method"></a>
Not documented.

### `build_proposition_extraction_prompt(text)` <a id="method-i-build_proposition_extraction_prompt"></a> <a id="build_proposition_extraction_prompt-instance_method"></a>
Not documented.

### `build_proposition_system_prompt()` <a id="method-i-build_proposition_system_prompt"></a> <a id="build_proposition_system_prompt-instance_method"></a>
Not documented.

### `build_tag_extraction_prompt(text, existing_ontology)` <a id="method-i-build_tag_extraction_prompt"></a> <a id="build_tag_extraction_prompt-instance_method"></a>

Prompt Builders

### `build_tag_system_prompt()` <a id="method-i-build_tag_system_prompt"></a> <a id="build_tag_system_prompt-instance_method"></a>
Not documented.

### `chunk_overlap()` <a id="method-i-chunk_overlap"></a> <a id="chunk_overlap-instance_method"></a>
Not documented.

### `chunk_size()` <a id="method-i-chunk_size"></a> <a id="chunk_size-instance_method"></a>
Chunking convenience accessors

### `circuit_breaker_failure_threshold()` <a id="method-i-circuit_breaker_failure_threshold"></a> <a id="circuit_breaker_failure_threshold-instance_method"></a>
Circuit breaker convenience accessors

### `circuit_breaker_half_open_max_calls()` <a id="method-i-circuit_breaker_half_open_max_calls"></a> <a id="circuit_breaker_half_open_max_calls-instance_method"></a>
Not documented.

### `circuit_breaker_reset_timeout()` <a id="method-i-circuit_breaker_reset_timeout"></a> <a id="circuit_breaker_reset_timeout-instance_method"></a>
Not documented.

### `configure_ruby_llm(provider = nil)` <a id="method-i-configure_ruby_llm"></a> <a id="configure_ruby_llm-instance_method"></a>
Not documented.

### `database_config()` <a id="method-i-database_config"></a> <a id="database_config-instance_method"></a>
Not documented.

### `database_configured?()` <a id="method-i-database_configured-3F"></a> <a id="database_configured?-instance_method"></a>
- **`@return`** [Boolean]

### `database_host()` <a id="method-i-database_host"></a> <a id="database_host-instance_method"></a>
- **`@return`** [String, nil] the database host

### `database_name()` <a id="method-i-database_name"></a> <a id="database_name-instance_method"></a>
- **`@return`** [String, nil] the database name

### `database_password()` <a id="method-i-database_password"></a> <a id="database_password-instance_method"></a>
- **`@return`** [String, nil] the database password

### `database_port()` <a id="method-i-database_port"></a> <a id="database_port-instance_method"></a>
- **`@return`** [Integer, nil] the database port

### `database_url()` <a id="method-i-database_url"></a> <a id="database_url-instance_method"></a>
Database convenience methods

### `database_user()` <a id="method-i-database_user"></a> <a id="database_user-instance_method"></a>
- **`@return`** [String, nil] the database user

### `deepseek_api_key()` <a id="method-i-deepseek_api_key"></a> <a id="deepseek_api_key-instance_method"></a>
Not documented.

### `embedding_dimensions()` <a id="method-i-embedding_dimensions"></a> <a id="embedding_dimensions-instance_method"></a>
Not documented.

### `embedding_model()` <a id="method-i-embedding_model"></a> <a id="embedding_model-instance_method"></a>
Not documented.

### `embedding_provider()` <a id="method-i-embedding_provider"></a> <a id="embedding_provider-instance_method"></a>
Embedding convenience accessors

### `embedding_timeout()` <a id="method-i-embedding_timeout"></a> <a id="embedding_timeout-instance_method"></a>
Not documented.

### `environment()` <a id="method-i-environment"></a> <a id="environment-instance_method"></a>
NOTE: test?, development?, production? are auto-generated by MywayConfig::Base
based on environment keys in defaults.yml

### `expected_database_name()` <a id="method-i-expected_database_name"></a> <a id="expected_database_name-instance_method"></a>
Returns the expected database name based on service.name and environment
- **`@return`** [String] expected database name in format "{service_name}_{environment}"

**`@example`**
```ruby
config.service.name = "htm"
HTM_ENV = "test"
config.expected_database_name  # => "htm_test"
```

### `extract_embedding_from_response(response)` <a id="method-i-extract_embedding_from_response"></a> <a id="extract_embedding_from_response-instance_method"></a>

Response Extraction Helpers

### `extract_propositions()` <a id="method-i-extract_propositions"></a> <a id="extract_propositions-instance_method"></a>
Not documented.

### `extract_text_from_response(response)` <a id="method-i-extract_text_from_response"></a> <a id="extract_text_from_response-instance_method"></a>
Not documented.

### `gemini_api_key()` <a id="method-i-gemini_api_key"></a> <a id="gemini_api_key-instance_method"></a>
Not documented.

### `huggingface_api_key()` <a id="method-i-huggingface_api_key"></a> <a id="huggingface_api_key-instance_method"></a>
Not documented.

### `initialize()` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>

Instance Methods
- **`@return`** [Config] a new instance of Config

### `job_backend()` <a id="method-i-job_backend"></a> <a id="job_backend-instance_method"></a>
Job backend convenience accessor

### `max_embedding_dimension()` <a id="method-i-max_embedding_dimension"></a> <a id="max_embedding_dimension-instance_method"></a>
Not documented.

### `max_tag_depth()` <a id="method-i-max_tag_depth"></a> <a id="max_tag_depth-instance_method"></a>
Not documented.

### `normalize_ollama_model(model_name)` <a id="method-i-normalize_ollama_model"></a> <a id="normalize_ollama_model-instance_method"></a>

Ollama Helpers

### `ollama_url()` <a id="method-i-ollama_url"></a> <a id="ollama_url-instance_method"></a>
Not documented.

### `openai_api_key()` <a id="method-i-openai_api_key"></a> <a id="openai_api_key-instance_method"></a>
Provider credential convenience accessors

### `openai_organization()` <a id="method-i-openai_organization"></a> <a id="openai_organization-instance_method"></a>
Not documented.

### `openai_project()` <a id="method-i-openai_project"></a> <a id="openai_project-instance_method"></a>
Not documented.

### `openrouter_api_key()` <a id="method-i-openrouter_api_key"></a> <a id="openrouter_api_key-instance_method"></a>
Not documented.

### `parse_database_url()` <a id="method-i-parse_database_url"></a> <a id="parse_database_url-instance_method"></a>
Parse database URL into component hash
- **`@return`** [Hash, nil] parsed components or nil if no URL

### `parse_proposition_response(text)` <a id="method-i-parse_proposition_response"></a> <a id="parse_proposition_response-instance_method"></a>
Not documented.

### `parse_tag_response(text)` <a id="method-i-parse_tag_response"></a> <a id="parse_tag_response-instance_method"></a>
Not documented.

### `proposition_model()` <a id="method-i-proposition_model"></a> <a id="proposition_model-instance_method"></a>
Not documented.

### `proposition_provider()` <a id="method-i-proposition_provider"></a> <a id="proposition_provider-instance_method"></a>
Proposition convenience accessors

### `proposition_timeout()` <a id="method-i-proposition_timeout"></a> <a id="proposition_timeout-instance_method"></a>
Not documented.

### `refresh_ollama_models!()` <a id="method-i-refresh_ollama_models-21"></a> <a id="refresh_ollama_models!-instance_method"></a>
Not documented.

### `relevance_access_weight()` <a id="method-i-relevance_access_weight"></a> <a id="relevance_access_weight-instance_method"></a>
Not documented.

### `relevance_recency_half_life_hours()` <a id="method-i-relevance_recency_half_life_hours"></a> <a id="relevance_recency_half_life_hours-instance_method"></a>
Not documented.

### `relevance_recency_weight()` <a id="method-i-relevance_recency_weight"></a> <a id="relevance_recency_weight-instance_method"></a>
Not documented.

### `relevance_semantic_weight()` <a id="method-i-relevance_semantic_weight"></a> <a id="relevance_semantic_weight-instance_method"></a>
Relevance scoring convenience accessors

### `relevance_tag_weight()` <a id="method-i-relevance_tag_weight"></a> <a id="relevance_tag_weight-instance_method"></a>
Not documented.

### `reset_to_defaults()` <a id="method-i-reset_to_defaults"></a> <a id="reset_to_defaults-instance_method"></a>
Not documented.

### `service_name()` <a id="method-i-service_name"></a> <a id="service_name-instance_method"></a>
Service name convenience accessor

### `tag_model()` <a id="method-i-tag_model"></a> <a id="tag_model-instance_method"></a>
Not documented.

### `tag_provider()` <a id="method-i-tag_provider"></a> <a id="tag_provider-instance_method"></a>
Tag convenience accessors

### `tag_timeout()` <a id="method-i-tag_timeout"></a> <a id="tag_timeout-instance_method"></a>
Not documented.

### `valid_database_name?()` <a id="method-i-valid_database_name-3F"></a> <a id="valid_database_name?-instance_method"></a>
Check if the database name matches the expected convention
- **`@return`** [Boolean] true if database name matches expected

### `valid_environment?()` <a id="method-i-valid_environment-3F"></a> <a id="valid_environment?-instance_method"></a>
Instance method delegates
- **`@return`** [Boolean]

### `validate!()` <a id="method-i-validate-21"></a> <a id="validate!-instance_method"></a>
Not documented.

### `validate_callables()` <a id="method-i-validate_callables"></a> <a id="validate_callables-instance_method"></a>
- **`@raise`** [HTM::ValidationError]

### `validate_config()` <a id="method-i-validate_config"></a> <a id="validate_config-instance_method"></a>
Not documented.

### `validate_database!()` <a id="method-i-validate_database-21"></a> <a id="validate_database!-instance_method"></a>
Validate that database is configured for the current environment
- **`@raise`** [HTM::ConfigurationError] if database is not configured
- **`@return`** [true] if database is configured

### `validate_database_name!()` <a id="method-i-validate_database_name-21"></a> <a id="validate_database_name!-instance_method"></a>
Validate that the database name follows the naming convention

Database names must be: {service_name}_{environment}
- **`@raise`** [HTM::ConfigurationError] if database name doesn't match expected
- **`@return`** [true] if database name is valid

**@example Valid configurations**
```ruby
HTM_ENV=test, service.name=htm, database=htm_test        # OK
HTM_ENV=production, service.name=payroll, database=payroll_production  # OK
```

**@example Invalid configurations (will raise)**
```ruby
HTM_ENV=test, service.name=htm, database=htm_production  # Wrong environment
HTM_ENV=test, service.name=htm, database=payroll_test    # Wrong service
HTM_ENV=test, service.name=htm, database=mydb            # Wrong format
```

### `validate_environment!()` <a id="method-i-validate_environment-21"></a> <a id="validate_environment!-instance_method"></a>
Not documented.

### `validate_job_backend()` <a id="method-i-validate_job_backend"></a> <a id="validate_job_backend-instance_method"></a>
Not documented.

### `validate_logger()` <a id="method-i-validate_logger"></a> <a id="validate_logger-instance_method"></a>
- **`@raise`** [HTM::ValidationError]

### `validate_provider(name, value)` <a id="method-i-validate_provider"></a> <a id="validate_provider-instance_method"></a>
Not documented.

### `validate_providers()` <a id="method-i-validate_providers"></a> <a id="validate_providers-instance_method"></a>
Not documented.

### `validate_relevance_weights()` <a id="method-i-validate_relevance_weights"></a> <a id="validate_relevance_weights-instance_method"></a>
Not documented.

### `validate_settings!()` <a id="method-i-validate_settings-21"></a> <a id="validate_settings!-instance_method"></a>
Not documented.

### `validate_week_start()` <a id="method-i-validate_week_start"></a> <a id="validate_week_start-instance_method"></a>
Not documented.
