# Class: HTM::LongTermMemory
**Inherits:** Object
    

Long-term Memory - PostgreSQL/TimescaleDB-backed permanent storage

LongTermMemory provides durable storage for all memory nodes with:
*   Vector similarity search (RAG)
*   Full-text search
*   Time-range queries
*   Relationship graphs
*   Tag system
*   ActiveRecord ORM for data access
*   Query result caching for efficiency


# Attributes
## query_timeout[RW] {: #attribute-i-query_timeout }
Returns the value of attribute query_timeout.


# Instance Methods
## add(content:, token_count:0, robot_id:, embedding:nil, metadata:{}) {: #method-i-add }
Add a node to long-term memory (with deduplication)

If content already exists (by content_hash), links the robot to the existing
node and updates timestamps. Otherwise creates a new node.

**`@param`** [String] Conversation message/utterance

**`@param`** [Integer] Token count

**`@param`** [Integer] Robot identifier

**`@param`** [Array<Float>, nil] Pre-generated embedding vector

**`@param`** [Hash] Flexible metadata for the node (default: {})

**`@return`** [Hash] { node_id:, is_new:, robot_node: }

## add_tag(node_id:, tag:) {: #method-i-add_tag }
Add a tag to a node

**`@param`** [Integer] Node database ID

**`@param`** [String] Tag name

**`@return`** [void] 

## batch_load_node_tags(node_ids) {: #method-i-batch_load_node_tags }
Batch load tags for multiple nodes (avoids N+1 queries)

**`@param`** [Array<Integer>] Node database IDs

**`@return`** [Hash<Integer, Array<String>>] Map of node_id to array of tag names

## calculate_relevance(node:, query_tags:[], vector_similarity:nil, node_tags:nil) {: #method-i-calculate_relevance }
Calculate dynamic relevance score for a node given query context

Combines multiple signals:
*   Vector similarity (semantic match)
*   Tag overlap (categorical match)
*   Recency (freshness)
*   Access frequency (popularity/utility)

**`@param`** [Hash] Node data with similarity, tags, created_at, access_count

**`@param`** [Array<String>] Tags associated with the query

**`@param`** [Float, nil] Pre-computed vector similarity (0-1)

**`@param`** [Array<String>, nil] Pre-loaded tags for this node (avoids N+1 query)

**`@return`** [Float] Composite relevance score (0-10)

## clear_cache!() {: #method-i-clear_cache! }
Clear the query cache

Call this after any operation that modifies data (soft delete, restore, etc.)
to ensure subsequent queries see fresh results.

**`@return`** [void] 

## delete(node_id) {: #method-i-delete }
Delete a node

**`@param`** [Integer] Node database ID

**`@return`** [void] 

## exists?(node_id) {: #method-i-exists? }
Check if a node exists

**`@param`** [Integer] Node database ID

**`@return`** [Boolean] True if node exists

## find_query_matching_tags(query, include_extracted:false) {: #method-i-find_query_matching_tags }
Find tags that match terms in the query

Searches the tags table for tags where any hierarchy level matches query
words. For example, query "PostgreSQL database" would match tags like
"database:postgresql", "database:sql", etc. Find tags matching a query using
semantic extraction

**`@param`** [String] Search query

**`@param`** [Boolean] If true, returns hash with :extracted and :matched keys

**`@return`** [Array<String>] Matching tag names (default)

**`@return`** [Hash] If include_extracted: { extracted: [...], matched: [...] }

## get_node_tags(node_id) {: #method-i-get_node_tags }
Get tags for a specific node

**`@param`** [Integer] Node database ID

**`@return`** [Array<String>] Tag names

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
## link_robot_to_node(robot_id:, node:, working_memory:false) {: #method-i-link_robot_to_node }
Link a robot to a node (create or update robot_node record)

**`@param`** [Integer] Robot ID

**`@param`** [HTM::Models::Node] Node to link

**`@param`** [Boolean] Whether node is in working memory (default: false)

**`@return`** [HTM::Models::RobotNode] The robot_node link record

## mark_evicted(robot_id:, node_ids:) {: #method-i-mark_evicted }
Mark nodes as evicted from working memory

Sets working_memory = false on the robot_nodes join table for the specified
robot and node IDs.

**`@param`** [Integer] Robot ID whose working memory is being evicted

**`@param`** [Array<Integer>] Node IDs to mark as evicted

**`@return`** [void] 

## node_topics(node_id) {: #method-i-node_topics }
Get topics for a specific node

**`@param`** [Integer] Node database ID

**`@return`** [Array<String>] Topic paths

