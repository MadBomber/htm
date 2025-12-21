# Class: HTM::Config
**Inherits:** Anyway::Config
    

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


**`@example`**
```ruby
export HTM_EMBEDDING__PROVIDER=openai
export HTM_EMBEDDING__MODEL=text-embedding-3-small
export HTM_PROVIDERS__OPENAI__API_KEY=sk-xxx
```
**`@example`**
```ruby
embedding:
  provider: ollama
  model: nomic-embed-text:latest
providers:
  ollama:
    url: http://localhost:11434
```
**`@example`**
```ruby
HTM.configure do |config|
  config.embedding.provider = :openai
  config.embedding.model = 'text-embedding-3-small'
end
```
# Class Methods
## active_xdg_config_file() {: #method-c-active_xdg_config_file }
## config_section_with_defaults(section_key ) {: #method-c-config_section_with_defaults }
Create a coercion that merges incoming value with SCHEMA defaults for a
section. This ensures env vars like HTM_DATABASE__URL don't lose other
defaults.
## deep_merge_hashes(base , overlay ) {: #method-c-deep_merge_hashes }
Deep merge helper for coercion
## env() {: #method-c-env }
## xdg_config_file() {: #method-c-xdg_config_file }
## xdg_config_paths() {: #method-c-xdg_config_paths }
XDG Config Path Helpers

# Attributes
## embedding_generator[RW] {: #attribute-i-embedding_generator }
Callable Accessors (not loaded from config sources)


## logger[RW] {: #attribute-i-logger }
Returns the value of attribute logger.

## proposition_extractor[RW] {: #attribute-i-proposition_extractor }
Callable Accessors (not loaded from config sources)


## tag_extractor[RW] {: #attribute-i-tag_extractor }
Callable Accessors (not loaded from config sources)


## token_counter[RW] {: #attribute-i-token_counter }
Returns the value of attribute token_counter.


# Instance Methods
## anthropic_api_key() {: #method-i-anthropic_api_key }
## azure_api_key() {: #method-i-azure_api_key }
## azure_api_version() {: #method-i-azure_api_version }
## azure_endpoint() {: #method-i-azure_endpoint }
## bedrock_access_key() {: #method-i-bedrock_access_key }
## bedrock_region() {: #method-i-bedrock_region }
## bedrock_secret_key() {: #method-i-bedrock_secret_key }
## chunk_overlap() {: #method-i-chunk_overlap }
## chunk_size() {: #method-i-chunk_size }
Chunking convenience accessors

## circuit_breaker_failure_threshold() {: #method-i-circuit_breaker_failure_threshold }
Circuit breaker convenience accessors

## circuit_breaker_half_open_max_calls() {: #method-i-circuit_breaker_half_open_max_calls }
## circuit_breaker_reset_timeout() {: #method-i-circuit_breaker_reset_timeout }
## configure_ruby_llm(providernil) {: #method-i-configure_ruby_llm }
## database_config() {: #method-i-database_config }
## database_configured?() {: #method-i-database_configured? }
**`@return`** [Boolean] 

## database_url() {: #method-i-database_url }
Database convenience methods

## deepseek_api_key() {: #method-i-deepseek_api_key }
## development?() {: #method-i-development? }
**`@return`** [Boolean] 

## embedding_dimensions() {: #method-i-embedding_dimensions }
## embedding_model() {: #method-i-embedding_model }
## embedding_provider() {: #method-i-embedding_provider }
Embedding convenience accessors

## embedding_timeout() {: #method-i-embedding_timeout }
## environment() {: #method-i-environment }
## extract_propositions() {: #method-i-extract_propositions }
## gemini_api_key() {: #method-i-gemini_api_key }
## huggingface_api_key() {: #method-i-huggingface_api_key }
## initialize() {: #method-i-initialize }
Instance Methods


**`@return`** [Config] a new instance of Config

## job_backend() {: #method-i-job_backend }
Job backend convenience accessor

## max_embedding_dimension() {: #method-i-max_embedding_dimension }
## max_tag_depth() {: #method-i-max_tag_depth }
## normalize_ollama_model(model_name) {: #method-i-normalize_ollama_model }
Ollama Helpers


## ollama_url() {: #method-i-ollama_url }
## openai_api_key() {: #method-i-openai_api_key }
Provider credential convenience accessors

## openai_organization() {: #method-i-openai_organization }
## openai_project() {: #method-i-openai_project }
## openrouter_api_key() {: #method-i-openrouter_api_key }
## production?() {: #method-i-production? }
**`@return`** [Boolean] 

## proposition_model() {: #method-i-proposition_model }
## proposition_provider() {: #method-i-proposition_provider }
Proposition convenience accessors

## proposition_timeout() {: #method-i-proposition_timeout }
## refresh_ollama_models!() {: #method-i-refresh_ollama_models! }
## relevance_access_weight() {: #method-i-relevance_access_weight }
## relevance_recency_half_life_hours() {: #method-i-relevance_recency_half_life_hours }
## relevance_recency_weight() {: #method-i-relevance_recency_weight }
## relevance_semantic_weight() {: #method-i-relevance_semantic_weight }
Relevance scoring convenience accessors

## relevance_tag_weight() {: #method-i-relevance_tag_weight }
## reset_to_defaults() {: #method-i-reset_to_defaults }
## service_name() {: #method-i-service_name }
Service name convenience accessor

## tag_model() {: #method-i-tag_model }
## tag_provider() {: #method-i-tag_provider }
Tag convenience accessors

## tag_timeout() {: #method-i-tag_timeout }
## test?() {: #method-i-test? }
Environment Helpers


**`@return`** [Boolean] 

## validate!() {: #method-i-validate! }
## validate_settings!() {: #method-i-validate_settings! }