# Class HTM::LongTermMemory <a id="class-HTM-LongTermMemory"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Includes** | [HTM::LongTermMemory::FulltextSearch](LongTermMemory/FulltextSearch.md), [HTM::LongTermMemory::HybridSearch](LongTermMemory/HybridSearch.md), [HTM::LongTermMemory::NodeOperations](LongTermMemory/NodeOperations.md), [HTM::LongTermMemory::RelevanceScorer](LongTermMemory/RelevanceScorer.md), [HTM::LongTermMemory::RobotOperations](LongTermMemory/RobotOperations.md), [HTM::LongTermMemory::TagOperations](LongTermMemory/TagOperations.md), [HTM::LongTermMemory::VectorSearch](LongTermMemory/VectorSearch.md) |
| **Defined in** | lib/htm/long_term_memory.rb, lib/htm/long_term_memory/hybrid_search.rb, lib/htm/long_term_memory/vector_search.rb, lib/htm/long_term_memory/tag_operations.rb, lib/htm/long_term_memory/fulltext_search.rb, lib/htm/long_term_memory/node_operations.rb, lib/htm/long_term_memory/relevance_scorer.rb, lib/htm/long_term_memory/robot_operations.rb |

Long-term Memory - PostgreSQL-backed permanent storage

LongTermMemory provides durable storage for all memory nodes with:
*   Vector similarity search (RAG)
*   Full-text search
*   Time-range queries
*   Relationship graphs
*   Tag system
*   Sequel ORM for data access
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

## Constants
### `DEFAULT_CACHE_SIZE` <a id="constant-DEFAULT_CACHE_SIZE"></a> <a id="DEFAULT_CACHE_SIZE-constant"></a>
Number of queries to cache

### `DEFAULT_CACHE_TTL` <a id="constant-DEFAULT_CACHE_TTL"></a> <a id="DEFAULT_CACHE_TTL-constant"></a>
Cache lifetime in seconds (5 minutes)

### `DEFAULT_QUERY_TIMEOUT` <a id="constant-DEFAULT_QUERY_TIMEOUT"></a> <a id="DEFAULT_QUERY_TIMEOUT-constant"></a>
milliseconds (30 seconds)

### `MAX_VECTOR_DIMENSION` <a id="constant-MAX_VECTOR_DIMENSION"></a> <a id="MAX_VECTOR_DIMENSION-constant"></a>
Maximum supported dimension with HNSW index (pgvector limitation)

## Attributes
### `query_timeout` [R] <a id="attribute-i-query_timeout"></a> <a id="query_timeout-instance_method"></a>
Returns the value of attribute query_timeout.

## Public Instance Methods
### `add(content:, robot_id:, token_count: 0, embedding: nil, metadata: {})` <a id="method-i-add"></a> <a id="add-instance_method"></a>
Add a node to long-term memory (with deduplication)

If content already exists (by content_hash), links the robot to the existing
node and updates timestamps. Otherwise creates a new node.
- **`@param`** `content` [String] Conversation message/utterance
- **`@param`** `token_count` [Integer] Token count
- **`@param`** `robot_id` [Integer] Robot identifier
- **`@param`** `embedding` [Array<Float>, nil] Pre-generated embedding vector
- **`@param`** `metadata` [Hash] Flexible metadata for the node (default: {})
- **`@raise`** [ArgumentError] If metadata is not a Hash
- **`@return`** [Hash] { node_id:, is_new:, robot_node: }

### `add_tag(node_id:, tag:)` <a id="method-i-add_tag"></a> <a id="add_tag-instance_method"></a>
Add a tag to a node (creates tag and all parent tags)

When adding a hierarchical tag like "database:postgresql:extensions", this
also creates and associates the parent tags "database" and
"database:postgresql" with the node.
- **`@param`** `node_id` [Integer] Node database ID
- **`@param`** `tag` [String] Tag name
- **`@return`** [void]

**`@example`**
```ruby
add_tag(node_id: 123, tag: "database:postgresql:extensions")
# Creates tags: "database", "database:postgresql", "database:postgresql:extensions"
# Associates all three with node 123
```

### `batch_load_node_tags(node_ids)` <a id="method-i-batch_load_node_tags"></a> <a id="batch_load_node_tags-instance_method"></a>
Batch load tags for multiple nodes (avoids N+1 queries)
- **`@param`** `node_ids` [Array<Integer>] Node database IDs
- **`@return`** [Hash<Integer, Array<String>>] Map of node_id to array of tag names

