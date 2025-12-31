# frozen_string_literal: true

require_relative 'errors'
require 'active_support/core_ext/string/inflections'

class HTM
  # Tag Service - Processes and validates hierarchical tags
  #
  # This service wraps the configured tag extractor and provides:
  # - Response parsing (string or array)
  # - Format validation (lowercase, alphanumeric, hyphens, colons)
  # - Depth validation (max 5 levels)
  # - Ontology consistency
  # - Circuit breaker protection for external LLM failures
  #
  # The actual LLM call is delegated to HTM.configuration.tag_extractor
  #
  class TagService
    TAG_FORMAT = /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/  # Validation regex

    # Circuit breaker for tag extraction API calls
    @circuit_breaker = nil
    @circuit_breaker_mutex = Mutex.new

    class << self
      # Maximum tag hierarchy depth (configurable, default 4)
      #
      # @return [Integer] Max depth (3 colons max by default)
      #
      def max_depth
        HTM.configuration.max_tag_depth
      end

      # Get or create the circuit breaker for tag service
      #
      # @return [HTM::CircuitBreaker] The circuit breaker instance
      #
      def circuit_breaker
        config = HTM.configuration
        @circuit_breaker_mutex.synchronize do
          @circuit_breaker ||= HTM::CircuitBreaker.new(
            name: 'tag_service',
            failure_threshold: config.circuit_breaker_failure_threshold,
            reset_timeout: config.circuit_breaker_reset_timeout,
            half_open_max_calls: config.circuit_breaker_half_open_max_calls
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

    # Extract tags with validation and processing
    #
    # @param content [String] Text to analyze
    # @param existing_ontology [Array<String>] Sample of existing tags for context
    # @return [Array<String>] Validated tag names
    # @raise [CircuitBreakerOpenError] If circuit breaker is open
    #
    def self.extract(content, existing_ontology: [])
      # Use circuit breaker to protect against cascading failures
      raw_tags = circuit_breaker.call do
        HTM.configuration.tag_extractor.call(content, existing_ontology)
      end

      # Parse response (may be string or array)
      parsed_tags = parse_tags(raw_tags)

      # Validate and filter tags
      validate_and_filter_tags(parsed_tags)

    rescue HTM::CircuitBreakerOpenError
      # Re-raise circuit breaker errors without wrapping
      raise
    rescue HTM::TagError
      raise
    rescue StandardError => e
      HTM.logger.error "TagService: Failed to extract tags: #{e.message}"
      raise HTM::TagError, "Tag extraction failed: #{e.message}"
    end

    # Parse tag response (handles string or array input)
    #
    # @param raw_tags [String, Array] Raw response from extractor
    # @return [Array<String>] Parsed tag strings
    #
    def self.parse_tags(raw_tags)
      case raw_tags
      when Array
        # Already an array, return as-is
        raw_tags.map(&:to_s).map(&:strip).reject(&:empty?)
      when String
        # String response - split by newlines
        raw_tags.split("\n").map(&:strip).reject(&:empty?)
      else
        raise HTM::TagError, "Tag response must be Array or String, got #{raw_tags.class}"
      end
    end

    # Validate and filter tags
    #
    # @param tags [Array<String>] Parsed tags
    # @return [Array<String>] Valid tags only
    #
    def self.validate_and_filter_tags(tags)
      valid_tags = []

      tags.each do |tag|
        # Normalize: convert plural levels to singular
        tag = singularize_tag_levels(tag)
        # Check format
        unless tag.match?(TAG_FORMAT)
          HTM.logger.warn "TagService: Invalid tag format, skipping: #{tag}"
          next
        end

        # Check depth
        depth = tag.count(':')
        max_tag_depth = max_depth
        if depth >= max_tag_depth
          HTM.logger.warn "TagService: Tag depth #{depth + 1} exceeds max #{max_tag_depth}, skipping: #{tag}"
          next
        end

        # Parse hierarchy for ontological validation
        levels = tag.split(':')

        # Check for self-containment (root == leaf creates circular reference)
        if levels.size > 1 && levels.first == levels.last
          HTM.logger.warn "TagService: Self-containment detected (root == leaf), skipping: #{tag}"
          next
        end

        # Check for duplicate segments in path (indicates circular/redundant hierarchy)
        if levels.size != levels.uniq.size
          HTM.logger.warn "TagService: Duplicate segment in hierarchy, skipping: #{tag}"
          next
        end

        # Tag is valid
        valid_tags << tag
      end

      valid_tags.uniq
    end

    # Validate single tag format
    #
    # @param tag [String] Tag to validate
    # @return [Boolean] True if valid
    #
    def self.valid_tag?(tag)
      return false unless tag.is_a?(String)
      return false if tag.empty?
      return false unless tag.match?(TAG_FORMAT)
      return false if tag.count(':') >= max_depth

      # Ontological validation
      levels = tag.split(':')
      return false if levels.size > 1 && levels.first == levels.last  # Self-containment
      return false if levels.size != levels.uniq.size  # Duplicate segments

      true
    end

    # Parse hierarchical structure of a tag
    #
    # @param tag [String] Hierarchical tag (e.g., "ai:llm:embedding")
    # @return [Hash] Hierarchy structure
    #   {
    #     full: "ai:llm:embedding",
    #     root: "ai",
    #     parent: "ai:llm",
    #     levels: ["ai", "llm", "embedding"],
    #     depth: 3
    #   }
    #
    def self.parse_hierarchy(tag)
      levels = tag.split(':')

      {
        full: tag,
        root: levels.first,
        parent: levels.size > 1 ? levels[0..-2].join(':') : nil,
        levels: levels,
        depth: levels.size
      }
    end

    # Words that should NOT be singularized (proper nouns, technical terms, etc.)
    SINGULARIZE_SKIP_LIST = %w[
      rails kubernetes aws gcp azure s3 ios macos redis postgres
      postgresql mysql jenkins travis github gitlab mkdocs devops
      analytics statistics mathematics physics ethics dynamics
      graphics linguistics economics robotics
      pages windows
    ].freeze

    # Normalize tag levels to singular form
    #
    # Converts plural levels to singular using ActiveSupport's singularize.
    # This ensures taxonomy consistency (e.g., "users" -> "user").
    #
    # Skips:
    # - Proper nouns and technical terms (Rails, MkDocs, etc.)
    # - Words ending in -ics (analytics, robotics, etc.)
    # - Words that don't end in common plural patterns
    #
    # @param tag [String] Tag with potentially plural levels
    # @return [String] Tag with all levels singularized
    #
    def self.singularize_tag_levels(tag)
      levels = tag.split(':')
      singularized = levels.map do |level|
        singularize_level(level)
      end
      singularized.join(':')
    rescue NoMethodError
      # singularize not available (ActiveSupport not loaded)
      tag
    end

    # Singularize a single tag level with safety checks
    #
    # @param level [String] Single tag level
    # @return [String] Singularized level or original if skipped
    #
    def self.singularize_level(level)
      # Skip if in the skip list
      return level if SINGULARIZE_SKIP_LIST.include?(level.downcase)

      # Skip words ending in -ics (usually singular: analytics, robotics, etc.)
      return level if level.end_with?('ics')

      # Skip words ending in -ous (adjectives: victorious, precious, etc.)
      return level if level.end_with?('ous')

      # Skip words ending in -ss (class, access, etc.)
      return level if level.end_with?('ss')

      # Skip single-letter or very short words
      return level if level.length <= 2

      # Only singularize if it looks like a regular plural
      # (ends in s but not ss, ics, ous)
      unless level.end_with?('s')
        return level
      end

      singular = level.singularize

      # Sanity check: if singularize made it weird, keep original
      # (e.g., "pages" -> "page" is fine, but "bus" -> "bu" is not)
      if singular.length < level.length - 2
        return level
      end

      if singular != level
        HTM.logger.debug "TagService: Normalized '#{level}' to '#{singular}'"
      end

      singular
    end
  end
end
