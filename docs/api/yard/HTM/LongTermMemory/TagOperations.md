# Module HTM::LongTermMemory::TagOperations <a id="module-HTM-LongTermMemory-TagOperations"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/long_term_memory/tag_operations.rb |

Tag management operations for LongTermMemory

Handles hierarchical tag operations including:
*   Adding tags to nodes
*   Querying nodes by topic/tag
*   Tag relationship analysis
*   Batch tag loading (N+1 prevention)
*   Query-to-tag matching

Security: All queries use parameterized placeholders and LIKE patterns are
sanitized to prevent SQL injection.

## Constants
### `DEFAULT_TAG_SIMILARITY_THRESHOLD` <a id="constant-DEFAULT_TAG_SIMILARITY_THRESHOLD"></a> <a id="DEFAULT_TAG_SIMILARITY_THRESHOLD-constant"></a>
Default trigram similarity threshold for fuzzy tag search (0.0-1.0) Lower =
more fuzzy matches, higher = stricter matching

### `MAX_TAG_QUERY_LIMIT` <a id="constant-MAX_TAG_QUERY_LIMIT"></a> <a id="MAX_TAG_QUERY_LIMIT-constant"></a>
Maximum results to prevent DoS via unbounded queries

### `MAX_TAG_SAMPLE_SIZE` <a id="constant-MAX_TAG_SAMPLE_SIZE"></a> <a id="MAX_TAG_SAMPLE_SIZE-constant"></a>
Not documented.

### `POPULAR_TAGS_CACHE_TTL` <a id="constant-POPULAR_TAGS_CACHE_TTL"></a> <a id="POPULAR_TAGS_CACHE_TTL-constant"></a>
Cache TTL for popular tags (5 minutes) This eliminates expensive RANDOM()
queries on every tag extraction

## Attributes
### `popular_tags_cache` [RW] <a id="attribute-c-popular_tags_cache"></a> <a id="popular_tags_cache-class_method"></a>
Returns the value of attribute popular_tags_cache.

### `popular_tags_cache_expires_at` [RW] <a id="attribute-c-popular_tags_cache_expires_at"></a> <a id="popular_tags_cache_expires_at-class_method"></a>
Returns the value of attribute popular_tags_cache_expires_at.

### `popular_tags_mutex` [RW] <a id="attribute-c-popular_tags_mutex"></a> <a id="popular_tags_mutex-class_method"></a>
Returns the value of attribute popular_tags_mutex.

## Public Instance Methods
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

### `popular_tags(limit: 20, timeframe: nil)` <a id="method-i-popular_tags"></a> <a id="popular_tags-instance_method"></a>
Get most popular tags
- **`@param`** `limit` [Integer] Number of tags to return (capped at MAX_TAG_QUERY_LIMIT)
- **`@param`** `timeframe` [Range, nil] Optional time range filter
- **`@return`** [Array<Hash>] Tags with usage counts

### `search_tags(query, limit: 20, min_similarity: DEFAULT_TAG_SIMILARITY_THRESHOLD)` <a id="method-i-search_tags"></a> <a id="search_tags-instance_method"></a>
Fuzzy search for tags using trigram similarity

Uses PostgreSQL pg_trgm extension to find tags that are similar to the query
string, tolerating typos and partial matches.
- **`@param`** `query` [String] Search query (tag name or partial)
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_TAG_QUERY_LIMIT)
- **`@param`** `min_similarity` [Float] Minimum similarity threshold (0.0-1.0)
- **`@return`** [Array<Hash>] Matching tags with similarity scores
Each hash contains: { name: String, similarity: Float }

### `topic_relationships(min_shared_nodes: 2, limit: 50)` <a id="method-i-topic_relationships"></a> <a id="topic_relationships-instance_method"></a>
Get topic relationships (co-occurrence)
- **`@param`** `min_shared_nodes` [Integer] Minimum shared nodes
- **`@param`** `limit` [Integer] Maximum relationships (capped at MAX_TAG_QUERY_LIMIT)
- **`@return`** [Array<Hash>] Topic relationships
