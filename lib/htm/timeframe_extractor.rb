# frozen_string_literal: true

require 'chronic'

class HTM
  # Timeframe Extractor - Extracts temporal expressions from queries
  #
  # This service parses natural language time expressions from recall queries
  # and returns both the timeframe and the cleaned query text.
  #
  # Supports:
  # - Standard time expressions via Chronic gem ("yesterday", "last week", etc.)
  # - "few" keyword mapped to FEW constant (e.g., "few days ago" → "3 days ago")
  # - "recent/recently" without units defaults to FEW days
  #
  # @example Basic usage
  #   result = TimeframeExtractor.extract("what did we discuss last week about PostgreSQL")
  #   result[:query]     # => "what did we discuss about PostgreSQL"
  #   result[:timeframe] # => #<Range: 2025-11-21..2025-11-28>
  #
  # @example With "few" keyword
  #   result = TimeframeExtractor.extract("show me notes from a few days ago")
  #   result[:timeframe] # => Time object for 3 days ago
  #
  # @example With "recently"
  #   result = TimeframeExtractor.extract("what did we recently discuss")
  #   result[:timeframe] # => Range from 3 days ago to now
  #
  class TimeframeExtractor
    # The numeric value for "few" and "recently" without units
    FEW = 3

    # Default unit for "recently" when no time unit is specified
    DEFAULT_RECENT_UNIT = :days

    # Time unit patterns for matching
    TIME_UNITS = %w[
      seconds? minutes? hours? days? weeks? months? years?
    ].join('|').freeze

    # Word-to-number mapping for written numbers
    WORD_NUMBERS = {
      'one' => 1, 'two' => 2, 'three' => 3, 'four' => 4, 'five' => 5,
      'six' => 6, 'seven' => 7, 'eight' => 8, 'nine' => 9, 'ten' => 10
    }.freeze

    # Seconds per singular time unit (used by parse_last_x and parse_recent)
    UNIT_SECONDS = {
      'second' => 1,
      'minute' => 60,
      'hour'   => 3_600,
      'day'    => 86_400,
      'week'   => 604_800,
      'month'  => 2_592_000,
      'year'   => 31_536_000
    }.freeze

    # Patterns for temporal expressions (order matters - more specific first)
    # Each pattern should match ORIGINAL text (including "few", "a few")
    TEMPORAL_PATTERNS = [
      # "between X and Y" - date ranges
      /\bbetween\s+(.+?)\s+and\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "from X to Y" - date ranges
      /\bfrom\s+(.+?)\s+to\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "since X" - from date to now
      /\bsince\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "before/after X"
      /\b(before|after)\s+(.+?)(?=\s+(?:about|regarding|for|on|with)|$)/i,

      # "in the last/past X units" (including "few", "a few", "several")
      /\bin\s+the\s+(?:last|past)\s+(?:\d+|few|a\s+few|several)\s+(?:#{TIME_UNITS})/i,

      # "weekend before last" / "the weekend before last"
      /\b(?:the\s+)?weekend\s+before\s+last\b/i,

      # "N weekends ago" (numeric or written)
      /\b(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten|few|a\s+few|several)\s+weekends?\s+ago\b/i,

      # "a few X ago" or "few X ago"
      /\b(?:a\s+)?few\s+(?:#{TIME_UNITS})\s+ago\b/i,

      # "X units ago"
      /\b\d+\s+(?:#{TIME_UNITS})\s+ago\b/i,

      # "last/this/next weekend"
      /\b(?:last|this|next)\s+weekend\b/i,

      # "last/this/next X" (week, month, year, monday, etc.)
      /\b(?:last|this|next)\s+(?:week|month|year|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i,

      # "recently" or "recent" as standalone or with context
      /\b(?:recently|recent)\b/i,

      # Standard time words
      /\b(?:yesterday|today|tonight|this\s+morning|this\s+afternoon|this\s+evening|last\s+night)\b/i
    ].freeze

    # Result structure for extracted timeframe
    Result = Struct.new(:query, :timeframe, :original_expression, keyword_init: true)

    class << self
      # Extract timeframe from a query string
      #
      # @param query [String] The query to parse
      # @return [Result] Struct with :query (cleaned), :timeframe, :original_expression
      #
      def extract(query)
        return Result.new(query: query, timeframe: nil, original_expression: nil) if query.nil? || query.strip.empty?

        # Try each pattern against the ORIGINAL query
        TEMPORAL_PATTERNS.each do |pattern|
          match = query.match(pattern)
          next unless match

          original_expression = match[0].strip
          timeframe = parse_expression(original_expression)
          next unless timeframe

          # Remove the matched expression from query
          cleaned_query = clean_query(query, original_expression)

          return Result.new(
            query: cleaned_query,
            timeframe: timeframe,
            original_expression: original_expression
          )
        end

        # No temporal expression found
        Result.new(query: query, timeframe: nil, original_expression: nil)
      end

      # Check if query contains a temporal expression
      #
      # @param query [String] The query to check
      # @return [Boolean]
      #
      def temporal?(query)
        return false if query.nil? || query.strip.empty?

        TEMPORAL_PATTERNS.any? { |pattern| query.match?(pattern) }
      end

      private

      # Normalize "few" and "a few" to the FEW constant value
      #
      # @param text [String] Text to normalize
      # @return [String] Normalized text
      #
      def normalize_few_keywords(text)
        text
          .gsub(/\ba\s+few\b/i, FEW.to_s)
          .gsub(/\bfew\b/i, FEW.to_s)
          .gsub(/\bseveral\b/i, FEW.to_s)
      end

      # Parse a temporal expression into a timeframe
      #
      # @param expression [String] The temporal expression
      # @return [Time, Range, nil] Parsed timeframe
      #
      def parse_expression(expression)
        return parse_recent if expression.match?(/\b(?:recently|recent)\b/i)
        return parse_weekends_ago(2) if expression.match?(/\bweekend\s+before\s+last\b/i)

        if (match = expression.match(/\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten|few|a\s+few|several)\s+weekends?\s+ago\b/i))
          return parse_weekends_ago(parse_number(match[1]))
        end

        normalized    = normalize_few_keywords(expression)
        chronic_expr  = normalized.gsub(/\bin\s+the\s+/i, '')

        if (match = normalized.match(/(?:in\s+the\s+)?(?:last|past)\s+(\d+)\s+(#{TIME_UNITS})/i))
          return parse_last_x(match[1].to_i, match[2])
        end

        chronic_parse_expression(chronic_expr)
      end

      # Parse a number from string (numeric or written word)
      #
      # @param str [String] Number as digit or word
      # @return [Integer] Parsed number
      #
      def parse_number(str)
        normalized = str.downcase.strip
        return FEW if ['few', 'a few', 'several'].include?(normalized)
        return WORD_NUMBERS[normalized] if WORD_NUMBERS.key?(normalized)
        normalized.to_i
      end

      # Parse "N weekends ago" to a Saturday-Sunday range
      #
      # @param count [Integer] Number of weekends ago (1 = last weekend)
      # @return [Range] Time range for that weekend (Saturday 00:00 to Monday 00:00)
      #
      def parse_weekends_ago(count)
        now = Time.now
        target_saturday = last_saturday_before(now) - ((count - 1) * 7 * 86_400)
        target_saturday..(target_saturday + (2 * 86_400))
      end

      def chronic_parse_expression(expr)
        week_start = fetch_week_start
        result     = Chronic.parse(expr, guess: false, week_start: week_start)
        return result.begin..result.end if result.respond_to?(:begin) && result.respond_to?(:end)
        Chronic.parse(expr, week_start: week_start)
      end

      def fetch_week_start
        return HTM.configuration.week_start if defined?(HTM) && HTM.respond_to?(:configuration)
        :sunday
      end

      def last_saturday_before(now)
        days_since = (now.wday - 6) % 7
        days_since = 7 if days_since.zero? && now.wday != 6
        Time.new(now.year, now.month, now.day, 0, 0, 0) - (days_since * 86_400)
      end

      # Parse "last X units" or "past X units" to a proper range
      #
      # @param count [Integer] Number of units
      # @param unit [String] Time unit (days, hours, etc.)
      # @return [Range] Time range from count units ago to now
      #
      def parse_last_x(count, unit)
        now = Time.now
        unit_singular = unit.downcase.sub(/s$/, '')
        seconds = count * (UNIT_SECONDS[unit_singular] || UNIT_SECONDS['day'])
        (now - seconds)..now
      end

      # Parse "recently" to a range from FEW days ago to now
      #
      # @return [Range] Time range
      #
      def parse_recent
        now = Time.now
        seconds = FEW * (UNIT_SECONDS[DEFAULT_RECENT_UNIT.to_s] || UNIT_SECONDS['day'])
        (now - seconds)..now
      end

      # Clean the query by removing the temporal expression
      #
      # @param query [String] Original query
      # @param expression [String] Expression to remove
      # @return [String] Cleaned query
      #
      def clean_query(query, expression)
        # Escape special regex characters in the expression
        escaped = Regexp.escape(expression)

        query
          .sub(/#{escaped}/i, '')      # Remove the expression
          .gsub(/\s{2,}/, ' ')          # Collapse multiple spaces
          .gsub(/\s+([,.])/,  '\1')     # Fix space before punctuation
          .strip
      end
    end
  end
end