## nodes_by_topic(topic_path, exact:false, limit:50) {: #method-i-nodes_by_topic }
Retrieve nodes by ontological topic

**`@param`** [String] Topic hierarchy path

**`@param`** [Boolean] Exact match or prefix match

**`@param`** [Integer] Maximum results

**`@return`** [Array<Hash>] Matching nodes

## ontology_structure() {: #method-i-ontology_structure }
Get ontology structure view

**`@return`** [Array<Hash>] Ontology structure

## pool_size() {: #method-i-pool_size }
For backwards compatibility with tests/code that expect pool_size

## popular_tags(limit:20, timeframe:nil) {: #method-i-popular_tags }
Get most popular tags

**`@param`** [Integer] Number of tags to return

**`@param`** [Range, nil] Optional time range filter

**`@return`** [Array<Hash>] Tags with usage counts

## register_robot(robot_name) {: #method-i-register_robot }
Register a robot

**`@param`** [String] Robot identifier

**`@param`** [String] Robot name

**`@return`** [void] 

## retrieve(node_id) {: #method-i-retrieve }
Retrieve a node by ID

Automatically tracks access by incrementing access_count and updating
last_accessed

**`@param`** [Integer] Node database ID

**`@return`** [Hash, nil] Node data or nil

## search(timeframe:, query:, limit:, embedding_service:, metadata:{}) {: #method-i-search }
Vector similarity search

**`@param`** [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)

**`@param`** [String] Search query

**`@param`** [Integer] Maximum results

**`@param`** [Object] Service to generate embeddings

**`@param`** [Hash] Filter by metadata fields (default: {})

**`@return`** [Array<Hash>] Matching nodes

## search_by_tags(tags:, match_all:false, timeframe:nil, limit:20) {: #method-i-search_by_tags }
Search nodes by tags

**`@param`** [Array<String>] Tags to search for

**`@param`** [Boolean] If true, match ALL tags; if false, match ANY tag

**`@param`** [Range, nil] Optional time range filter

**`@param`** [Integer] Maximum results

**`@return`** [Array<Hash>] Matching nodes with relevance scores

## search_fulltext(timeframe:, query:, limit:, metadata:{}) {: #method-i-search_fulltext }
Full-text search

**`@param`** [Range] Time range to search

**`@param`** [String] Search query

**`@param`** [Integer] Maximum results

**`@param`** [Hash] Filter by metadata fields (default: {})

**`@return`** [Array<Hash>] Matching nodes

## search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit:100, metadata:{}) {: #method-i-search_hybrid }
Hybrid search (full-text + vector)

**`@param`** [Range] Time range to search

**`@param`** [String] Search query

**`@param`** [Integer] Maximum results

**`@param`** [Object] Service to generate embeddings

**`@param`** [Integer] Candidates to consider (default: 100)

**`@param`** [Hash] Filter by metadata fields (default: {})

**`@return`** [Array<Hash>] Matching nodes

## search_with_relevance(timeframe:, query:nil, query_tags:[], limit:20, embedding_service:nil, metadata:{}) {: #method-i-search_with_relevance }
Search with dynamic relevance scoring

Returns nodes with calculated relevance scores based on query context

**`@param`** [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)

**`@param`** [String, nil] Search query

**`@param`** [Array<String>] Tags to match

**`@param`** [Integer] Maximum results

**`@param`** [Object, nil] Service to generate embeddings

**`@param`** [Hash] Filter by metadata fields (default: {})

**`@return`** [Array<Hash>] Nodes with relevance scores

## shutdown() {: #method-i-shutdown }
Shutdown - no-op with ActiveRecord (connection pool managed by ActiveRecord)

## stats() {: #method-i-stats }
Get memory statistics

**`@return`** [Hash] Statistics

## topic_relationships(min_shared_nodes:2, limit:50) {: #method-i-topic_relationships }
Get topic relationships (co-occurrence)

**`@param`** [Integer] Minimum shared nodes

**`@param`** [Integer] Maximum relationships

**`@return`** [Array<Hash>] Topic relationships

## track_access(node_ids) {: #method-i-track_access }
Track access for multiple nodes (bulk operation)

Updates access_count and last_accessed for all nodes in the array

**`@param`** [Array<Integer>] Node IDs that were accessed

**`@return`** [void] 

## update_last_accessed(node_id) {: #method-i-update_last_accessed }
Update last_accessed timestamp

**`@param`** [Integer] Node database ID

**`@return`** [void] 

## update_robot_activity(robot_id) {: #method-i-update_robot_activity }
Update robot activity timestamp

**`@param`** [String] Robot identifier

**`@return`** [void] 

