# frozen_string_literal: true

require 'lru_redux'
require 'set'

class HTM
  # Thread-safe query result cache with TTL and statistics
  #
  # Provides LRU caching for expensive query results with:
  # - Configurable size and TTL
  # - Thread-safe statistics tracking
  # - Fast cache key generation (using Ruby's built-in hash)
  # - Selective cache invalidation by method type
  #
  # @example Create a cache
  #   cache = HTM::QueryCache.new(size: 1000, ttl: 300)
  #
  # @example Use the cache
  #   result = cache.fetch(:search, timeframe, query, limit) do
  #     expensive_search_operation
  #   end
  #
  # @example Check statistics
  #   cache.stats
  #   # => { hits: 42, misses: 10, hit_rate: 80.77, size: 52 }
  #
  # @example Selective invalidation
  #   cache.invalidate_methods!(:search, :hybrid)  # Only invalidate search-related entries
  #
  class QueryCache
    attr_reader :enabled

    # Cache key prefix for method-based invalidation
    METHOD_PREFIX = "m:".freeze

    # Initialize a new query cache
    #
    # @param size [Integer] Maximum number of entries (default: 1000, use 0 to disable)
    # @param ttl [Integer] Time-to-live in seconds (default: 300)
    #
    def initialize(size: 1000, ttl: 300)
      @enabled = size > 0

      if @enabled
        @cache = LruRedux::TTL::ThreadSafeCache.new(size, ttl)
        @hits = 0
        @misses = 0
        @mutex = Mutex.new
        # Track keys by method for selective invalidation
        @keys_by_method = Hash.new { |h, k| h[k] = Set.new }
      end
    end

    # Fetch a value from cache or execute block
    #
    # @param method [Symbol] Method name for cache key
    # @param args [Array] Arguments for cache key
    # @yield Block that computes the value if not cached
    # @return [Object] Cached or computed value
    #
    def fetch(method, *args, &block)
      return yield unless @enabled

      key = cache_key(method, *args)

      if (cached = @cache[key])
        @mutex.synchronize { @hits += 1 }
        return cached
      end

      @mutex.synchronize { @misses += 1 }
      result = yield
      @cache[key] = result

      # Track key for selective invalidation
      @mutex.synchronize { @keys_by_method[method] << key }

      result
    end

    # Clear all cached entries
    #
    # @return [void]
    #
    def clear!
      return unless @enabled

      @cache.clear
      @mutex.synchronize { @keys_by_method.clear }
    end

    # Invalidate cache (alias for clear!)
    #
    # @return [void]
    #
    def invalidate!
      clear!
    end

    # Invalidate cache entries for specific methods only
    #
    # More efficient than full invalidation when only certain
    # types of cached data need to be refreshed.
    #
    # @param methods [Array<Symbol>] Method names to invalidate
    # @return [Integer] Number of entries invalidated
    #
    def invalidate_methods!(*methods)
      return 0 unless @enabled

      count = 0
      @mutex.synchronize do
        methods.each do |method|
          keys = @keys_by_method.delete(method) || Set.new
          keys.each do |key|
            @cache.delete(key)
            count += 1
          end
        end
      end
      count
    end

    # Get cache statistics
    #
    # @return [Hash, nil] Statistics hash or nil if disabled
    #
    def stats
      return nil unless @enabled

      total = @hits + @misses
      hit_rate = total > 0 ? (@hits.to_f / total * 100).round(2) : 0.0

      {
        hits: @hits,
        misses: @misses,
        hit_rate: hit_rate,
        size: @cache.count
      }
    end

    # Check if cache is enabled
    #
    # @return [Boolean]
    #
    def enabled?
      @enabled
    end

    private

    # Generate a cache key from method and arguments
    #
    # Uses Ruby's built-in hash method which is much faster than SHA-256.
    # The combination of method name and argument hash provides sufficient
    # uniqueness for cache keys while being ~10x faster than cryptographic hashing.
    #
    # @param method [Symbol] Method name
    # @param args [Array] Arguments
    # @return [String] Hash-based key
    #
    def cache_key(method, *args)
      # Build composite hash from all arguments
      args_hash = args.map { |arg| normalize_arg(arg) }.hash
      # Combine method and args into a single key
      "#{method}:#{args_hash}"
    end

    # Normalize an argument for cache key generation
    #
    # Uses type-safe serialization to prevent cache poisoning via malicious to_s.
    # Only known safe types are serialized; unknown types include class name.
    #
    # @param arg [Object] Argument to normalize
    # @return [String] Normalized string representation
    #
    def normalize_arg(arg)
      case arg
      when nil
        "nil"
      when Integer, Float
        # Safe numeric types
        "#{arg.class}:#{arg}"
      when String
        # Include class to differentiate from symbols
        "String:#{arg}"
      when Symbol
        "Symbol:#{arg}"
      when TrueClass, FalseClass
        "Bool:#{arg}"
      when Time, DateTime
        # Use ISO8601 for consistent time representation
        "Time:#{arg.to_i}"
      when Date
        "Date:#{arg.iso8601}"
      when Range
        # Use normalized form for range endpoints
        "Range:#{normalize_arg(arg.begin)}-#{normalize_arg(arg.end)}"
      when Array
        # Recursively normalize array elements
        "Array:[#{arg.map { |a| normalize_arg(a) }.join(',')}]"
      when Hash
        # Sort keys for deterministic ordering, recursively normalize values
        "Hash:{#{arg.sort_by { |k, _| k.to_s }.map { |k, v| "#{normalize_arg(k)}=>#{normalize_arg(v)}" }.join(',')}}"
      else
        # Unknown types: use class name and object_id to prevent collision
        # Don't rely on to_s which could be maliciously overridden
        "#{arg.class}##{arg.object_id}"
      end
    end
  end
end
