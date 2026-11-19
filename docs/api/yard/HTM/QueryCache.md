# Class HTM::QueryCache <a id="class-HTM-QueryCache"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/query_cache.rb |

Thread-safe query result cache with TTL and statistics

Provides LRU caching for expensive query results with:
*   Configurable size and TTL
*   Thread-safe statistics tracking
*   Fast cache key generation (using Ruby's built-in hash)
*   Selective cache invalidation by method type

**@example Create a cache**
```ruby
cache = HTM::QueryCache.new(size: 1000, ttl: 300)
```

**@example Use the cache**
```ruby
result = cache.fetch(:search, timeframe, query, limit) do
  expensive_search_operation
end
```

**@example Check statistics**
```ruby
cache.stats
# => { hits: 42, misses: 10, hit_rate: 80.77, size: 52 }
```

**@example Selective invalidation**
```ruby
cache.invalidate_methods!(:search, :hybrid)  # Only invalidate search-related entries
```

## Constants
### `METHOD_PREFIX` <a id="constant-METHOD_PREFIX"></a> <a id="METHOD_PREFIX-constant"></a>
Cache key prefix for method-based invalidation

## Attributes
### `enabled` [R] <a id="attribute-i-enabled"></a> <a id="enabled-instance_method"></a>
Returns the value of attribute enabled.

## Public Instance Methods
### `clear!()` <a id="method-i-clear-21"></a> <a id="clear!-instance_method"></a>
Clear all cached entries
- **`@return`** [void]

### `enabled?()` <a id="method-i-enabled-3F"></a> <a id="enabled?-instance_method"></a>
Check if cache is enabled
- **`@return`** [Boolean]

### `fetch(method)` <a id="method-i-fetch"></a> <a id="fetch-instance_method"></a>
Fetch a value from cache or execute block
- **`@param`** `method` [Symbol] Method name for cache key
- **`@param`** `args` [Array] Arguments for cache key
- **`@return`** [Object] Cached or computed value
- **`@yield`** Block that computes the value if not cached

### `initialize(size: 1000, ttl: 300)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Initialize a new query cache
- **`@param`** `size` [Integer] Maximum number of entries (default: 1000, use 0 to disable)
- **`@param`** `ttl` [Integer] Time-to-live in seconds (default: 300)
- **`@return`** [QueryCache] a new instance of QueryCache

### `invalidate!()` <a id="method-i-invalidate-21"></a> <a id="invalidate!-instance_method"></a>
Invalidate cache (alias for clear!)
- **`@return`** [void]

### `invalidate_methods!(*methods)` <a id="method-i-invalidate_methods-21"></a> <a id="invalidate_methods!-instance_method"></a>
Invalidate cache entries for specific methods only

More efficient than full invalidation when only certain types of cached data
need to be refreshed.
- **`@param`** `methods` [Array<Symbol>] Method names to invalidate
- **`@return`** [Integer] Number of entries invalidated

### `stats()` <a id="method-i-stats"></a> <a id="stats-instance_method"></a>
Get cache statistics
- **`@return`** [Hash, nil] Statistics hash or nil if disabled
