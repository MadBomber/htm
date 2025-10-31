# frozen_string_literal: true

require_relative 'errors'
require 'logger'

class HTM
  # HTM Configuration
  #
  # Applications using HTM should configure LLM access by providing two methods:
  # 1. embedding_generator - Converts text to vector embeddings
  # 2. tag_extractor - Extracts hierarchical tags from text
  # 3. logger - Logger instance for HTM operations
  #
  # @example Configure with custom methods
  #   HTM.configure do |config|
  #     config.embedding_generator = ->(text) {
  #       MyApp::LLMService.embed(text)  # Returns Array<Float>
  #     }
  #     config.tag_extractor = ->(text, ontology) {
  #       MyApp::LLMService.extract_tags(text, ontology)  # Returns Array<String>
  #     }
  #     config.logger = Rails.logger  # Use Rails logger
  #   end
  #
  # @example Use defaults with custom timeouts
  #   HTM.configure do |config|
  #     config.embedding_timeout = 60      # 1 minute for faster models
  #     config.tag_timeout = 300           # 5 minutes for larger models
  #     config.connection_timeout = 10     # 10 seconds connection timeout
  #     config.reset_to_defaults  # Apply default implementations with new timeouts
  #   end
  #
  # @example Use defaults
  #   HTM.configure  # Uses default implementations
  #
  class Configuration
    attr_accessor :embedding_generator, :tag_extractor, :token_counter
    attr_accessor :embedding_model, :embedding_provider, :embedding_dimensions
    attr_accessor :tag_model, :tag_provider
    attr_accessor :ollama_url
    attr_accessor :embedding_timeout, :tag_timeout, :connection_timeout
    attr_accessor :logger

    def initialize
      # Default configuration
      @embedding_provider = :ollama
      @embedding_model = 'nomic-embed-text'
      @embedding_dimensions = 768

      @tag_provider = :ollama
      @tag_model = 'llama3'

      @ollama_url = ENV['OLLAMA_URL'] || 'http://localhost:11434'

      # Timeout settings (in seconds) - apply to all LLM providers
      @embedding_timeout = 120      # 2 minutes for embedding generation
      @tag_timeout = 180            # 3 minutes for tag generation (LLM inference)
      @connection_timeout = 30      # 30 seconds for initial connection

      # Default logger (STDOUT with INFO level)
      @logger = default_logger

      # Set default implementations
      reset_to_defaults
    end

    # Reset to default RubyLLM-based implementations
    def reset_to_defaults
      @embedding_generator = default_embedding_generator
      @tag_extractor = default_tag_extractor
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

      unless @token_counter.respond_to?(:call)
        raise HTM::ValidationError, "token_counter must be callable (proc, lambda, or object responding to :call)"
      end

      unless @logger.respond_to?(:info) && @logger.respond_to?(:warn) && @logger.respond_to?(:error)
        raise HTM::ValidationError, "logger must respond to :info, :warn, and :error"
      end
    end

    private

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

    # Default embedding generator using Ollama HTTP API
    #
    # @return [Proc] Callable that takes text and returns embedding vector
    #
    def default_embedding_generator
      lambda do |text|
        require 'net/http'
        require 'json'

        case @embedding_provider
        when :ollama
          uri = URI("#{@ollama_url}/api/embeddings")
          request = Net::HTTP::Post.new(uri)
          request['Content-Type'] = 'application/json'
          request.body = { model: @embedding_model, prompt: text }.to_json

          response = Net::HTTP.start(uri.hostname, uri.port,
            read_timeout: @embedding_timeout,
            open_timeout: @connection_timeout) do |http|
            http.request(request)
          end

          data = JSON.parse(response.body)
          embedding = data['embedding']

          unless embedding.is_a?(Array)
            raise HTM::EmbeddingError, "Invalid embedding response format"
          end

          embedding
        else
          raise HTM::EmbeddingError, "Unsupported embedding provider: #{@embedding_provider}. Only :ollama is currently supported."
        end
      end
    end

    # Default tag extractor using Ollama HTTP API
    #
    # @return [Proc] Callable that takes text and ontology, returns array of tags
    #
    def default_tag_extractor
      lambda do |text, existing_ontology = []|
        require 'net/http'
        require 'json'

        # Build prompt
        ontology_context = if existing_ontology.any?
          sample_tags = existing_ontology.sample([existing_ontology.size, 20].min)
          "Existing ontology includes: #{sample_tags.join(', ')}\n"
        else
          "This is a new ontology - create appropriate hierarchical tags.\n"
        end

        prompt = <<~PROMPT
          Extract hierarchical topic tags from the following text.

          #{ontology_context}
          Format: root:level1:level2:level3 (use colons to separate levels)

          Rules:
          - Use lowercase letters, numbers, and hyphens only
          - Maximum depth: 5 levels
          - Return 2-5 tags per text
          - Tags should be reusable and consistent
          - Prefer existing ontology tags when applicable
          - Use hyphens for multi-word terms (e.g., natural-language-processing)

          Text: #{text}

          Return ONLY the topic tags, one per line, no explanations.
        PROMPT

        case @tag_provider
        when :ollama
          uri = URI("#{@ollama_url}/api/generate")
          request = Net::HTTP::Post.new(uri)
          request['Content-Type'] = 'application/json'
          request.body = {
            model: @tag_model,
            prompt: prompt,
            system: 'You are a precise topic extraction system. Output only topic tags in hierarchical format: root:subtopic:detail',
            stream: false,
            options: { temperature: 0 }
          }.to_json

          response = Net::HTTP.start(uri.hostname, uri.port,
            read_timeout: @tag_timeout,
            open_timeout: @connection_timeout) do |http|
            http.request(request)
          end

          data = JSON.parse(response.body)
          response_text = data['response']

          # Parse and validate tags
          tags = response_text.to_s.split("\n").map(&:strip).reject(&:empty?)

          # Validate format: lowercase alphanumeric + hyphens + colons
          valid_tags = tags.select do |tag|
            tag =~ /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/
          end

          # Limit depth to 5 levels (4 colons maximum)
          valid_tags.select { |tag| tag.count(':') < 5 }
        else
          raise HTM::TagError, "Unsupported tag provider: #{@tag_provider}. Only :ollama is currently supported."
        end
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
