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
    MIN_PROPOSITION_LENGTH = 10   # Minimum characters for a valid proposition
    MAX_PROPOSITION_LENGTH = 1000 # Maximum characters for a valid proposition

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
      HTM.logger.debug "PropositionService: Extracting propositions from #{content.length} chars"

      # Use circuit breaker to protect against cascading failures
      raw_propositions = circuit_breaker.call do
        HTM.configuration.proposition_extractor.call(content)
      end

      # Parse response (may be string or array)
      parsed_propositions = parse_propositions(raw_propositions)

      # Validate and filter propositions
      valid_propositions = validate_and_filter_propositions(parsed_propositions)

      HTM.logger.debug "PropositionService: Extracted #{valid_propositions.length} valid propositions"

      valid_propositions

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

    # Validate and filter propositions
    #
    # @param propositions [Array<String>] Parsed propositions
    # @return [Array<String>] Valid propositions only
    #
    def self.validate_and_filter_propositions(propositions)
      valid_propositions = []

      propositions.each do |proposition|
        # Check minimum length
        if proposition.length < MIN_PROPOSITION_LENGTH
          HTM.logger.debug "PropositionService: Proposition too short, skipping: #{proposition}"
          next
        end

        # Check maximum length
        if proposition.length > MAX_PROPOSITION_LENGTH
          HTM.logger.warn "PropositionService: Proposition too long, skipping: #{proposition[0..50]}..."
          next
        end

        # Check for actual content (not just punctuation/whitespace)
        unless proposition.match?(/[a-zA-Z]{3,}/)
          HTM.logger.debug "PropositionService: Proposition lacks content, skipping: #{proposition}"
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
      return false if proposition.length < MIN_PROPOSITION_LENGTH
      return false if proposition.length > MAX_PROPOSITION_LENGTH
      return false unless proposition.match?(/[a-zA-Z]{3,}/)

      true
    end
  end
end
