# Module HTM::LongTermMemory::RelevanceScorer <a id="module-HTM-LongTermMemory-RelevanceScorer"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/long_term_memory/relevance_scorer.rb |

Relevance scoring for search results

Combines multiple signals to calculate dynamic relevance:
*   Vector similarity (semantic match) - config.relevance_semantic_weight
    (default: 0.5)
*   Tag overlap (categorical match) - config.relevance_tag_weight (default:
    0.3)
*   Recency (freshness) - config.relevance_recency_weight (default: 0.1)
*   Access frequency (popularity/utility) - config.relevance_access_weight
    (default: 0.1)

Recency decay uses configurable half-life:
config.relevance_recency_half_life_hours (default: 168 = 1 week)

Also provides tag similarity calculations using hierarchical Jaccard.

## Constants
### `ACCESS_SCORE_NORMALIZER` <a id="constant-ACCESS_SCORE_NORMALIZER"></a> <a id="ACCESS_SCORE_NORMALIZER-constant"></a>
Access frequency normalization

### `DEFAULT_NEUTRAL_SCORE` <a id="constant-DEFAULT_NEUTRAL_SCORE"></a> <a id="DEFAULT_NEUTRAL_SCORE-constant"></a>
Default score when signal is unavailable

### `RELEVANCE_MAX` <a id="constant-RELEVANCE_MAX"></a> <a id="RELEVANCE_MAX-constant"></a>
Not documented.

### `RELEVANCE_MIN` <a id="constant-RELEVANCE_MIN"></a> <a id="RELEVANCE_MIN-constant"></a>
Not documented.

### `RELEVANCE_SCALE` <a id="constant-RELEVANCE_SCALE"></a> <a id="RELEVANCE_SCALE-constant"></a>
Final score scaling

## Public Instance Methods
### `calculate_relevance(node:, query_tags: [], vector_similarity: nil, node_tags: nil)` <a id="method-i-calculate_relevance"></a> <a id="calculate_relevance-instance_method"></a>
Calculate dynamic relevance score for a node given query context
- **`@param`** `node` [Hash] Node data with similarity, tags, created_at, access_count
- **`@param`** `query_tags` [Array<String>] Tags associated with the query
- **`@param`** `vector_similarity` [Float, nil] Pre-computed vector similarity (0-1)
- **`@param`** `node_tags` [Array<String>, nil] Pre-loaded tags for this node (avoids N+1 query)
- **`@return`** [Float] Composite relevance score (RELEVANCE_MIN to RELEVANCE_MAX)

### `fetch_candidates_by_timeframe(timeframe:, metadata:, limit:)` <a id="method-i-fetch_candidates_by_timeframe"></a> <a id="fetch_candidates_by_timeframe-instance_method"></a>
Fetch candidates by timeframe using raw SQL (avoids ORM overhead)
- **`@param`** `timeframe` [nil, Range, Array<Range>] Time range(s) to search
- **`@param`** `metadata` [Hash] Filter by metadata fields
- **`@param`** `limit` [Integer] Maximum results
- **`@return`** [Array<Hash>] Candidate nodes as hashes

### `recency_half_life_hours()` <a id="method-i-recency_half_life_hours"></a> <a id="recency_half_life_hours-instance_method"></a>
Not documented.

### `search_by_tags(tags:, match_all: false, timeframe: nil, limit: 20)` <a id="method-i-search_by_tags"></a> <a id="search_by_tags-instance_method"></a>
Search nodes by tags
- **`@param`** `tags` [Array<String>] Tags to search for
- **`@param`** `match_all` [Boolean] If true, match ALL tags; if false, match ANY tag
- **`@param`** `timeframe` [Range, nil] Optional time range filter
- **`@param`** `limit` [Integer] Maximum results
- **`@return`** [Array<Hash>] Matching nodes with relevance scores

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

### `weight_access()` <a id="method-i-weight_access"></a> <a id="weight_access-instance_method"></a>
Not documented.

### `weight_recency()` <a id="method-i-weight_recency"></a> <a id="weight_recency-instance_method"></a>
Not documented.

### `weight_semantic()` <a id="method-i-weight_semantic"></a> <a id="weight_semantic-instance_method"></a>
Configurable scoring weights (via HTM.configuration)

### `weight_tag()` <a id="method-i-weight_tag"></a> <a id="weight_tag-instance_method"></a>
Not documented.
