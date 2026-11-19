# Module HTM::LongTermMemory::VectorSearch <a id="module-HTM-LongTermMemory-VectorSearch"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/long_term_memory/vector_search.rb |

Vector similarity search using pgvector

Performs semantic search by:
1.  Generating query embedding client-side
2.  Using pgvector cosine distance for similarity ranking
3.  Supporting timeframe and metadata filtering

Results are cached for performance.

Security: All queries use parameterized placeholders to prevent SQL injection.

## Constants
### `MAX_VECTOR_LIMIT` <a id="constant-MAX_VECTOR_LIMIT"></a> <a id="MAX_VECTOR_LIMIT-constant"></a>
Maximum results to prevent DoS via unbounded queries

## Public Instance Methods
### `search(timeframe:, query:, limit:, embedding_service:, metadata: {})` <a id="method-i-search"></a> <a id="search-instance_method"></a>
Vector similarity search
- **`@param`** `timeframe` [nil, Range, Array<Range>] Time range(s) to search (nil = no filter)
- **`@param`** `query` [String] Search query
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_VECTOR_LIMIT)
- **`@param`** `embedding_service` [Object] Service to generate embeddings
- **`@param`** `metadata` [Hash] Filter by metadata fields (default: {})
- **`@return`** [Array<Hash>] Matching nodes
