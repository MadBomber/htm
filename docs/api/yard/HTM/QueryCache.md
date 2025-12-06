# Class: HTM::QueryCache
**Inherits:** Object
    

Thread-safe query result cache with TTL and statistics

Provides LRU caching for expensive query results with:
*   Configurable size and TTL
*   Thread-safe statistics tracking
*   Fast cache key generation (using Ruby's built-in hash)
*   Selective cache invalidation by method type


**`@example`**
```ruby
cache = HTM::QueryCache.new(size: 1000, ttl: 300)
```
**`@example`**
```ruby
result = cache.fetch(:search, timeframe, query, limit) do
  expensive_search_operation
end
```
**`@example`**
```ruby
cache.stats
# => { hits: 42, misses: 10, hit_rate: 80.77, size: 52 }
```
**`@example`**
```ruby
cache.invalidate_methods!(:search, :hybrid)  # Only invalidate search-related entries
```
# Attributes
## enabled[RW] {: #attribute-i-enabled }
Returns the value of attribute enabled.


# Instance Methods
## clear!() {: #method-i-clear! }
Clear all cached entries

**`@return`** [void] 

## enabled?() {: #method-i-enabled? }
Check if cache is enabled

**`@return`** [Boolean] 

## fetch(method, *args, &block) {: #method-i-fetch }
Fetch a value from cache or execute block

**`@param`** [Symbol] Method name for cache key

**`@param`** [Array] Arguments for cache key

**`@return`** [Object] Cached or computed value

**`@yield`** [] Block that computes the value if not cached

## initialize(size:1000, ttl:300) {: #method-i-initialize }
Initialize a new query cache

**`@param`** [Integer] Maximum number of entries (default: 1000, use 0 to disable)

**`@param`** [Integer] Time-to-live in seconds (default: 300)

**`@return`** [QueryCache] a new instance of QueryCache

## invalidate!() {: #method-i-invalidate! }
Invalidate cache (alias for clear!)

**`@return`** [void] 

## invalidate_methods!(*methods) {: #method-i-invalidate_methods! }
Invalidate cache entries for specific methods only

More efficient than full invalidation when only certain types of cached data
need to be refreshed.

**`@param`** [Array<Symbol>] Method names to invalidate

**`@return`** [Integer] Number of entries invalidated

## stats() {: #method-i-stats }
Get cache statistics

**`@return`** [Hash, nil] Statistics hash or nil if disabled

