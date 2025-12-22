# frozen_string_literal: true

require_relative 'errors'

class HTM
  # Proposition Service - Extracts atomic factual propositions from text
  #
  # This service breaks complex text into simple, self-contained factual
  # statements that can be stored as independent memory nodes. Each proposition:
  # - Expresses a single fact
  # - Is understandable without context
  # - Uses full names, not pronouns
  # - Includes relevant dates/qualifiers
  # - Contains one subject-predicate relationship
  #
  # The actual LLM call is delegated to HTM.configuration.proposition_extractor
  #
  # @example
  #   propositions = HTM::PropositionService.extract(
  #     "In 1969, Neil Armstrong became the first person to walk on the Moon during Apollo 11."
  #   )
  #   # => ["Neil Armstrong was an astronaut.",
  #   #     "Neil Armstrong walked on the Moon in 1969.",
  #   #     "Neil Armstrong was the first person to walk on the Moon.",
  #   #     "Neil Armstrong walked on the Moon during the Apollo 11 mission.",
  #   #     "The Apollo 11 mission occurred in 1969."]
  #
  class PropositionService
    # Patterns that indicate meta-responses (LLM asking for input instead of extracting)
    META_RESPONSE_PATTERNS = [
      /please provide/i,
      /provide the text/i,
      /provide me with/i,
      /I need the text/i,
      /I am ready/i,
      /waiting for/i,
      /send me the/i,
      /what text would you/i,
      /what would you like/i,
      /cannot extract.*without/i,
      /no text provided/i
    ].freeze

    # Circuit breaker for proposition extraction API calls
    @circuit_breaker = nil
    @circuit_breaker_mutex = Mutex.new

    class << self
      # Get or create the circuit breaker for proposition service
      #
      # @return [HTM::CircuitBreaker] The circuit breaker instance
      #
      def circuit_breaker
        @circuit_breaker_mutex.synchronize do
          @circuit_breaker ||= HTM::CircuitBreaker.new(
            name: 'proposition_service',
            failure_threshold: 5,
            reset_timeout: 60
          )
        end
      end

      # Reset the circuit breaker (useful for testing)
      #
      # @return [void]
      #
      def reset_circuit_breaker!
        @circuit_breaker_mutex.synchronize do
          @circuit_breaker&.reset!
        end
      end
    end

    # Extract propositions from text content
    #
    # @param content [String] Text to analyze
    # @return [Array<String>] Array of atomic propositions
    # @raise [CircuitBreakerOpenError] If circuit breaker is open
    # @raise [PropositionError] If extraction fails
    #
    def self.extract(content)
      # Use circuit breaker to protect against cascading failures
      raw_propositions = circuit_breaker.call do
        HTM.configuration.proposition_extractor.call(content)
      end

      # Parse response (may be string or array)
      parsed_propositions = parse_propositions(raw_propositions)

      # Validate and filter propositions
      validate_and_filter_propositions(parsed_propositions)

    rescue HTM::CircuitBreakerOpenError
      # Re-raise circuit breaker errors without wrapping
      raise
    rescue HTM::PropositionError
      raise
    rescue StandardError => e
      HTM.logger.error "PropositionService: Failed to extract propositions: #{e.message}"
      raise HTM::PropositionError, "Proposition extraction failed: #{e.message}"
    end

    # Parse proposition response (handles string or array input)
    #
    # @param raw_propositions [String, Array] Raw response from extractor
    # @return [Array<String>] Parsed proposition strings
    #
    def self.parse_propositions(raw_propositions)
      case raw_propositions
      when Array
        # Already an array, return as-is
        raw_propositions.map(&:to_s).map(&:strip).reject(&:empty?)
      when String
        # String response - split by newlines, remove list markers
        raw_propositions
          .split("\n")
          .map(&:strip)
          .map { |line| line.sub(/^[-*•]\s*/, '') } # Remove bullet points
          .map { |line| line.sub(/^\d+\.\s*/, '') } # Remove numbered lists
          .map(&:strip)
          .reject(&:empty?)
      else
        raise HTM::PropositionError, "Proposition response must be Array or String, got #{raw_propositions.class}"
      end
    end

    # Get minimum character length from config
    #
    # @return [Integer] Minimum character count for valid propositions
    #
    def self.min_length
      HTM.config.proposition.min_length || 10
    rescue
      10
    end

    # Get maximum character length from config
    #
    # @return [Integer] Maximum character count for valid propositions
    #
    def self.max_length
      HTM.config.proposition.max_length || 1000
    rescue
      1000
    end

    # Get minimum words from config
    #
    # @return [Integer] Minimum word count for valid propositions
    #
    def self.min_words
      HTM.config.proposition.min_words || 5
    rescue
      5
    end

    # Check if proposition is a meta-response (LLM asking for input)
    #
    # @param proposition [String] Proposition to check
    # @return [Boolean] True if it's a meta-response
    #
    def self.meta_response?(proposition)
      META_RESPONSE_PATTERNS.any? { |pattern| proposition.match?(pattern) }
    end

    # Validate and filter propositions
    #
    # @param propositions [Array<String>] Parsed propositions
    # @return [Array<String>] Valid propositions only
    #
    def self.validate_and_filter_propositions(propositions)
      valid_propositions = []
      min_char_length = min_length
      max_char_length = max_length
      min_word_count = min_words

      propositions.each do |proposition|
        # Check minimum length (characters)
        next if proposition.length < min_char_length

        # Check maximum length
        if proposition.length > max_char_length
          HTM.logger.warn "PropositionService: Proposition too long, skipping: #{proposition[0..50]}..."
          next
        end

        # Check for actual content (not just punctuation/whitespace)
        unless proposition.match?(/[a-zA-Z]{3,}/)
          next
        end

        # Check minimum word count
        word_count = proposition.split.size
        if word_count < min_word_count
          HTM.logger.debug "PropositionService: Proposition too short (#{word_count} words), skipping: #{proposition}"
          next
        end

        # Filter out meta-responses (LLM asking for more input)
        if meta_response?(proposition)
          HTM.logger.warn "PropositionService: Filtered meta-response: #{proposition[0..50]}..."
          next
        end

        # Proposition is valid
        valid_propositions << proposition
      end

      valid_propositions.uniq
    end

    # Validate single proposition
    #
    # @param proposition [String] Proposition to validate
    # @return [Boolean] True if valid
    #
    def self.valid_proposition?(proposition)
      return false unless proposition.is_a?(String)
      return false if proposition.length < min_length
      return false if proposition.length > max_length
      return false unless proposition.match?(/[a-zA-Z]{3,}/)
      return false if proposition.split.size < min_words
      return false if meta_response?(proposition)

      true
    end
  end
end
