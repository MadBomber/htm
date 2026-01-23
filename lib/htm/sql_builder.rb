# frozen_string_literal: true

class HTM
  # SQL building utilities for constructing safe, parameterized queries
  #
  # Provides class methods for building SQL conditions for:
  # - Timeframe filtering (single range or multiple ranges)
  # - Metadata filtering (JSONB containment)
  # - Embedding sanitization and padding (SQL injection prevention)
  # - LIKE pattern sanitization (wildcard injection prevention)
  #
  # All methods use proper escaping and parameterization to prevent SQL injection.
  #
  # @example Build a timeframe condition
  #   HTM::SqlBuilder.timeframe_condition(1.week.ago..Time.now)
  #   # => "(created_at BETWEEN '2024-01-01' AND '2024-01-08')"
  #
  # @example Build a metadata condition
  #   HTM::SqlBuilder.metadata_condition({ priority: "high" })
  #   # => "(metadata @> '{\"priority\":\"high\"}'::jsonb)"
  #
  # @example Sanitize an embedding
  #   HTM::SqlBuilder.sanitize_embedding([0.1, 0.2, 0.3])
  #   # => "[0.1,0.2,0.3]"
  #
  # @example Sanitize a LIKE pattern
  #   HTM::SqlBuilder.sanitize_like_pattern("test%pattern")
  #   # => "test\\%pattern"
  #
  class SqlBuilder
    # Maximum embedding dimension supported by pgvector with HNSW index
    MAX_EMBEDDING_DIMENSION = 2000

    class << self
      # Sanitize embedding for SQL use
      #
      # Validates that all values are numeric and converts to safe PostgreSQL vector format.
      # This prevents SQL injection by ensuring only valid numeric values are included.
      #
      # @param embedding [Array<Numeric>] Embedding vector
      # @return [String] Sanitized vector string for PostgreSQL (e.g., "[0.1,0.2,0.3]")
      # @raise [ArgumentError] If embedding contains non-numeric values
      #
      def sanitize_embedding(embedding)
        unless embedding.is_a?(Array)
          raise ArgumentError, "Embedding must be an Array, got #{embedding.class}"
        end

        if embedding.empty?
          raise ArgumentError, "Embedding cannot be empty"
        end

        # Find invalid values for detailed error message
        invalid_indices = []
        embedding.each_with_index do |v, i|
          unless v.is_a?(Numeric) && v.respond_to?(:finite?) && v.finite?
            invalid_indices << i
          end
        end

        unless invalid_indices.empty?
          sample = invalid_indices.first(5).map { |i| "index #{i}: #{embedding[i].inspect}" }.join(", ")
          raise ArgumentError, "Embedding contains invalid values at #{sample}"
        end

        "[#{embedding.map { |v| v.to_f }.join(',')}]"
      end

      # Pad embedding to target dimension
      #
      # Pads embedding with zeros to reach the target dimension for pgvector compatibility.
      #
      # @param embedding [Array<Numeric>] Embedding vector
      # @param target_dimension [Integer] Target dimension (default: MAX_EMBEDDING_DIMENSION)
      # @return [Array<Numeric>] Padded embedding
      #
      def pad_embedding(embedding, target_dimension: MAX_EMBEDDING_DIMENSION)
        return embedding if embedding.length >= target_dimension

        embedding + Array.new(target_dimension - embedding.length, 0.0)
      end

      # Sanitize a string for use in SQL LIKE patterns
      #
      # Escapes SQL LIKE wildcards (% and _) to prevent pattern injection.
      #
      # @param pattern [String] Pattern to sanitize
      # @return [String] Sanitized pattern safe for LIKE queries
      #
      def sanitize_like_pattern(pattern)
        return "" if pattern.nil?

        pattern.to_s.gsub(/[%_\\]/) { |match| "\\#{match}" }
      end

      # Build SQL condition for timeframe filtering
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s)
      # @param table_alias [String, nil] Table alias (default: none)
      # @param column [String] Column name (default: "created_at")
      # @return [String, nil] SQL condition or nil for no filter
      #
      def timeframe_condition(timeframe, table_alias: nil, column: "created_at")
        return nil if timeframe.nil?

        prefix = table_alias ? "#{table_alias}." : ""
        full_column = "#{prefix}#{column}"

        case timeframe
        when Range
          begin_quoted = HTM.db.literal(timeframe.begin.iso8601)
          end_quoted = HTM.db.literal(timeframe.end.iso8601)
          "(#{full_column} BETWEEN #{begin_quoted} AND #{end_quoted})"
        when Array
          conditions = timeframe.map do |range|
            begin_quoted = HTM.db.literal(range.begin.iso8601)
            end_quoted = HTM.db.literal(range.end.iso8601)
            "(#{full_column} BETWEEN #{begin_quoted} AND #{end_quoted})"
          end
          "(#{conditions.join(' OR ')})"
        end
      end

      # Apply timeframe filter to Sequel dataset
      #
      # @param scope [Sequel::Dataset] Base dataset
      # @param timeframe [nil, Range, Array<Range>] Time range(s)
      # @param column [Symbol] Column name (default: :created_at)
      # @return [Sequel::Dataset] Filtered dataset
      #
      def apply_timeframe(scope, timeframe, column: :created_at)
        return scope if timeframe.nil?

        case timeframe
        when Range
          scope.where(column => timeframe)
        when Array
          conditions = timeframe.map { |range| Sequel.expr(column => range) }
          scope.where(Sequel.|(*conditions))
        else
          scope
        end
      end

      # Build SQL condition for metadata filtering (JSONB containment)
      #
      # @param metadata [Hash] Metadata to filter by
      # @param table_alias [String, nil] Table alias (default: none)
      # @param column [String] Column name (default: "metadata")
      # @return [String, nil] SQL condition or nil for no filter
      #
      def metadata_condition(metadata, table_alias: nil, column: "metadata")
        return nil if metadata.nil? || metadata.empty?

        prefix = table_alias ? "#{table_alias}." : ""
        full_column = "#{prefix}#{column}"

        quoted_metadata = HTM.db.literal(metadata.to_json)
        "(#{full_column} @> #{quoted_metadata}::jsonb)"
      end

      # Apply metadata filter to Sequel dataset
      #
      # @param scope [Sequel::Dataset] Base dataset
      # @param metadata [Hash] Metadata to filter by
      # @param column [String] Column name (default: "metadata")
      # @return [Sequel::Dataset] Filtered dataset
      #
      def apply_metadata(scope, metadata, column: "metadata")
        return scope if metadata.nil? || metadata.empty?

        scope.where(Sequel.lit("#{column} @> ?::jsonb", metadata.to_json))
      end
    end
  end
end