### `calculate_relevance(node:, query_tags: [], vector_similarity: nil, node_tags: nil)` <a id="method-i-calculate_relevance"></a> <a id="calculate_relevance-instance_method"></a>
Calculate dynamic relevance score for a node given query context
- **`@param`** `node` [Hash] Node data with similarity, tags, created_at, access_count
- **`@param`** `query_tags` [Array<String>] Tags associated with the query
- **`@param`** `vector_similarity` [Float, nil] Pre-computed vector similarity (0-1)
- **`@param`** `node_tags` [Array<String>, nil] Pre-loaded tags for this node (avoids N+1 query)
- **`@return`** [Float] Composite relevance score (RELEVANCE_MIN to RELEVANCE_MAX)

### `clear_cache!()` <a id="method-i-clear_cache-21"></a> <a id="clear_cache!-instance_method"></a>
Clear the query result cache
- **`@return`** [void]

### `delete(node_id)` <a id="method-i-delete"></a> <a id="delete-instance_method"></a>
Delete a node
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [void]

### `exists?(node_id)` <a id="method-i-exists-3F"></a> <a id="exists?-instance_method"></a>
Check if a node exists
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [Boolean] True if node exists

### `fetch_candidates_by_timeframe(timeframe:, metadata:, limit:)` <a id="method-i-fetch_candidates_by_timeframe"></a> <a id="fetch_candidates_by_timeframe-instance_method"></a>
Fetch candidates by timeframe using raw SQL (avoids ORM overhead)
- **`@param`** `timeframe` [nil, Range, Array<Range>] Time range(s) to search
- **`@param`** `metadata` [Hash] Filter by metadata fields
- **`@param`** `limit` [Integer] Maximum results
- **`@return`** [Array<Hash>] Candidate nodes as hashes

### `find_query_matching_tags(query, include_extracted: false)` <a id="method-i-find_query_matching_tags"></a> <a id="find_query_matching_tags-instance_method"></a>
Find tags that match terms in the query

Searches the tags table for tags where any hierarchy level matches query
words. Uses semantic extraction via LLM to find relevant tags.

Performance: Uses a single UNION query instead of multiple sequential queries.
- **`@param`** `query` [String] Search query
- **`@param`** `include_extracted` [Boolean] If true, returns hash with :extracted and :matched keys
- **`@return`** [Array<String>] Matching tag names (default)
- **`@return`** [Hash] If include_extracted: { extracted: [...], matched: [...] }

### `get_node_tags(node_id)` <a id="method-i-get_node_tags"></a> <a id="get_node_tags-instance_method"></a>
Get tags for a specific node
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [Array<String>] Tag names

### `initialize(config, pool_size: nil, query_timeout: DEFAULT_QUERY_TIMEOUT, cache_size: DEFAULT_CACHE_SIZE, cache_ttl: DEFAULT_CACHE_TTL)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Initialize long-term memory storage
- **`@param`** `config` [Hash] Database configuration (host, port, dbname, user, password)
- **`@param`** `pool_size` [Integer, nil] Connection pool size (uses Sequel default if nil)
- **`@param`** `query_timeout` [Integer] Query timeout in milliseconds (default: 30000)
- **`@param`** `cache_size` [Integer] Number of query results to cache (default: 1000, use 0 to disable)
- **`@param`** `cache_ttl` [Integer] Cache time-to-live in seconds (default: 300)
- **`@return`** [LongTermMemory] a new instance of LongTermMemory

**@example Initialize with defaults**
```ruby
ltm = LongTermMemory.new(HTM::Database.default_config)
```

**@example Initialize with custom cache settings**
```ruby
ltm = LongTermMemory.new(config, cache_size: 500, cache_ttl: 600)
```

**@example Disable caching**
```ruby
ltm = LongTermMemory.new(config, cache_size: 0)
```

### `link_robot_to_node(robot_id:, node:, working_memory: false)` <a id="method-i-link_robot_to_node"></a> <a id="link_robot_to_node-instance_method"></a>
Link a robot to a node (create or update robot_node record)
- **`@param`** `robot_id` [Integer] Robot ID
- **`@param`** `node` [HTM::Models::Node] Node to link
- **`@param`** `working_memory` [Boolean] Whether node is in working memory (default: false)
- **`@return`** [HTM::Models::RobotNode] The robot_node link record

