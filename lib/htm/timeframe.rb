# frozen_string_literal: true

require 'date'
require 'time'

class HTM
  # Timeframe - Normalizes various timeframe inputs for database queries
  #
  # Handles multiple input types and normalizes them to either:
  # - nil (no timeframe filter)
  # - Range (single time window)
  # - Array<Range> (multiple time windows, OR'd together)
  #
  # @example Various input types
  #   Timeframe.normalize(nil)                    # => nil (no filter)
  #   Timeframe.normalize(Date.today)             # => Range for entire day
  #   Timeframe.normalize(Time.now)               # => Range for entire day
  #   Timeframe.normalize("last week")            # => Range from chronic/extractor
  #   Timeframe.normalize(:auto, query: "...")    # => Extract from query text
  #   Timeframe.normalize(range1..range2)         # => Pass through
  #   Timeframe.normalize([range1, range2])       # => Array of ranges
  #
  class Timeframe
    # Result structure for :auto mode
    Result = Struct.new(:timeframe, :query, :extracted, keyword_init: true)

    class << self
      # Normalize a timeframe input to nil, Range, or Array<Range>
      #
      # @param input [nil, Range, Array, Date, DateTime, Time, String, Symbol] Timeframe specification
      # @param query [String, nil] Query text (required when input is :auto)
      # @return [nil, Range, Array<Range>] Normalized timeframe
      # @return [Result] When input is :auto, returns Result with :timeframe, :query, :extracted
      #
      def normalize(input, query: nil)
        case input
        when nil
          nil

        when :auto
          normalize_auto(query)

        when Range
          validate_range!(input)
          input

        when Array
          normalize_array(input)

        when Date
          normalize_date(input)

        when DateTime
          normalize_datetime(input)

        when Time
          normalize_time(input)

        when String
          normalize_string(input)

        else
          raise ArgumentError, "Unsupported timeframe type: #{input.class}. " \
            "Expected nil, Range, Array<Range>, Date, DateTime, Time, String, or :auto"
        end
      end

      # Check if a value is a valid timeframe input
      #
      # @param input [Object] Value to check
      # @return [Boolean]
      #
      def valid?(input)
        case input
        when nil, :auto, Range, Date, DateTime, Time, String
          true
        when Array
          input.all? { |r| r.is_a?(Range) }
        else
          false
        end
      end

      private

      # Normalize :auto - extract timeframe from query text
      #
      # @param query [String] Query text to parse
      # @return [Result] Result with :timeframe, :query (cleaned), :extracted (original expression)
      #
      def normalize_auto(query)
        raise ArgumentError, "query is required when timeframe is :auto" if query.nil? || query.strip.empty?

        result = HTM::TimeframeExtractor.extract(query)

        Result.new(
          timeframe: result.timeframe,
          query: result.query,
          extracted: result.original_expression
        )
      end

      # Normalize an array of ranges
      #
      # @param array [Array] Array of Range objects
      # @return [Array<Range>] Validated array of ranges
      #
      def normalize_array(array)
        raise ArgumentError, "Array timeframe cannot be empty" if array.empty?

        array.map do |item|
          case item
          when Range
            validate_range!(item)
            item
          when Date
            normalize_date(item)
          when DateTime
            normalize_datetime(item)
          when Time
            normalize_time(item)
          when String
            normalize_string(item)
          else
            raise ArgumentError, "Array elements must be Range, Date, DateTime, Time, or String. Got: #{item.class}"
          end
        end
      end

      # Normalize a Date to a Range spanning the entire day
      #
      # @param date [Date] Date to normalize
      # @return [Range] Time range for entire day
      #
      def normalize_date(date)
        # Convert Date to Time at beginning of day in local timezone
        beginning = Time.new(date.year, date.month, date.day, 0, 0, 0)
        ending = Time.new(date.year, date.month, date.day, 23, 59, 59)
        beginning..ending
      end

      # Normalize a DateTime to a Range spanning the entire day
      #
      # @param datetime [DateTime] DateTime to normalize
      # @return [Range] Time range for entire day containing this moment
      #
      def normalize_datetime(datetime)
        # Extract date portion and create full day range
        normalize_date(datetime.to_date)
      end

      # Normalize a Time to a Range spanning the entire day
      #
      # @param time [Time] Time to normalize
      # @return [Range] Time range for entire day containing this moment
      #
      def normalize_time(time)
        beginning = Time.new(time.year, time.month, time.day, 0, 0, 0, time.utc_offset)
        ending = Time.new(time.year, time.month, time.day, 23, 59, 59, time.utc_offset)
        beginning..ending
      end

      # Normalize a String using TimeframeExtractor
      #
      # @param string [String] Natural language timeframe
      # @return [Range, nil] Parsed timeframe or nil if unparseable
      #
      def normalize_string(string)
        return nil if string.nil? || string.strip.empty?

        result = HTM::TimeframeExtractor.extract(string)

        # If extraction found a timeframe, return it
        return result.timeframe if result.timeframe

        # Fall back to treating the whole string as a timeframe expression
        # (for cases like just "last week" without surrounding text)
        fallback = HTM::TimeframeExtractor.extract("show me #{string}")
        fallback.timeframe
      end

      # Validate that a Range has Time-compatible begin/end
      #
      # @param range [Range] Range to validate
      # @raise [ArgumentError] If range is invalid
      #
      def validate_range!(range)
        unless range.begin.respond_to?(:to_time) && range.end.respond_to?(:to_time)
          raise ArgumentError, "Range must have Time-compatible begin and end values"
        end
      end
    end
  end
end
