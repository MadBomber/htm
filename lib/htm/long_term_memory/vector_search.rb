# frozen_string_literal: true

class HTM
  class LongTermMemory
    # Vector similarity search using pgvector
    #
    # Performs semantic search by:
    # 1. Generating query embedding client-side
    # 2. Using pgvector cosine distance for similarity ranking
    # 3. Supporting timeframe and metadata filtering
    #
    # Results are cached for performance.
    #
    # Security: All queries use parameterized placeholders to prevent SQL injection.
    #
    module VectorSearch
      # Maximum results to prevent DoS via unbounded queries
      MAX_VECTOR_LIMIT = 1000

      # Vector similarity search
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
      # @param query [String] Search query
      # @param limit [Integer] Maximum results (capped at MAX_VECTOR_LIMIT)
      # @param embedding_service [Object] Service to generate embeddings
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Matching nodes
      #
      def search(timeframe:, query:, limit:, embedding_service:, metadata: {})
        # Enforce limit to prevent DoS
        safe_limit = [[limit.to_i, 1].max, MAX_VECTOR_LIMIT].min

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = @cache.fetch(:search, timeframe, query, safe_limit, metadata) do
          search_uncached(
            timeframe: timeframe,
            query: query,
            limit: safe_limit,
            embedding_service: embedding_service,
            metadata: metadata
          )
        end
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round
        HTM::Telemetry.search_latency.record(elapsed_ms, attributes: { 'strategy' => 'vector' })
        result
      end

      private

      # Uncached vector similarity search
      #
      # Generates query embedding client-side and performs vector search in database.
      #
      # @param timeframe [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
      # @param query [String] Search query
      # @param limit [Integer] Maximum results
      # @param embedding_service [Object] Service to generate query embedding
      # @param metadata [Hash] Filter by metadata fields (default: {})
      # @return [Array<Hash>] Matching nodes
      #
      def search_uncached(timeframe:, query:, limit:, embedding_service:, metadata: {})
        # Generate query embedding client-side
        query_embedding = embedding_service.embed(query)

        # Validate embedding before use
        unless query_embedding.is_a?(Array) && query_embedding.any?
          HTM.logger.error("Invalid embedding returned from embedding service")
          return []
        end

        # Pad embedding to target dimension
        padded_embedding = HTM::SqlBuilder.pad_embedding(query_embedding)

        # Sanitize embedding for safe SQL use (validates all values are numeric)
        embedding_str = HTM::SqlBuilder.sanitize_embedding(padded_embedding)

        # Build filter conditions
        timeframe_condition = HTM::SqlBuilder.timeframe_condition(timeframe)
        metadata_condition = HTM::SqlBuilder.metadata_condition(metadata)

        conditions = ["embedding IS NOT NULL", "deleted_at IS NULL"]
        conditions << timeframe_condition if timeframe_condition
        conditions << metadata_condition if metadata_condition

        where_clause = "WHERE #{conditions.join(' AND ')}"

        # Use parameterized query for embedding
        sql = <<~SQL
          SELECT id, content, access_count, created_at, token_count,
                 1 - (embedding <=> ?::vector) as similarity
          FROM nodes
          #{where_clause}
          ORDER BY embedding <=> ?::vector
          LIMIT ?
        SQL

        result = HTM.db.fetch(sql, embedding_str, embedding_str, limit).all

        # Track access for retrieved nodes
        node_ids = result.map { |r| r[:id] }
        track_access(node_ids)

        # Convert to hash with string keys for compatibility
        result.map { |r| r.transform_keys(&:to_s) }
      end
    end
  end
end