### `mark_evicted(robot_id:, node_ids:)` <a id="method-i-mark_evicted"></a> <a id="mark_evicted-instance_method"></a>
Mark nodes as evicted from working memory

Sets working_memory = false on the robot_nodes join table for the specified
robot and node IDs.
- **`@param`** `robot_id` [Integer] Robot ID whose working memory is being evicted
- **`@param`** `node_ids` [Array<Integer>] Node IDs to mark as evicted
- **`@return`** [void]

### `node_topics(node_id)` <a id="method-i-node_topics"></a> <a id="node_topics-instance_method"></a>
Get topics for a specific node
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [Array<String>] Topic paths

### `nodes_by_topic(topic_path, exact: false, fuzzy: false, min_similarity: DEFAULT_TAG_SIMILARITY_THRESHOLD, limit: 50)` <a id="method-i-nodes_by_topic"></a> <a id="nodes_by_topic-instance_method"></a>
Retrieve nodes by ontological topic

Matching modes (in order of precedence):
*   exact: true - Only exact tag name match
*   fuzzy: true - Trigram similarity search (typo-tolerant)
*   default - LIKE prefix match (e.g., "database" matches
    "database:postgresql")
- **`@param`** `topic_path` [String] Topic hierarchy path
- **`@param`** `exact` [Boolean] Exact match only (highest priority)
- **`@param`** `fuzzy` [Boolean] Use trigram similarity for typo-tolerant search
- **`@param`** `min_similarity` [Float] Minimum similarity for fuzzy mode (0.0-1.0)
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_TAG_QUERY_LIMIT)
- **`@return`** [Array<Hash>] Matching nodes

### `ontology_structure()` <a id="method-i-ontology_structure"></a> <a id="ontology_structure-instance_method"></a>
Get ontology structure view
- **`@return`** [Array<Hash>] Ontology structure

### `pool_size()` <a id="method-i-pool_size"></a> <a id="pool_size-instance_method"></a>
For backwards compatibility with tests/code that expect pool_size

### `popular_tags(limit: 20, timeframe: nil)` <a id="method-i-popular_tags"></a> <a id="popular_tags-instance_method"></a>
Get most popular tags
- **`@param`** `limit` [Integer] Number of tags to return (capped at MAX_TAG_QUERY_LIMIT)
- **`@param`** `timeframe` [Range, nil] Optional time range filter
- **`@return`** [Array<Hash>] Tags with usage counts

### `recency_half_life_hours()` <a id="method-i-recency_half_life_hours"></a> <a id="recency_half_life_hours-instance_method"></a>
Not documented.

### `register_robot(robot_name)` <a id="method-i-register_robot"></a> <a id="register_robot-instance_method"></a>
Register a robot
- **`@param`** `robot_name` [String] Robot name
- **`@return`** [Integer] Robot ID

### `retrieve(node_id)` <a id="method-i-retrieve"></a> <a id="retrieve-instance_method"></a>
Retrieve a node by ID

Automatically tracks access by incrementing access_count and updating
last_accessed. Uses a single UPDATE query instead of separate increment! and
touch calls.
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [Hash, nil] Node data or nil

### `search(timeframe:, query:, limit:, embedding_service:, metadata: {})` <a id="method-i-search"></a> <a id="search-instance_method"></a>
Vector similarity search
- **`@param`** `timeframe` [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
- **`@param`** `query` [String] Search query
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_VECTOR_LIMIT)
- **`@param`** `embedding_service` [Object] Service to generate embeddings
- **`@param`** `metadata` [Hash] Filter by metadata fields (default: {})
- **`@return`** [Array<Hash>] Matching nodes

### `search_by_tags(tags:, match_all: false, timeframe: nil, limit: 20)` <a id="method-i-search_by_tags"></a> <a id="search_by_tags-instance_method"></a>
Search nodes by tags
- **`@param`** `tags` [Array<String>] Tags to search for
- **`@param`** `match_all` [Boolean] If true, match ALL tags; if false, match ANY tag
- **`@param`** `timeframe` [Range, nil] Optional time range filter
- **`@param`** `limit` [Integer] Maximum results
- **`@return`** [Array<Hash>] Matching nodes with relevance scores

