# frozen_string_literal: true

require_relative 'errors'
require 'logger'

class HTM
  # HTM Configuration
  #
  # HTM uses RubyLLM for multi-provider LLM support. Supported providers:
  # - :openai (OpenAI API)
  # - :anthropic (Anthropic Claude)
  # - :gemini (Google Gemini)
  # - :azure (Azure OpenAI)
  # - :ollama (Local Ollama - default)
  # - :huggingface (HuggingFace Inference API)
  # - :openrouter (OpenRouter)
  # - :bedrock (AWS Bedrock)
  # - :deepseek (DeepSeek)
  #
  # @example Configure with OpenAI
  #   HTM.configure do |config|
  #     config.embedding_provider = :openai
  #     config.embedding_model = 'text-embedding-3-small'
  #     config.tag_provider = :openai
  #     config.tag_model = 'gpt-4o-mini'
  #     config.openai_api_key = ENV['OPENAI_API_KEY']
  #   end
  #
  # @example Configure with Ollama (default)
  #   HTM.configure do |config|
  #     config.embedding_provider = :ollama
  #     config.embedding_model = 'nomic-embed-text'
  #     config.tag_provider = :ollama
  #     config.tag_model = 'llama3'
  #     config.ollama_url = 'http://localhost:11434'
  #   end
  #
  # @example Configure with Anthropic for tags, OpenAI for embeddings
  #   HTM.configure do |config|
  #     config.embedding_provider = :openai
  #     config.embedding_model = 'text-embedding-3-small'
  #     config.openai_api_key = ENV['OPENAI_API_KEY']
  #     config.tag_provider = :anthropic
  #     config.tag_model = 'claude-3-haiku-20240307'
  #     config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  #   end
  #
  # @example Configure with custom methods
  #   HTM.configure do |config|
  #     config.embedding_generator = ->(text) {
  #       MyApp::LLMService.embed(text)  # Returns Array<Float>
  #     }
  #     config.tag_extractor = ->(text, ontology) {
  #       MyApp::LLMService.extract_tags(text, ontology)  # Returns Array<String>
  #     }
  #     config.logger = Rails.logger
  #   end
  #
  class Configuration
    attr_accessor :embedding_generator, :tag_extractor, :proposition_extractor, :token_counter
    attr_accessor :embedding_model, :embedding_provider, :embedding_dimensions
    attr_accessor :tag_model, :tag_provider
    attr_accessor :proposition_model, :proposition_provider, :extract_propositions
    attr_accessor :embedding_timeout, :tag_timeout, :proposition_timeout, :connection_timeout
    attr_accessor :logger
    attr_accessor :job_backend
    attr_accessor :week_start

    # Limit configuration
    attr_accessor :max_embedding_dimension  # Max vector dimensions (default: 2000)
    attr_accessor :max_tag_depth            # Max tag hierarchy depth (default: 4)

    # Chunking configuration (for file loading)
    attr_accessor :chunk_size               # Max characters per chunk (default: 1024)
    attr_accessor :chunk_overlap            # Character overlap between chunks (default: 64)

    # Circuit breaker configuration
    attr_accessor :circuit_breaker_failure_threshold   # Failures before opening (default: 5)
    attr_accessor :circuit_breaker_reset_timeout       # Seconds before half-open (default: 60)
    attr_accessor :circuit_breaker_half_open_max_calls # Successes to close (default: 3)

    # Relevance scoring weights (must sum to 1.0)
    attr_accessor :relevance_semantic_weight  # Vector similarity weight (default: 0.5)
    attr_accessor :relevance_tag_weight       # Tag overlap weight (default: 0.3)
    attr_accessor :relevance_recency_weight   # Temporal freshness weight (default: 0.1)
    attr_accessor :relevance_access_weight    # Access frequency weight (default: 0.1)
    attr_accessor :relevance_recency_half_life_hours  # Decay half-life in hours (default: 168 = 1 week)

    # Provider-specific API keys and endpoints
    attr_accessor :openai_api_key, :openai_organization, :openai_project
    attr_accessor :anthropic_api_key
    attr_accessor :gemini_api_key
    attr_accessor :azure_api_key, :azure_endpoint, :azure_api_version
    attr_accessor :ollama_url
    attr_accessor :huggingface_api_key
    attr_accessor :openrouter_api_key
    attr_accessor :bedrock_access_key, :bedrock_secret_key, :bedrock_region
    attr_accessor :deepseek_api_key

    # Supported providers
    SUPPORTED_PROVIDERS = %i[
      openai anthropic gemini azure ollama
      huggingface openrouter bedrock deepseek
    ].freeze

    # Default embedding dimensions by provider/model
    DEFAULT_DIMENSIONS = {
      openai: 1536,      # text-embedding-3-small
      anthropic: 1024,   # voyage embeddings
      gemini: 768,       # text-embedding-004
      azure: 1536,       # same as OpenAI
      ollama: 768,       # nomic-embed-text
      huggingface: 768,  # varies by model
      openrouter: 1536,  # varies by model
      bedrock: 1536,     # titan-embed-text
      deepseek: 1536     # varies by model
    }.freeze

    def initialize
      # Default configuration - Ollama for local development
      # All settings can be overridden via HTM_* environment variables
      @embedding_provider                  = ENV.fetch('HTM_EMBEDDING_PROVIDER', 'ollama').to_sym
      @embedding_model                     = ENV.fetch('HTM_EMBEDDING_MODEL', 'nomic-embed-text:latest')
      @embedding_dimensions                = ENV.fetch('HTM_EMBEDDING_DIMENSIONS', 768).to_i

      @tag_provider                        = ENV.fetch('HTM_TAG_PROVIDER', 'ollama').to_sym
      @tag_model                           = ENV.fetch('HTM_TAG_MODEL', 'gemma3:latest')

      @proposition_provider                = ENV.fetch('HTM_PROPOSITION_PROVIDER', 'ollama').to_sym
      @proposition_model                   = ENV.fetch('HTM_PROPOSITION_MODEL', 'gemma3:latest')
      @extract_propositions                = ENV.fetch('HTM_EXTRACT_PROPOSITIONS', 'false').downcase == 'true'

      # Provider credentials from environment variables
      # These use standard provider env var names for compatibility
      @openai_api_key                      = ENV.fetch('HTM_OPENAI_API_KEY', ENV['OPENAI_API_KEY'])
      @openai_organization                 = ENV.fetch('HTM_OPENAI_ORGANIZATION', ENV['OPENAI_ORGANIZATION'])
      @openai_project                      = ENV.fetch('HTM_OPENAI_PROJECT', ENV['OPENAI_PROJECT'])
      @anthropic_api_key                   = ENV.fetch('HTM_ANTHROPIC_API_KEY', ENV['ANTHROPIC_API_KEY'])
      @gemini_api_key                      = ENV.fetch('HTM_GEMINI_API_KEY', ENV['GEMINI_API_KEY'])
      @azure_api_key                       = ENV.fetch('HTM_AZURE_API_KEY', ENV['AZURE_OPENAI_API_KEY'])
      @azure_endpoint                      = ENV.fetch('HTM_AZURE_ENDPOINT', ENV['AZURE_OPENAI_ENDPOINT'])
      @azure_api_version                   = ENV.fetch('HTM_AZURE_API_VERSION', ENV.fetch('AZURE_OPENAI_API_VERSION', '2024-02-01'))
      @ollama_url                          = ENV.fetch('HTM_OLLAMA_URL', ENV['OLLAMA_API_BASE'] || ENV['OLLAMA_URL'] || 'http://localhost:11434')
      @huggingface_api_key                 = ENV.fetch('HTM_HUGGINGFACE_API_KEY', ENV['HUGGINGFACE_API_KEY'])
      @openrouter_api_key                  = ENV.fetch('HTM_OPENROUTER_API_KEY', ENV['OPENROUTER_API_KEY'])
      @bedrock_access_key                  = ENV.fetch('HTM_BEDROCK_ACCESS_KEY', ENV['AWS_ACCESS_KEY_ID'])
      @bedrock_secret_key                  = ENV.fetch('HTM_BEDROCK_SECRET_KEY', ENV['AWS_SECRET_ACCESS_KEY'])
      @bedrock_region                      = ENV.fetch('HTM_BEDROCK_REGION', ENV.fetch('AWS_REGION', 'us-east-1'))
      @deepseek_api_key                    = ENV.fetch('HTM_DEEPSEEK_API_KEY', ENV['DEEPSEEK_API_KEY'])

      # Timeout settings (in seconds) - apply to all LLM providers
      @embedding_timeout                   = ENV.fetch('HTM_EMBEDDING_TIMEOUT', 120).to_i
      @tag_timeout                         = ENV.fetch('HTM_TAG_TIMEOUT', 180).to_i
      @proposition_timeout                 = ENV.fetch('HTM_PROPOSITION_TIMEOUT', 180).to_i
      @connection_timeout                  = ENV.fetch('HTM_CONNECTION_TIMEOUT', 30).to_i

      # Limit settings
      @max_embedding_dimension             = ENV.fetch('HTM_MAX_EMBEDDING_DIMENSION', 2000).to_i
      @max_tag_depth                       = ENV.fetch('HTM_MAX_TAG_DEPTH', 4).to_i

      # Chunking settings (for file loading)
      @chunk_size                          = ENV.fetch('HTM_CHUNK_SIZE', 1024).to_i
      @chunk_overlap                       = ENV.fetch('HTM_CHUNK_OVERLAP', 64).to_i

      # Circuit breaker settings
      @circuit_breaker_failure_threshold   = ENV.fetch('HTM_CIRCUIT_BREAKER_FAILURE_THRESHOLD', 5).to_i
      @circuit_breaker_reset_timeout       = ENV.fetch('HTM_CIRCUIT_BREAKER_RESET_TIMEOUT', 60).to_i
      @circuit_breaker_half_open_max_calls = ENV.fetch('HTM_CIRCUIT_BREAKER_HALF_OPEN_MAX_CALLS', 3).to_i

      # Relevance scoring weights (should sum to 1.0)
      @relevance_semantic_weight           = ENV.fetch('HTM_RELEVANCE_SEMANTIC_WEIGHT', 0.5).to_f
      @relevance_tag_weight                = ENV.fetch('HTM_RELEVANCE_TAG_WEIGHT', 0.3).to_f
      @relevance_recency_weight            = ENV.fetch('HTM_RELEVANCE_RECENCY_WEIGHT', 0.1).to_f
      @relevance_access_weight             = ENV.fetch('HTM_RELEVANCE_ACCESS_WEIGHT', 0.1).to_f
      @relevance_recency_half_life_hours   = ENV.fetch('HTM_RELEVANCE_RECENCY_HALF_LIFE_HOURS', 168.0).to_f

      # Default logger (STDOUT with INFO level)
      @logger                              = default_logger

      # Job backend: inline, thread, active_job, sidekiq (auto-detected if not set)
      @job_backend                         = ENV['HTM_JOB_BACKEND'] ? ENV['HTM_JOB_BACKEND'].to_sym : detect_job_backend

      # Timeframe parsing configuration: sunday or monday
      @week_start                          = ENV.fetch('HTM_WEEK_START', 'sunday').to_sym

      # Thread-safe Ollama model refresh tracking
      @ollama_models_refreshed             = false
      @ollama_refresh_mutex                = Mutex.new

      # Set default implementations
      reset_to_defaults
    end

    # Reset to default RubyLLM-based implementations
    def reset_to_defaults
      @embedding_generator = default_embedding_generator
      @tag_extractor = default_tag_extractor
      @proposition_extractor = default_proposition_extractor
      @token_counter = default_token_counter
    end

    # Validate configuration
    def validate!
      unless @embedding_generator.respond_to?(:call)
        raise HTM::ValidationError, "embedding_generator must be callable (proc, lambda, or object responding to :call)"
      end

      unless @tag_extractor.respond_to?(:call)
        raise HTM::ValidationError, "tag_extractor must be callable (proc, lambda, or object responding to :call)"
      end

      unless @proposition_extractor.respond_to?(:call)
        raise HTM::ValidationError, "proposition_extractor must be callable (proc, lambda, or object responding to :call)"
      end

      unless @token_counter.respond_to?(:call)
        raise HTM::ValidationError, "token_counter must be callable (proc, lambda, or object responding to :call)"
      end

      unless @logger.respond_to?(:info) && @logger.respond_to?(:warn) && @logger.respond_to?(:error)
        raise HTM::ValidationError, "logger must respond to :info, :warn, and :error"
      end

      unless [:active_job, :sidekiq, :inline, :thread].include?(@job_backend)
        raise HTM::ValidationError, "job_backend must be one of: :active_job, :sidekiq, :inline, :thread (got #{@job_backend.inspect})"
      end

      unless [:sunday, :monday].include?(@week_start)
        raise HTM::ValidationError, "week_start must be :sunday or :monday (got #{@week_start.inspect})"
      end

      # Validate provider if specified
      if @embedding_provider && !SUPPORTED_PROVIDERS.include?(@embedding_provider)
        raise HTM::ValidationError, "embedding_provider must be one of: #{SUPPORTED_PROVIDERS.join(', ')} (got #{@embedding_provider.inspect})"
      end

      if @tag_provider && !SUPPORTED_PROVIDERS.include?(@tag_provider)
        raise HTM::ValidationError, "tag_provider must be one of: #{SUPPORTED_PROVIDERS.join(', ')} (got #{@tag_provider.inspect})"
      end

      if @proposition_provider && !SUPPORTED_PROVIDERS.include?(@proposition_provider)
        raise HTM::ValidationError, "proposition_provider must be one of: #{SUPPORTED_PROVIDERS.join(', ')} (got #{@proposition_provider.inspect})"
      end
    end

    # Normalize Ollama model name to include tag if missing
    #
    # Ollama models require a tag (e.g., :latest, :7b, :13b). If the user
    # specifies a model without a tag, we append :latest by default.
    #
    # @param model_name [String] Original model name
    # @return [String] Normalized model name with tag
    #
    def normalize_ollama_model(model_name)
      return model_name if model_name.nil? || model_name.empty?
      return model_name if model_name.include?(':')

      "#{model_name}:latest"
    end

    # Configure RubyLLM with the appropriate provider credentials
    #
    # @param provider [Symbol] The provider to configure (:openai, :anthropic, etc.)
    #
    def configure_ruby_llm(provider = nil)
      # Always require ruby_llm to ensure full module is loaded
      # (require is idempotent, and defined?(RubyLLM) can be true before configure method exists)
      require 'ruby_llm'

      provider ||= @embedding_provider

      RubyLLM.configure do |config|
        case provider
        when :openai
          config.openai_api_key = @openai_api_key if @openai_api_key
          config.openai_organization = @openai_organization if @openai_organization && config.respond_to?(:openai_organization=)
          config.openai_project = @openai_project if @openai_project && config.respond_to?(:openai_project=)
        when :anthropic
          config.anthropic_api_key = @anthropic_api_key if @anthropic_api_key
        when :gemini
          config.gemini_api_key = @gemini_api_key if @gemini_api_key
        when :azure
          config.azure_api_key = @azure_api_key if @azure_api_key && config.respond_to?(:azure_api_key=)
          config.azure_endpoint = @azure_endpoint if @azure_endpoint && config.respond_to?(:azure_endpoint=)
          config.azure_api_version = @azure_api_version if @azure_api_version && config.respond_to?(:azure_api_version=)
        when :ollama
          # Ollama exposes OpenAI-compatible API at /v1
          # Ensure URL has /v1 suffix (add if missing, don't duplicate if present)
          ollama_api_base = if @ollama_url.end_with?('/v1') || @ollama_url.end_with?('/v1/')
            @ollama_url.sub(%r{/+$}, '')  # Just remove trailing slashes
          else
            "#{@ollama_url.sub(%r{/+$}, '')}/v1"
          end
          config.ollama_api_base = ollama_api_base
        when :huggingface
          config.huggingface_api_key = @huggingface_api_key if @huggingface_api_key && config.respond_to?(:huggingface_api_key=)
        when :openrouter
          config.openrouter_api_key = @openrouter_api_key if @openrouter_api_key && config.respond_to?(:openrouter_api_key=)
        when :bedrock
          config.bedrock_api_key = @bedrock_access_key if @bedrock_access_key && config.respond_to?(:bedrock_api_key=)
          config.bedrock_secret_key = @bedrock_secret_key if @bedrock_secret_key && config.respond_to?(:bedrock_secret_key=)
          config.bedrock_region = @bedrock_region if @bedrock_region && config.respond_to?(:bedrock_region=)
        when :deepseek
          config.deepseek_api_key = @deepseek_api_key if @deepseek_api_key && config.respond_to?(:deepseek_api_key=)
        end
      end
    end

    private

    # Auto-detect appropriate job backend based on environment
    #
    # Detection priority:
    # 1. ActiveJob (if defined) - Rails applications
    # 2. Sidekiq (if defined) - Sinatra and other web apps
    # 3. Inline (if test environment) - Test suites
    # 4. Thread (default fallback) - CLI and standalone apps
    #
    # @return [Symbol] Detected job backend
    #
    def detect_job_backend
      # Check for explicit environment variable override
      if ENV['HTM_JOB_BACKEND']
        return ENV['HTM_JOB_BACKEND'].to_sym
      end

      # Detect test environment - use inline for synchronous execution
      test_env = ENV['RACK_ENV'] == 'test' || ENV['RAILS_ENV'] == 'test' || ENV['APP_ENV'] == 'test'
      return :inline if test_env

      # Detect Rails - prefer ActiveJob
      if defined?(ActiveJob)
        return :active_job
      end

      # Detect Sidekiq - direct integration for Sinatra apps
      if defined?(Sidekiq)
        return :sidekiq
      end

      # Default fallback - simple threading for standalone/CLI apps
      :thread
    end

    # Default logger configuration
    def default_logger
      logger = Logger.new($stdout)
      logger.level = ENV.fetch('HTM_LOG_LEVEL', 'INFO').upcase.to_sym
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} -- HTM: #{msg}\n"
      end
      logger
    end

    # Default token counter using Tiktoken
    def default_token_counter
      lambda do |text|
        require 'tiktoken_ruby' unless defined?(Tiktoken)
        encoder = Tiktoken.encoding_for_model("gpt-3.5-turbo")
        encoder.encode(text).length
      end
    end

    # Default embedding generator using RubyLLM
    #
    # @return [Proc] Callable that takes text and returns embedding vector
    #
    def default_embedding_generator
      lambda do |text|
        require 'ruby_llm' unless defined?(RubyLLM)

        # Configure RubyLLM for the embedding provider
        configure_ruby_llm(@embedding_provider)

        # Refresh models for Ollama to discover local models (thread-safe)
        if @embedding_provider == :ollama
          @ollama_refresh_mutex.synchronize do
            unless @ollama_models_refreshed
              RubyLLM.models.refresh!
              @ollama_models_refreshed = true
            end
          end
        end

        # Normalize Ollama model name (ensure it has a tag like :latest)
        model = @embedding_provider == :ollama ? normalize_ollama_model(@embedding_model) : @embedding_model

        # Generate embedding using RubyLLM
        response = RubyLLM.embed(text, model: model)

        # Extract embedding vector from response
        embedding = extract_embedding_from_response(response)

        unless embedding.is_a?(Array) && embedding.all? { |v| v.is_a?(Numeric) }
          raise HTM::EmbeddingError, "Invalid embedding response format from #{@embedding_provider}"
        end

        embedding
      end
    end

    # Extract embedding vector from RubyLLM response
    #
    # @param response [Object] RubyLLM embed response
    # @return [Array<Float>] Embedding vector
    #
    def extract_embedding_from_response(response)
      return nil unless response

      # Handle different response formats from RubyLLM
      case response
      when Array
        # Direct array response
        response
      when ->(r) { r.respond_to?(:vectors) }
        # RubyLLM::Embedding object with vectors method
        vectors = response.vectors
        vectors.is_a?(Array) && vectors.first.is_a?(Array) ? vectors.first : vectors
      when ->(r) { r.respond_to?(:to_a) }
        # Can be converted to array
        response.to_a
      when ->(r) { r.respond_to?(:embedding) }
        # Has embedding attribute
        response.embedding
      else
        # Try to extract vectors from instance variables
        if response.respond_to?(:instance_variable_get)
          vectors = response.instance_variable_get(:@vectors)
          return vectors.first if vectors.is_a?(Array) && vectors.first.is_a?(Array)
          return vectors if vectors.is_a?(Array)
        end
        raise HTM::EmbeddingError, "Cannot extract embedding from response: #{response.class}"
      end
    end

    # Default tag extractor using RubyLLM chat
    #
    # @return [Proc] Callable that takes text and ontology, returns array of tags
    #
    def default_tag_extractor
      lambda do |text, existing_ontology = []|
        require 'ruby_llm' unless defined?(RubyLLM)

        # Configure RubyLLM for the tag provider
        configure_ruby_llm(@tag_provider)

        # Refresh models for Ollama to discover local models (thread-safe)
        if @tag_provider == :ollama
          @ollama_refresh_mutex.synchronize do
            unless @ollama_models_refreshed
              RubyLLM.models.refresh!
              @ollama_models_refreshed = true
            end
          end
        end

        # Normalize Ollama model name (ensure it has a tag like :latest)
        model = @tag_provider == :ollama ? normalize_ollama_model(@tag_model) : @tag_model

        # Build prompt
        taxonomy_context = if existing_ontology.any?
          sample_tags = existing_ontology.sample([existing_ontology.size, 20].min)
          "Existing taxonomy paths: #{sample_tags.join(', ')}\n\nPrefer reusing these paths when the text matches their domain."
        else
          "This is a new taxonomy - establish clear root categories."
        end

        prompt = <<~PROMPT
          Extract classification tags for this text using a HIERARCHICAL TAXONOMY.

          A hierarchical taxonomy is a tree where each concept has exactly ONE parent path:

              domain
              ├── category
              │   ├── subcategory
              │   │   └── specific-term
              │   └── subcategory
              └── category

          #{taxonomy_context}

          TAG FORMAT: domain:category:subcategory:term (colon-separated, max 4 levels)

          LEVEL GUIDELINES:
          - Level 1 (domain): Broad field (database, ai, web, security, devops)
          - Level 2 (category): Major subdivision (database:relational, ai:machine-learning)
          - Level 3 (subcategory): Specific area (database:relational:postgresql)
          - Level 4 (term): Fine detail, use sparingly (database:relational:postgresql:extensions)

          RULES:
          1. Each concept belongs to ONE path only (no duplicates across branches)
          2. Use lowercase, hyphens for multi-word terms (natural-language-processing)
          3. Return 2-5 tags that best classify this text
          4. Match existing taxonomy paths when applicable
          5. More general tags are often better than overly specific ones

          GOOD EXAMPLES:
          - database:postgresql
          - ai:machine-learning:embeddings
          - web:api:rest
          - programming:ruby:gems

          BAD EXAMPLES:
          - postgresql (missing domain - where does it belong?)
          - database:postgresql AND data:storage:postgresql (duplicate concept)
          - ai:ml:nlp:transformers:bert:embeddings (too deep)

          TEXT: #{text}

          Return ONLY tags, one per line.
        PROMPT

        system_prompt = <<~SYSTEM.strip
          You are a taxonomy classifier that assigns texts to a hierarchical classification tree.

          Core principle: Each concept has ONE canonical location in the tree. If "postgresql" exists under "database", never create it elsewhere.

          Your task:
          1. Identify the domains/topics present in the text
          2. Build paths from general (root) to specific (leaf)
          3. Reuse existing taxonomy branches when they fit
          4. Output 2-5 classification paths, one per line
        SYSTEM

        # Use RubyLLM chat for tag extraction
        chat = RubyLLM.chat(model: model)
        chat.with_instructions(system_prompt)
        response = chat.ask(prompt)

        # Extract text from response
        response_text = extract_text_from_response(response)

        # Parse and validate tags
        tags = response_text.to_s.split("\n").map(&:strip).reject(&:empty?)

        # Validate format: lowercase alphanumeric + hyphens + colons
        valid_tags = tags.select do |tag|
          tag =~ /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/
        end

        # Limit depth to 4 levels (3 colons maximum)
        valid_tags.select { |tag| tag.count(':') < 4 }
      end
    end

    # Default proposition extractor using RubyLLM chat
    #
    # @return [Proc] Callable that takes text and returns array of propositions
    #
    def default_proposition_extractor
      lambda do |text|
        require 'ruby_llm' unless defined?(RubyLLM)

        # Configure RubyLLM for the proposition provider
        configure_ruby_llm(@proposition_provider)

        # Refresh models for Ollama to discover local models (thread-safe)
        if @proposition_provider == :ollama
          @ollama_refresh_mutex.synchronize do
            unless @ollama_models_refreshed
              RubyLLM.models.refresh!
              @ollama_models_refreshed = true
            end
          end
        end

        # Normalize Ollama model name (ensure it has a tag like :latest)
        model = @proposition_provider == :ollama ? normalize_ollama_model(@proposition_model) : @proposition_model

        # Build prompt
        prompt = <<~PROMPT
          Extract all ATOMIC factual propositions from the following text.

          An atomic proposition expresses exactly ONE relationship or fact. If a statement combines multiple pieces of information (what, where, when, who, why), split it into separate propositions.

          CRITICAL: Each proposition must contain only ONE of these:
          - ONE subject-verb relationship
          - ONE attribute or property
          - ONE location, time, or qualifier

          Example input: "Todd Warren plans to pursue a PhD in Music at the University of Texas."

          CORRECT atomic output:
          - Todd Warren plans to pursue a PhD.
          - Todd Warren plans to study Music.
          - Todd Warren plans to attend the University of Texas.
          - The University of Texas offers a PhD program in Music.

          WRONG (not atomic - combines multiple facts):
          - Todd Warren plans to pursue a PhD in Music at the University of Texas.

          Example input: "In 1969, Neil Armstrong became the first person to walk on the Moon during the Apollo 11 mission."

          CORRECT atomic output:
          - Neil Armstrong was an astronaut.
          - Neil Armstrong walked on the Moon.
          - Neil Armstrong walked on the Moon in 1969.
          - Neil Armstrong was the first person to walk on the Moon.
          - The Apollo 11 mission occurred in 1969.
          - Neil Armstrong participated in the Apollo 11 mission.

          Rules:
          1. Split compound statements into separate atomic facts
          2. Each proposition = exactly one fact
          3. Use full names, never pronouns
          4. Make each proposition understandable in isolation
          5. Prefer more propositions over fewer

          TEXT: #{text}

          Return ONLY atomic propositions, one per line. Use a dash (-) prefix for each.
        PROMPT

        system_prompt = <<~SYSTEM.strip
          You are an atomic fact extraction system. Your goal is maximum decomposition.

          IMPORTANT: Break every statement into its smallest possible factual units.

          A statement like "John bought a red car in Paris" contains FOUR facts:
          - John bought a car.
          - The car John bought is red.
          - John made a purchase in Paris.
          - John bought a car in Paris.

          Always ask: "Can this be split further?" If yes, split it.

          Rules:
          1. ONE fact per proposition (subject-predicate or subject-attribute)
          2. Never combine location + action + time in one proposition
          3. Never combine multiple attributes in one proposition
          4. Use full names, never pronouns
          5. Each proposition must stand alone without context

          Output ONLY propositions, one per line, prefixed with a dash (-).
        SYSTEM

        # Use RubyLLM chat for proposition extraction
        chat = RubyLLM.chat(model: model)
        chat.with_instructions(system_prompt)
        response = chat.ask(prompt)

        # Extract text from response
        response_text = extract_text_from_response(response)

        # Parse propositions (remove dash prefix, filter empty lines)
        response_text.to_s
          .split("\n")
          .map(&:strip)
          .map { |line| line.sub(/^[-*•]\s*/, '') }
          .map(&:strip)
          .reject(&:empty?)
      end
    end

    # Extract text content from RubyLLM chat response
    #
    # @param response [Object] RubyLLM chat response
    # @return [String] Response text
    #
    def extract_text_from_response(response)
      return '' unless response

      case response
      when String
        response
      when ->(r) { r.respond_to?(:content) }
        response.content.to_s
      when ->(r) { r.respond_to?(:text) }
        response.text.to_s
      when ->(r) { r.respond_to?(:to_s) }
        response.to_s
      else
        ''
      end
    end
  end

  class << self
    attr_writer :configuration

    # Get current configuration
    #
    # @return [HTM::Configuration]
    #
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure HTM
    #
    # @yield [config] Configuration object
    # @yieldparam config [HTM::Configuration]
    #
    # @example Custom configuration
    #   HTM.configure do |config|
    #     config.embedding_generator = ->(text) { MyEmbedder.embed(text) }
    #     config.tag_extractor = ->(text, ontology) { MyTagger.extract(text, ontology) }
    #   end
    #
    # @example Default configuration
    #   HTM.configure  # Uses RubyLLM defaults
    #
    def configure
      yield(configuration) if block_given?
      configuration.validate!
      configuration
    end

    # Reset configuration to defaults
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Generate embedding using EmbeddingService
    #
    # @param text [String] Text to embed
    # @return [Array<Float>] Embedding vector (original, not padded)
    #
    def embed(text)
      result = HTM::EmbeddingService.generate(text)
      result[:embedding]
    end

    # Extract tags using TagService
    #
    # @param text [String] Text to analyze
    # @param existing_ontology [Array<String>] Sample of existing tags for context
    # @return [Array<String>] Extracted and validated tag names
    #
    def extract_tags(text, existing_ontology: [])
      HTM::TagService.extract(text, existing_ontology: existing_ontology)
    end

    # Extract propositions using PropositionService
    #
    # @param text [String] Text to analyze
    # @return [Array<String>] Extracted atomic propositions
    #
    def extract_propositions(text)
      HTM::PropositionService.extract(text)
    end

    # Count tokens using configured counter
    #
    # @param text [String] Text to count tokens for
    # @return [Integer] Token count
    #
    def count_tokens(text)
      configuration.token_counter.call(text)
    rescue StandardError => e
      raise HTM::ValidationError, "Token counting failed: #{e.message}"
    end

    # Get configured logger
    #
    # @return [Logger] Configured logger instance
    #
    def logger
      configuration.logger
    end
  end
end
