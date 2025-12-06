# Class: HTM::LongTermMemory
**Inherits:** Object
    
**Includes:** FulltextSearch, HybridSearch, NodeOperations, RelevanceScorer, RobotOperations, TagOperations, VectorSearch
  

Long-term Memory - PostgreSQL/TimescaleDB-backed permanent storage

LongTermMemory provides durable storage for all memory nodes with:
*   Vector similarity search (RAG)
*   Full-text search
*   Time-range queries
*   Relationship graphs
*   Tag system
*   ActiveRecord ORM for data access
*   Query result caching for efficiency

This class uses standalone utility classes and modules:

Standalone classes (used via class methods or instances):
*   HTM::SqlBuilder: SQL condition building helpers (class methods)
*   HTM::QueryCache: Query result caching (instantiated as @cache)

Included modules:
*   RelevanceScorer: Dynamic relevance scoring
*   NodeOperations: Node CRUD operations
*   RobotOperations: Robot registration and activity
*   TagOperations: Tag management
*   VectorSearch: Vector similarity search
*   FulltextSearch: Full-text search
*   HybridSearch: Combined search strategies


# Attributes
## query_timeout[RW] {: #attribute-i-query_timeout }
Returns the value of attribute query_timeout.


# Instance Methods
## clear_cache!() {: #method-i-clear_cache! }
Clear the query result cache

**`@return`** [void] 

## initialize(config, pool_size:nil, query_timeout:DEFAULT_QUERY_TIMEOUT, cache_size:DEFAULT_CACHE_SIZE, cache_ttl:DEFAULT_CACHE_TTL) {: #method-i-initialize }
Initialize long-term memory storage

**`@param`** [Hash] Database configuration (host, port, dbname, user, password)

**`@param`** [Integer, nil] Connection pool size (uses ActiveRecord default if nil)

**`@param`** [Integer] Query timeout in milliseconds (default: 30000)

**`@param`** [Integer] Number of query results to cache (default: 1000, use 0 to disable)

**`@param`** [Integer] Cache time-to-live in seconds (default: 300)

**`@return`** [LongTermMemory] a new instance of LongTermMemory


**`@example`**
```ruby
ltm = LongTermMemory.new(HTM::Database.default_config)
```
**`@example`**
```ruby
ltm = LongTermMemory.new(config, cache_size: 500, cache_ttl: 600)
```
**`@example`**
```ruby
ltm = LongTermMemory.new(config, cache_size: 0)
```
## pool_size() {: #method-i-pool_size }
For backwards compatibility with tests/code that expect pool_size

## shutdown() {: #method-i-shutdown }
Shutdown - no-op with ActiveRecord (connection pool managed by ActiveRecord)

## stats() {: #method-i-stats }
Get memory statistics

**`@return`** [Hash] Statistics

