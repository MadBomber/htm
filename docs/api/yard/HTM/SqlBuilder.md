# Class HTM::SqlBuilder <a id="class-HTM-SqlBuilder"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/sql_builder.rb |

SQL building utilities for constructing safe, parameterized queries

Provides class methods for building SQL conditions for:
*   Timeframe filtering (single range or multiple ranges)
*   Metadata filtering (JSONB containment)
*   Embedding sanitization and padding (SQL injection prevention)
*   LIKE pattern sanitization (wildcard injection prevention)

All methods use proper escaping and parameterization to prevent SQL injection.

**@example Build a timeframe condition**
```ruby
HTM::SqlBuilder.timeframe_condition(1.week.ago..Time.now)
# => "(created_at BETWEEN '2024-01-01' AND '2024-01-08')"
```

**@example Build a metadata condition**
```ruby
HTM::SqlBuilder.metadata_condition({ priority: "high" })
# => "(metadata @> '{\"priority\":\"high\"}'::jsonb)"
```

**@example Sanitize an embedding**
```ruby
HTM::SqlBuilder.sanitize_embedding([0.1, 0.2, 0.3])
# => "[0.1,0.2,0.3]"
```

**@example Sanitize a LIKE pattern**
```ruby
HTM::SqlBuilder.sanitize_like_pattern("test%pattern")
# => "test\\%pattern"
```

## Constants
### `MAX_EMBEDDING_DIMENSION` <a id="constant-MAX_EMBEDDING_DIMENSION"></a> <a id="MAX_EMBEDDING_DIMENSION-constant"></a>
Maximum embedding dimension supported by pgvector with HNSW index

## Public Class Methods
### `apply_metadata(scope, metadata, column: "metadata")` <a id="method-c-apply_metadata"></a> <a id="apply_metadata-class_method"></a>
Apply metadata filter to Sequel dataset
- **`@param`** `scope` [Sequel::Dataset] Base dataset
- **`@param`** `metadata` [Hash] Metadata to filter by
- **`@param`** `column` [String] Column name (default: "metadata")
- **`@return`** [Sequel::Dataset] Filtered dataset

### `apply_timeframe(scope, timeframe, column: :created_at)` <a id="method-c-apply_timeframe"></a> <a id="apply_timeframe-class_method"></a>
Apply timeframe filter to Sequel dataset
- **`@param`** `scope` [Sequel::Dataset] Base dataset
- **`@param`** `timeframe` [nil, Range, Array<Range>] Time range(s)
- **`@param`** `column` [Symbol] Column name (default: :created_at)
- **`@return`** [Sequel::Dataset] Filtered dataset

### `metadata_condition(metadata, table_alias: nil, column: "metadata")` <a id="method-c-metadata_condition"></a> <a id="metadata_condition-class_method"></a>
Build SQL condition for metadata filtering (JSONB containment)
- **`@param`** `metadata` [Hash] Metadata to filter by
- **`@param`** `table_alias` [String, nil] Table alias (default: none)
- **`@param`** `column` [String] Column name (default: "metadata")
- **`@return`** [String, nil] SQL condition or nil for no filter

### `pad_embedding(embedding, target_dimension: MAX_EMBEDDING_DIMENSION)` <a id="method-c-pad_embedding"></a> <a id="pad_embedding-class_method"></a>
Pad embedding to target dimension

Pads embedding with zeros to reach the target dimension for pgvector
compatibility.
- **`@param`** `embedding` [Array<Numeric>] Embedding vector
- **`@param`** `target_dimension` [Integer] Target dimension (default: MAX_EMBEDDING_DIMENSION)
- **`@return`** [Array<Numeric>] Padded embedding

### `sanitize_embedding(embedding)` <a id="method-c-sanitize_embedding"></a> <a id="sanitize_embedding-class_method"></a>
Sanitize embedding for SQL use

Validates that all values are numeric and converts to safe PostgreSQL vector
format. This prevents SQL injection by ensuring only valid numeric values are
included.
- **`@param`** `embedding` [Array<Numeric>] Embedding vector
- **`@raise`** [ArgumentError] If embedding contains non-numeric values
- **`@return`** [String] Sanitized vector string for PostgreSQL (e.g., "[0.1,0.2,0.3]")

### `sanitize_like_pattern(pattern)` <a id="method-c-sanitize_like_pattern"></a> <a id="sanitize_like_pattern-class_method"></a>
Sanitize a string for use in SQL LIKE patterns

Escapes SQL LIKE wildcards (% and _) to prevent pattern injection.
- **`@param`** `pattern` [String] Pattern to sanitize
- **`@return`** [String] Sanitized pattern safe for LIKE queries

### `timeframe_condition(timeframe, table_alias: nil, column: "created_at")` <a id="method-c-timeframe_condition"></a> <a id="timeframe_condition-class_method"></a>
Build SQL condition for timeframe filtering
- **`@param`** `timeframe` [nil, Range, Array<Range>] Time range(s)
- **`@param`** `table_alias` [String, nil] Table alias (default: none)
- **`@param`** `column` [String] Column name (default: "created_at")
- **`@return`** [String, nil] SQL condition or nil for no filter
