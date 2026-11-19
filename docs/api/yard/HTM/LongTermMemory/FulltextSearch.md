# Module HTM::LongTermMemory::FulltextSearch <a id="module-HTM-LongTermMemory-FulltextSearch"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/long_term_memory/fulltext_search.rb |

Full-text search using PostgreSQL tsvector and pg_trgm

Performs keyword-based search using:
*   PostgreSQL full-text search (tsvector/tsquery) for stemmed word matching
*   Trigram fuzzy matching (pg_trgm) for typos and partial words
*   Combined scoring: tsvector matches rank higher, trigram provides fallback

Results are cached for performance.

Security: All queries use parameterized placeholders to prevent SQL injection.

## Constants
### `MAX_FULLTEXT_LIMIT` <a id="constant-MAX_FULLTEXT_LIMIT"></a> <a id="MAX_FULLTEXT_LIMIT-constant"></a>
Maximum results to prevent DoS via unbounded queries

### `TRIGRAM_SIMILARITY_THRESHOLD` <a id="constant-TRIGRAM_SIMILARITY_THRESHOLD"></a> <a id="TRIGRAM_SIMILARITY_THRESHOLD-constant"></a>
Minimum trigram similarity threshold (0.0-1.0) Lower = more fuzzy matches,
higher = stricter matching

### `TSVECTOR_SCORE_BOOST` <a id="constant-TSVECTOR_SCORE_BOOST"></a> <a id="TSVECTOR_SCORE_BOOST-constant"></a>
Score boost for tsvector matches over trigram matches Ensures exact word
matches rank above fuzzy matches

## Public Instance Methods
### `search_fulltext(timeframe:, query:, limit:, metadata: {})` <a id="method-i-search_fulltext"></a> <a id="search_fulltext-instance_method"></a>
Full-text search
- **`@param`** `timeframe` [Range] Time range to search
- **`@param`** `query` [String] Search query
- **`@param`** `limit` [Integer] Maximum results (capped at MAX_FULLTEXT_LIMIT)
- **`@param`** `metadata` [Hash] Filter by metadata fields (default: {})
- **`@return`** [Array<Hash>] Matching nodes
