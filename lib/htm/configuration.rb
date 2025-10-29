# frozen_string_literal: true

require_relative 'errors'

class HTM
  # HTM Configuration
  #
  # Applications using HTM should configure LLM access by providing two methods:
  # 1. embedding_generator - Converts text to vector embeddings
  # 2. tag_extractor - Extracts hierarchical tags from text
  #
  # @example Configure with custom methods
  #   HTM.configure do |config|
  #     config.embedding_generator = ->(text) {
  #       MyApp::LLMService.embed(text)  # Returns Array<Float>
  #     }
  #     config.tag_extractor = ->(text, ontology) {
  #       MyApp::LLMService.extract_tags(text, ontology)  # Returns Array<String>
  #     }
  #   end
  #
  # @example Use defaults (RubyLLM with Ollama)
  #   HTM.configure  # Uses default implementations
  #
  class Configuration
    attr_accessor :embedding_generator, :tag_extractor
    attr_accessor :embedding_model, :embedding_provider, :embedding_dimensions
    attr_accessor :tag_model, :tag_provider
    attr_accessor :ollama_url

    def initialize
      # Default configuration
      @embedding_provider = :ollama
      @embedding_model = 'nomic-embed-text'
      @embedding_dimensions = 768

      @tag_provider = :ollama
      @tag_model = 'llama3'

      @ollama_url = ENV['OLLAMA_URL'] || 'http://localhost:11434'

      # Set default implementations
      reset_to_defaults
    end

    # Reset to default RubyLLM-based implementations
    def reset_to_defaults
      @embedding_generator = default_embedding_generator
      @tag_extractor = default_tag_extractor
    end

    # Validate configuration
    def validate!
      unless @embedding_generator.respond_to?(:call)
        raise HTM::ValidationError, "embedding_generator must be callable (proc, lambda, or object responding to :call)"
      end

      unless @tag_extractor.respond_to?(:call)
        raise HTM::ValidationError, "tag_extractor must be callable (proc, lambda, or object responding to :call)"
      end
    end

    private

    # Default embedding generator using RubyLLM
    #
    # @return [Proc] Callable that takes text and returns embedding vector
    #
    def default_embedding_generator
      lambda do |text|
        require 'ruby_llm'

        client = RubyLLM::Client.new(
          provider: @embedding_provider,
          model: @embedding_model,
          url: (@embedding_provider == :ollama ? @ollama_url : nil)
        )

        response = client.embed(text)

        # RubyLLM returns different structures depending on provider
        embedding = case @embedding_provider
        when :ollama
          response['embedding']
        when :openai
          response.dig('data', 0, 'embedding')
        else
          raise HTM::EmbeddingError, "Unsupported embedding provider: #{@embedding_provider}"
        end

        unless embedding.is_a?(Array)
          raise HTM::EmbeddingError, "Invalid embedding response format"
        end

        embedding
      end
    end

    # Default tag extractor using RubyLLM
    #
    # @return [Proc] Callable that takes text and ontology, returns array of tags
    #
    def default_tag_extractor
      lambda do |text, existing_ontology = []|
        require 'ruby_llm'

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

        client = RubyLLM::Client.new(
          provider: @tag_provider,
          model: @tag_model,
          url: (@tag_provider == :ollama ? @ollama_url : nil)
        )

        response = client.generate(
          prompt: prompt,
          system: 'You are a precise topic extraction system. Output only topic tags in hierarchical format: root:subtopic:detail',
          temperature: 0
        )

        # Extract response text
        response_text = case @tag_provider
        when :ollama
          response['response']
        when :openai
          response.dig('choices', 0, 'message', 'content')
        else
          raise HTM::TagError, "Unsupported tag provider: #{@tag_provider}"
        end

        # Parse and validate tags
        tags = response_text.to_s.split("\n").map(&:strip).reject(&:empty?)

        # Validate format: lowercase alphanumeric + hyphens + colons
        valid_tags = tags.select do |tag|
          tag =~ /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/
        end

        # Limit depth to 5 levels (4 colons maximum)
        valid_tags.select { |tag| tag.count(':') < 5 }
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

    # Generate embedding using configured generator
    #
    # @param text [String] Text to embed
    # @return [Array<Float>] Embedding vector
    #
    def embed(text)
      configuration.embedding_generator.call(text)
    rescue StandardError => e
      raise HTM::EmbeddingError, "Embedding generation failed: #{e.message}"
    end

    # Extract tags using configured extractor
    #
    # @param text [String] Text to analyze
    # @param existing_ontology [Array<String>] Sample of existing tags for context
    # @return [Array<String>] Extracted tag names
    #
    def extract_tags(text, existing_ontology: [])
      configuration.tag_extractor.call(text, existing_ontology)
    rescue StandardError => e
      raise HTM::TagError, "Tag extraction failed: #{e.message}"
    end
  end
end