### `search_fulltext(timeframe:, query:, limit:, metadata: {})` <a id="method-i-search_fulltext"></a> <a id="search_fulltext-instance_method"></a>
Full-text search
- **`@param`** `timeframe` [Range] Time range to search
- **`@param`** `query` [String] Search query
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_FULLTEXT_LIMIT)
- **`@param`** `metadata` [Hash] Filter by metadata fields (default: {})
- **`@return`** [Array<Hash>] Matching nodes

### `search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit: 100, metadata: {})` <a id="method-i-search_hybrid"></a> <a id="search_hybrid-instance_method"></a>
Hybrid search using Reciprocal Rank Fusion
- **`@param`** `timeframe` [Range] Time range to search
- **`@param`** `query` [String] Search query
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_HYBRID_LIMIT)
- **`@param`** `embedding_service` [Object] Service to generate embeddings
- **`@param`** `prefilter_limit` [Integer] Candidates per search (default: 100)
- **`@param`** `metadata` [Hash] Filter by metadata fields (default: {})
- **`@return`** [Array<Hash>] Matching nodes

### `search_tags(query, limit: 20, min_similarity: DEFAULT_TAG_SIMILARITY_THRESHOLD)` <a id="method-i-search_tags"></a> <a id="search_tags-instance_method"></a>
Fuzzy search for tags using trigram similarity

Uses PostgreSQL pg_trgm extension to find tags that are similar to the query
string, tolerating typos and partial matches.
- **`@param`** `query` [String] Search query (tag name or partial)
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_TAG_QUERY_LIMIT)
- **`@param`** `min_similarity` [Float] Minimum similarity threshold (0.0-1.0)
- **`@return`** [Array<Hash>] Matching tags with similarity scores
Each hash contains: { name: String, similarity: Float }

### `search_with_relevance(timeframe:, query: nil, query_tags: [], limit: 20, embedding_service: nil, metadata: {})` <a id="method-i-search_with_relevance"></a> <a id="search_with_relevance-instance_method"></a>
Search with dynamic relevance scoring

Returns nodes with calculated relevance scores based on query context
- **`@param`** `timeframe` [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
- **`@param`** `query` [String, nil] Search query
- **`@param`** `query_tags` [Array<String>] Tags to match
- **`@param`** `limit` [Integer] Maximum results
- **`@param`** `embedding_service` [Object, nil] Service to generate embeddings
- **`@param`** `metadata` [Hash] Filter by metadata fields (default: {})
- **`@return`** [Array<Hash>] Nodes with relevance scores

### `shutdown()` <a id="method-i-shutdown"></a> <a id="shutdown-instance_method"></a>
Shutdown - no-op with Sequel (connection pool managed by Sequel)

### `stats()` <a id="method-i-stats"></a> <a id="stats-instance_method"></a>
Get memory statistics
- **`@return`** [Hash] Statistics

### `topic_relationships(min_shared_nodes: 2, limit: 50)` <a id="method-i-topic_relationships"></a> <a id="topic_relationships-instance_method"></a>
Get topic relationships (co-occurrence)
- **`@param`** `min_shared_nodes` [Integer] Minimum shared nodes
- **`@param`** `limit` [Integer] Maximum relationships (capped at MAX_TAG_QUERY_LIMIT)
- **`@return`** [Array<Hash>] Topic relationships

### `track_access(node_ids)` <a id="method-i-track_access"></a> <a id="track_access-instance_method"></a>
Track access for multiple nodes (bulk operation)

Updates access_count and last_accessed for all nodes in the array
- **`@param`** `node_ids` [Array<Integer>] Node IDs that were accessed
- **`@return`** [void]

### `update_last_accessed(node_id)` <a id="method-i-update_last_accessed"></a> <a id="update_last_accessed-instance_method"></a>
Update last_accessed timestamp
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [void]

### `update_robot_activity(robot_id)` <a id="method-i-update_robot_activity"></a> <a id="update_robot_activity-instance_method"></a>
Update robot activity timestamp
- **`@param`** `robot_id` [Integer] Robot identifier
- **`@return`** [void]

### `weight_access()` <a id="method-i-weight_access"></a> <a id="weight_access-instance_method"></a>
Not documented.

### `weight_recency()` <a id="method-i-weight_recency"></a> <a id="weight_recency-instance_method"></a>
Not documented.

### `weight_semantic()` <a id="method-i-weight_semantic"></a> <a id="weight_semantic-instance_method"></a>
Configurable scoring weights (via HTM.configuration)

### `weight_tag()` <a id="method-i-weight_tag"></a> <a id="weight_tag-instance_method"></a>
Not documented.
