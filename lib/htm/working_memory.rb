# frozen_string_literal: true

class HTM
  # Working Memory - Token-limited active context for immediate LLM use
  #
  # WorkingMemory manages the active conversation context within token limits.
  # When full, it evicts less important or older nodes back to long-term storage.
  #
  # Thread Safety: All public methods are protected by a mutex to ensure
  # safe concurrent access from multiple threads.
  #
  class WorkingMemory
    attr_reader :max_tokens

    # Initialize working memory
    #
    # @param max_tokens [Integer] Maximum tokens allowed in working memory
    #
    def initialize(max_tokens:)
      @max_tokens = max_tokens
      @nodes = {}
      @access_order = []
      @mutex = Mutex.new
    end

    # Add a node to working memory
    #
    # @param key [String] Node identifier
    # @param value [String] Node content
    # @param token_count [Integer] Number of tokens in this node
    # @param access_count [Integer] Access count from long-term memory (default: 0)
    # @param last_accessed [Time, nil] Last access time from long-term memory
    # @param from_recall [Boolean] Whether this node was recalled from long-term memory
    # @return [void]
    #
    def add(key, value, token_count:, access_count: 0, last_accessed: nil, from_recall: false)
      @mutex.synchronize do
        @nodes[key] = {
          value: value,
          token_count: token_count,
          access_count: access_count,
          last_accessed: last_accessed || Time.now,
          added_at: Time.now,
          from_recall: from_recall
        }
        update_access_unlocked(key)
      end
    end

    # Remove a node from working memory
    #
    # @param key [String] Node identifier
    # @return [void]
    #
    def remove(key)
      @mutex.synchronize do
        @nodes.delete(key)
        @access_order.delete(key)
      end
    end

    # Check if there's space for a node
    #
    # @param token_count [Integer] Number of tokens needed
    # @return [Boolean] true if space available
    #
    def has_space?(token_count)
      @mutex.synchronize do
        current_tokens_unlocked + token_count <= @max_tokens
      end
    end

    # Evict nodes to make space
    #
    # Uses LFU + LRU strategy: Least Frequently Used + Least Recently Used
    # Nodes with low access count and old timestamps are evicted first
    #
    # @param needed_tokens [Integer] Number of tokens needed
    # @return [Array<Hash>] Evicted nodes
    #
    def evict_to_make_space(needed_tokens)
      @mutex.synchronize do
        evicted = []
        tokens_freed = 0

        # Sort by access frequency + recency (lower score = more evictable)
        candidates = @nodes.sort_by do |key, node|
          access_frequency = node[:access_count] || 0
          time_since_accessed = Time.now - (node[:last_accessed] || node[:added_at])

          # Combined score: lower is more evictable
          # Frequently accessed = higher score (keep)
          # Recently accessed = higher score (keep)
          access_score = Math.log(1 + access_frequency)
          recency_score = 1.0 / (1 + time_since_accessed / 3600.0)

          -(access_score + recency_score)  # Negative for ascending sort
        end

        candidates.each do |key, node|
          break if tokens_freed >= needed_tokens

          evicted << { key: key, value: node[:value] }
          tokens_freed += node[:token_count]
          @nodes.delete(key)
          @access_order.delete(key)
        end

        evicted
      end
    end

    # Assemble context string for LLM
    #
    # @param strategy [Symbol] Assembly strategy (:recent, :frequent, :balanced)
    #   - :recent - Most recently accessed (LRU)
    #   - :frequent - Most frequently accessed (LFU)
    #   - :balanced - Combines frequency × recency
    # @param max_tokens [Integer, nil] Optional token limit
    # @return [String] Assembled context
    #
    def assemble_context(strategy:, max_tokens: nil)
      @mutex.synchronize do
        max = max_tokens || @max_tokens

        # Make defensive copies of nodes to prevent external mutation of internal state
        nodes = case strategy
        when :recent
          # Most recently accessed (LRU)
          @access_order.reverse.map { |k| @nodes[k]&.dup }.compact
        when :frequent
          # Most frequently accessed (LFU)
          @nodes.sort_by { |k, v| -(v[:access_count] || 0) }.map { |_, v| v.dup }
        when :balanced
          # Combined frequency × recency
          @nodes.sort_by { |k, v|
            access_frequency = v[:access_count] || 0
            time_since_accessed = Time.now - (v[:last_accessed] || v[:added_at])
            recency_factor = 1.0 / (1 + time_since_accessed / 3600.0)

            # Higher score = more relevant
            -(Math.log(1 + access_frequency) * recency_factor)
          }.map { |_, v| v.dup }
        else
          raise ArgumentError, "Unknown strategy: #{strategy}. Use :recent, :frequent, or :balanced"
        end

        # Build context up to token limit
        context_parts = []
        current_tokens = 0

        nodes.each do |node|
          break if current_tokens + node[:token_count] > max
          context_parts << node[:value]
          current_tokens += node[:token_count]
        end

        context_parts.join("\n\n")
      end
    end

    # Get current token count
    #
    # @return [Integer] Total tokens in working memory
    #
    def token_count
      @mutex.synchronize do
        current_tokens_unlocked
      end
    end

    # Get utilization percentage
    #
    # @return [Float] Percentage of working memory used
    #
    def utilization_percentage
      @mutex.synchronize do
        (current_tokens_unlocked.to_f / @max_tokens * 100).round(2)
      end
    end

    # Get node count
    #
    # @return [Integer] Number of nodes in working memory
    #
    def node_count
      @mutex.synchronize do
        @nodes.size
      end
    end

    # Clear all nodes from working memory
    #
    # @return [void]
    #
    def clear
      @mutex.synchronize do
        @nodes.clear
        @access_order.clear
      end
    end

    # ===========================================================================
    # Sync Methods (for inter-robot coordination via LISTEN/NOTIFY)
    # ===========================================================================

    # Add a node from sync notification (bypasses normal add flow)
    #
    # Called by RobotGroup when another robot adds to working memory.
    # Does not trigger notifications to avoid infinite loops.
    #
    # @param id [Integer] Node database ID
    # @param content [String] Node content
    # @param token_count [Integer] Token count
    # @param created_at [Time] When node was created
    # @return [void]
    #
    def add_from_sync(id:, content:, token_count:, created_at:)
      @mutex.synchronize do
        key = id.to_s
        return if @nodes.key?(key)  # Already have this node

        @nodes[key] = {
          value: content,
          token_count: token_count,
          access_count: 0,
          last_accessed: Time.now,
          added_at: created_at,
          from_recall: false,
          from_sync: true
        }
        update_access_unlocked(key)
      end
    end

    # Remove a node from sync notification
    #
    # Called by RobotGroup when another robot evicts from working memory.
    #
    # @param node_id [Integer] Node database ID
    # @return [void]
    #
    def remove_from_sync(node_id)
      @mutex.synchronize do
        key = node_id.to_s
        @nodes.delete(key)
        @access_order.delete(key)
      end
    end

    # Clear all nodes from sync notification
    #
    # Called by RobotGroup when another robot clears working memory.
    #
    # @return [void]
    #
    def clear_from_sync
      @mutex.synchronize do
        @nodes.clear
        @access_order.clear
      end
    end

    private

    # Internal unlocked version - must be called within @mutex.synchronize
    def current_tokens_unlocked
      @nodes.values.sum { |n| n[:token_count] }
    end

    # Internal unlocked version - must be called within @mutex.synchronize
    def update_access_unlocked(key)
      @access_order.delete(key)
      @access_order << key
    end
  end
end
