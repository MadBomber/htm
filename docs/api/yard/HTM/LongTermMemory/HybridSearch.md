# Module HTM::LongTermMemory::HybridSearch <a id="module-HTM-LongTermMemory-HybridSearch"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/long_term_memory/hybrid_search.rb |

Hybrid search using Reciprocal Rank Fusion (RRF)

Performs three independent searches and merges results:
1.  Vector similarity search for semantic matching
2.  Full-text search for keyword matching
3.  Tag-based search for hierarchical category matching

Results are merged using RRF scoring. Nodes appearing in multiple searches
receive boosted scores, making them rank higher.

Tag scoring uses hierarchical depth matching - the more levels of a tag
hierarchy that match, the higher the score contribution.

RRF Formula: score = Σ 1/(k + rank) for each search where node appears

Results are cached for performance.

Security: All queries use parameterized placeholders to prevent SQL injection.

## Constants
### `CANDIDATE_MULTIPLIER` <a id="constant-CANDIDATE_MULTIPLIER"></a> <a id="CANDIDATE_MULTIPLIER-constant"></a>
Multiplier for candidates from each search We fetch more candidates than
requested to ensure good fusion

### `MAX_HYBRID_LIMIT` <a id="constant-MAX_HYBRID_LIMIT"></a> <a id="MAX_HYBRID_LIMIT-constant"></a>
Maximum results to prevent DoS via unbounded queries

### `RRF_K` <a id="constant-RRF_K"></a> <a id="RRF_K-constant"></a>
RRF constant - higher values reduce the impact of rank differences 60 is the
standard value from the original RRF paper

## Public Instance Methods
### `search_hybrid(timeframe:, query:, limit:, embedding_service:, prefilter_limit: 100, metadata: {})` <a id="method-i-search_hybrid"></a> <a id="search_hybrid-instance_method"></a>
Hybrid search using Reciprocal Rank Fusion
- **`@param`** `timeframe` [Range] Time range to search
- **`@param`** `query` [String] Search query
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_HYBRID_LIMIT)
- **`@param`** `embedding_service` [Object] Service to generate embeddings
- **`@param`** `prefilter_limit` [Integer] Candidates per search (default: 100)
- **`@param`** `metadata` [Hash] Filter by metadata fields (default: {})
- **`@return`** [Array<Hash>] Matching nodes
