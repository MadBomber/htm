# frozen_string_literal: true

require 'anyway_config'
require 'logger'
require 'yaml'

# Define Config class first to establish superclass
class HTM
  class Config < Anyway::Config
  end
end

require_relative 'config/section'
require_relative 'config/validator'
require_relative 'config/database'
require_relative 'config/builder'

class HTM
  # HTM Configuration using Anyway Config
  #
  # Schema is defined in lib/htm/config/defaults.yml (single source of truth)
  # Configuration uses nested sections for better organization:
  #   - HTM.config.database.host
  #   - HTM.config.embedding.provider
  #   - HTM.config.providers.openai.api_key
  #
  # Configuration sources (lowest to highest priority):
  # 1. Bundled defaults: lib/htm/config/defaults.yml (ships with gem)
  # 2. XDG user config:
  #    - ~/Library/Application Support/htm/htm.yml (macOS only)
  #    - ~/.config/htm/htm.yml (XDG default)
  #    - $XDG_CONFIG_HOME/htm/htm.yml (if XDG_CONFIG_HOME is set)
  # 3. Project config: ./config/htm.yml (environment-specific)
  # 4. Local overrides: ./config/htm.local.yml (gitignored)
  # 5. Environment variables (HTM_*)
  # 6. Explicit values passed to configure block
  #
  # @example Configure with environment variables
  #   export HTM_EMBEDDING__PROVIDER=openai
  #   export HTM_EMBEDDING__MODEL=text-embedding-3-small
  #   export HTM_PROVIDERS__OPENAI__API_KEY=sk-xxx
  #
  # @example Configure with XDG user config (~/.config/htm/htm.yml)
  #   embedding:
  #     provider: ollama
  #     model: nomic-embed-text:latest
  #   providers:
  #     ollama:
  #       url: http://localhost:11434
  #
  # @example Configure with Ruby block
  #   HTM.configure do |config|
  #     config.embedding.provider = :openai
  #     config.embedding.model = 'text-embedding-3-small'
  #   end
  #
  class Config
    include Validator
    include Database
    include Builder

    config_name :htm
    env_prefix :htm

    # ==========================================================================
    # Schema Definition (loaded from defaults.yml - single source of truth)
    # ==========================================================================

    # Path to bundled defaults file (defines both schema and default values)
    DEFAULTS_PATH = File.expand_path('config/defaults.yml', __dir__).freeze

    # Load schema from defaults.yml at class definition time
    begin
      defaults_content = File.read(DEFAULTS_PATH)
      raw_yaml = YAML.safe_load(
        defaults_content,
        permitted_classes: [Symbol],
        symbolize_names: true,
        aliases: true
      ) || {}
      SCHEMA = raw_yaml[:defaults] || {}
    rescue StandardError => e
      warn "HTM: Could not load schema from #{DEFAULTS_PATH}: #{e.message}"
      SCHEMA = {}
    end

    # Nested section attributes (defined as hashes, converted to ConfigSection)
    attr_config :database, :service, :embedding, :tag, :proposition,
                :chunking, :circuit_breaker, :relevance, :job, :providers

    # Top-level scalar attributes
    attr_config :week_start, :connection_timeout, :telemetry_enabled, :log_level

    # Custom environment detection: HTM_ENV > RAILS_ENV > RACK_ENV > 'development'
    class << self
      def env
        Anyway::Settings.current_environment ||
          ENV['HTM_ENV'] ||
          ENV['RAILS_ENV'] ||
          ENV['RACK_ENV'] ||
          'development'
      end
    end

    # ==========================================================================
    # Type Coercion
    # ==========================================================================

    TO_SYMBOL = ->(v) { v.nil? ? nil : v.to_s.to_sym }

    # Create a coercion that merges incoming value with SCHEMA defaults for a section.
    # This ensures env vars like HTM_DATABASE__URL don't lose other defaults.
    def self.config_section_with_defaults(section_key)
      defaults = SCHEMA[section_key] || {}
      ->(v) {
        return v if v.is_a?(ConfigSection)
        incoming = v || {}
        # Deep merge: defaults first, then overlay incoming values
        merged = deep_merge_hashes(defaults.dup, incoming)
        ConfigSection.new(merged)
      }
    end

    # Deep merge helper for coercion
    def self.deep_merge_hashes(base, overlay)
      base.merge(overlay) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_hashes(old_val, new_val)
        else
          new_val.nil? ? old_val : new_val
        end
      end
    end

    coerce_types(
      # Nested sections -> ConfigSection objects (with SCHEMA defaults merged)
      database: config_section_with_defaults(:database),
      service: config_section_with_defaults(:service),
      embedding: config_section_with_defaults(:embedding),
      tag: config_section_with_defaults(:tag),
      proposition: config_section_with_defaults(:proposition),
      chunking: config_section_with_defaults(:chunking),
      circuit_breaker: config_section_with_defaults(:circuit_breaker),
      relevance: config_section_with_defaults(:relevance),
      job: config_section_with_defaults(:job),
      providers: config_section_with_defaults(:providers),

      # Top-level symbols
      week_start: TO_SYMBOL,
      log_level: TO_SYMBOL,

      # Top-level integers
      connection_timeout: :integer,

      # Top-level booleans
      telemetry_enabled: :boolean
    )

    # ==========================================================================
    # Validation
    # ==========================================================================

    # Default embedding dimensions by provider
    DEFAULT_DIMENSIONS = {
      openai: 1536,
      anthropic: 1024,
      gemini: 768,
      azure: 1536,
      ollama: 768,
      huggingface: 768,
      openrouter: 1536,
      bedrock: 1536,
      deepseek: 1536
    }.freeze

    on_load :coerce_nested_types, :reconcile_database_config, :validate_config, :setup_defaults

    # ==========================================================================
    # Callable Accessors (not loaded from config sources)
    # ==========================================================================

    attr_accessor :embedding_generator, :tag_extractor, :proposition_extractor
    attr_accessor :token_counter, :logger

    # ==========================================================================
    # Instance Methods
    # ==========================================================================

    def initialize(...)
      super
      @ollama_models_refreshed = false
      @ollama_refresh_mutex = Mutex.new
    end

    # ==========================================================================
    # Convenience Accessors (for common nested values)
    # ==========================================================================

    # Embedding convenience accessors
    def embedding_provider
      provider = embedding.provider
      provider.is_a?(Symbol) ? provider : provider&.to_sym
    end

    def embedding_model
      embedding.model
    end

    def embedding_dimensions
      embedding.dimensions.to_i
    end

    def embedding_timeout
      embedding.timeout.to_i
    end

    def max_embedding_dimension
      embedding.max_dimension.to_i
    end

    # Tag convenience accessors
    def tag_provider
      provider = tag.provider
      provider.is_a?(Symbol) ? provider : provider&.to_sym
    end

    def tag_model
      tag.model
    end

    def tag_timeout
      tag.timeout.to_i
    end

    def max_tag_depth
      tag.max_depth.to_i
    end

    # Proposition convenience accessors
    def proposition_provider
      provider = proposition.provider
      provider.is_a?(Symbol) ? provider : provider&.to_sym
    end

    def proposition_model
      proposition.model
    end

    def proposition_timeout
      proposition.timeout.to_i
    end

    def extract_propositions
      proposition.enabled
    end

    # Chunking convenience accessors
    def chunk_size
      chunking.size.to_i
    end

    def chunk_overlap
      chunking.overlap.to_i
    end

    # Circuit breaker convenience accessors
    def circuit_breaker_failure_threshold
      circuit_breaker.failure_threshold.to_i
    end

    def circuit_breaker_reset_timeout
      circuit_breaker.reset_timeout.to_i
    end

    def circuit_breaker_half_open_max_calls
      circuit_breaker.half_open_max_calls.to_i
    end

    # Relevance scoring convenience accessors
    def relevance_semantic_weight
      relevance.semantic_weight.to_f
    end

    def relevance_tag_weight
      relevance.tag_weight.to_f
    end

    def relevance_recency_weight
      relevance.recency_weight.to_f
    end

    def relevance_access_weight
      relevance.access_weight.to_f
    end

    def relevance_recency_half_life_hours
      relevance.recency_half_life_hours.to_f
    end

    # Job backend convenience accessor
    def job_backend
      backend = job.backend
      return nil if backend.nil?

      backend.is_a?(Symbol) ? backend : backend.to_sym
    end

    # Service name convenience accessor
    def service_name
      service.name
    end

    # Provider credential convenience accessors
    def openai_api_key
      providers.openai&.api_key
    end

    def openai_organization
      providers.openai&.organization
    end

    def openai_project
      providers.openai&.project
    end

    def anthropic_api_key
      providers.anthropic&.api_key
    end

    def gemini_api_key
      providers.gemini&.api_key
    end

    def azure_api_key
      providers.azure&.api_key
    end

    def azure_endpoint
      providers.azure&.endpoint
    end

    def azure_api_version
      providers.azure&.api_version
    end

    def ollama_url
      providers.ollama&.url || 'http://localhost:11434'
    end

    def huggingface_api_key
      providers.huggingface&.api_key
    end

    def openrouter_api_key
      providers.openrouter&.api_key
    end

    def bedrock_access_key
      providers.bedrock&.access_key
    end

    def bedrock_secret_key
      providers.bedrock&.secret_key
    end

    def bedrock_region
      providers.bedrock&.region || 'us-east-1'
    end

    def deepseek_api_key
      providers.deepseek&.api_key
    end

    # ==========================================================================
    # Environment Helpers
    # ==========================================================================

    def test?
      self.class.env == 'test'
    end

    def development?
      self.class.env == 'development'
    end

    def production?
      self.class.env == 'production'
    end

    def environment
      self.class.env
    end

    # ==========================================================================
    # Environment Validation
    # ==========================================================================

    # Returns list of valid environment names from bundled defaults
    #
    # @return [Array<Symbol>] valid environment names (e.g., [:development, :production, :test])
    def self.valid_environments
      HTM::Loaders::DefaultsLoader.valid_environments
    end

    # Check if current environment is valid (defined in config)
    #
    # @return [Boolean] true if environment has a config section
    def self.valid_environment?
      HTM::Loaders::DefaultsLoader.valid_environment?(env)
    end

    # Validate that the current environment is configured
    #
    # @raise [HTM::ConfigurationError] if environment is invalid
    # @return [true] if environment is valid
    def self.validate_environment!
      current = env
      return true if HTM::Loaders::DefaultsLoader.valid_environment?(current)

      valid = valid_environments.map(&:to_s).join(', ')
      raise HTM::ConfigurationError,
        "Invalid environment '#{current}'. " \
        "Valid environments are: #{valid}. " \
        "Set HTM_ENV to a valid environment or add a '#{current}:' section to your config."
    end

    # Instance method delegates
    def valid_environment?
      self.class.valid_environment?
    end

    def validate_environment!
      self.class.validate_environment!
    end

    # ==========================================================================
    # XDG Config Path Helpers
    # ==========================================================================

    def self.xdg_config_paths
      HTM::Loaders::XdgConfigLoader.config_paths
    end

    def self.xdg_config_file
      xdg_home = ENV['XDG_CONFIG_HOME']
      base = if xdg_home && !xdg_home.empty?
        xdg_home
      else
        File.expand_path('~/.config')
      end
      File.join(base, 'htm', 'htm.yml')
    end

    def self.active_xdg_config_file
      HTM::Loaders::XdgConfigLoader.find_config_file('htm')
    end

    # ==========================================================================
    # Ollama Helpers
    # ==========================================================================

    def normalize_ollama_model(model_name)
      return model_name if model_name.nil? || model_name.empty?
      return model_name if model_name.include?(':')

      "#{model_name}:latest"
    end

    def configure_ruby_llm(provider = nil)
      require 'ruby_llm'

      provider ||= embedding_provider

      RubyLLM.configure do |config|
        case provider
        when :openai
          config.openai_api_key = openai_api_key if openai_api_key
          config.openai_organization = openai_organization if openai_organization && config.respond_to?(:openai_organization=)
          config.openai_project = openai_project if openai_project && config.respond_to?(:openai_project=)
        when :anthropic
          config.anthropic_api_key = anthropic_api_key if anthropic_api_key
        when :gemini
          config.gemini_api_key = gemini_api_key if gemini_api_key
        when :azure
          config.azure_api_key = azure_api_key if azure_api_key && config.respond_to?(:azure_api_key=)
          config.azure_endpoint = azure_endpoint if azure_endpoint && config.respond_to?(:azure_endpoint=)
          config.azure_api_version = azure_api_version if azure_api_version && config.respond_to?(:azure_api_version=)
        when :ollama
          ollama_api_base = if ollama_url.end_with?('/v1') || ollama_url.end_with?('/v1/')
            ollama_url.sub(%r{/+$}, '')
          else
            "#{ollama_url.sub(%r{/+$}, '')}/v1"
          end
          config.ollama_api_base = ollama_api_base
        when :huggingface
          config.huggingface_api_key = huggingface_api_key if huggingface_api_key && config.respond_to?(:huggingface_api_key=)
        when :openrouter
          config.openrouter_api_key = openrouter_api_key if openrouter_api_key && config.respond_to?(:openrouter_api_key=)
        when :bedrock
          config.bedrock_api_key = bedrock_access_key if bedrock_access_key && config.respond_to?(:bedrock_api_key=)
          config.bedrock_secret_key = bedrock_secret_key if bedrock_secret_key && config.respond_to?(:bedrock_secret_key=)
          config.bedrock_region = bedrock_region if bedrock_region && config.respond_to?(:bedrock_region=)
        when :deepseek
          config.deepseek_api_key = deepseek_api_key if deepseek_api_key && config.respond_to?(:deepseek_api_key=)
        end
      end
    end

    def refresh_ollama_models!
      @ollama_refresh_mutex.synchronize do
        unless @ollama_models_refreshed
          require 'ruby_llm'
          RubyLLM.models.refresh!
          @ollama_models_refreshed = true
        end
      end
    end

    def reset_to_defaults
      @embedding_generator = build_default_embedding_generator
      @tag_extractor = build_default_tag_extractor
      @proposition_extractor = build_default_proposition_extractor
      @token_counter = build_default_token_counter
      @logger = build_default_logger
    end

    def validate!
      validate_callables
      validate_logger
    end

    def validate_settings!
      validate_providers
      validate_job_backend
      validate_week_start
      validate_relevance_weights
    end

    private

    # ==========================================================================
    # Type Coercion Callback
    # ==========================================================================

    def coerce_nested_types
      # Ensure nested provider sections are ConfigSections
      if providers.is_a?(ConfigSection)
        %i[openai anthropic gemini azure ollama huggingface openrouter bedrock deepseek].each do |provider|
          value = providers[provider]
          providers[provider] = ConfigSection.new(value) if value.is_a?(Hash)
        end
      end

      # Coerce database numeric fields to integers (env vars are always strings)
      if database&.port && !database.port.is_a?(Integer)
        database.port = database.port.to_i
      end
      if database&.pool_size && !database.pool_size.is_a?(Integer)
        database.pool_size = database.pool_size.to_i
      end
      if database&.timeout && !database.timeout.is_a?(Integer)
        database.timeout = database.timeout.to_i
      end
    end

    # ==========================================================================
    # Setup Defaults Callback
    # ==========================================================================

    def setup_defaults
      job.backend = detect_job_backend if job_backend.nil?
      @logger ||= build_default_logger
      @embedding_generator ||= build_default_embedding_generator
      @tag_extractor ||= build_default_tag_extractor
      @proposition_extractor ||= build_default_proposition_extractor
      @token_counter ||= build_default_token_counter
    end

    def detect_job_backend
      return :inline if test?
      return :active_job if defined?(ActiveJob)
      return :sidekiq if defined?(Sidekiq)

      :fiber
    end
  end
end

# Register custom loaders after Config class is defined
# Order matters: defaults (lowest priority) -> XDG -> project config -> ENV (highest)
require_relative 'loaders/defaults_loader'
require_relative 'loaders/xdg_config_loader'
