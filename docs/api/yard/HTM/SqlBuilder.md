# Class: HTM::SqlBuilder
**Inherits:** Object
    

SQL building utilities for constructing safe, parameterized queries

Provides class methods for building SQL conditions for:
*   Timeframe filtering (single range or multiple ranges)
*   Metadata filtering (JSONB containment)
*   Embedding sanitization and padding (SQL injection prevention)
*   LIKE pattern sanitization (wildcard injection prevention)

All methods use proper escaping and parameterization to prevent SQL injection.


**`@example`**
```ruby
HTM::SqlBuilder.timeframe_condition(1.week.ago..Time.now)
# => "(created_at BETWEEN '2024-01-01' AND '2024-01-08')"
```
**`@example`**
```ruby
HTM::SqlBuilder.metadata_condition({ priority: "high" })
# => "(metadata @> '{\"priority\":\"high\"}'::jsonb)"
```
**`@example`**
```ruby
HTM::SqlBuilder.sanitize_embedding([0.1, 0.2, 0.3])
# => "[0.1,0.2,0.3]"
```
**`@example`**
```ruby
HTM::SqlBuilder.sanitize_like_pattern("test%pattern")
# => "test\\%pattern"
```
# Class Methods
## apply_metadata(scope , metadata , column: "metadata") {: #method-c-apply_metadata }
Apply metadata filter to ActiveRecord scope
**`@param`** [ActiveRecord::Relation] Base scope

**`@param`** [Hash] Metadata to filter by

**`@param`** [String] Column name (default: "metadata")

**`@return`** [ActiveRecord::Relation] Scoped query

## apply_timeframe(scope , timeframe , column: :created_at) {: #method-c-apply_timeframe }
Apply timeframe filter to ActiveRecord scope
**`@param`** [ActiveRecord::Relation] Base scope

**`@param`** [nil, Range, Array<Range>] Time range(s)

**`@param`** [Symbol] Column name (default: :created_at)

**`@return`** [ActiveRecord::Relation] Scoped query

## metadata_condition(metadata , table_alias: nil, column: "metadata") {: #method-c-metadata_condition }
Build SQL condition for metadata filtering (JSONB containment)
**`@param`** [Hash] Metadata to filter by

**`@param`** [String, nil] Table alias (default: none)

**`@param`** [String] Column name (default: "metadata")

**`@return`** [String, nil] SQL condition or nil for no filter

## pad_embedding(embedding , target_dimension: MAX_EMBEDDING_DIMENSION) {: #method-c-pad_embedding }
Pad embedding to target dimension

Pads embedding with zeros to reach the target dimension for pgvector
compatibility.
**`@param`** [Array<Numeric>] Embedding vector

**`@param`** [Integer] Target dimension (default: MAX_EMBEDDING_DIMENSION)

**`@return`** [Array<Numeric>] Padded embedding

## sanitize_embedding(embedding ) {: #method-c-sanitize_embedding }
Sanitize embedding for SQL use

Validates that all values are numeric and converts to safe PostgreSQL vector
format. This prevents SQL injection by ensuring only valid numeric values are
included.
**`@param`** [Array<Numeric>] Embedding vector

**`@raise`** [ArgumentError] If embedding contains non-numeric values

**`@return`** [String] Sanitized vector string for PostgreSQL (e.g., "[0.1,0.2,0.3]")

## sanitize_like_pattern(pattern ) {: #method-c-sanitize_like_pattern }
Sanitize a string for use in SQL LIKE patterns

Escapes SQL LIKE wildcards (% and _) to prevent pattern injection.
**`@param`** [String] Pattern to sanitize

**`@return`** [String] Sanitized pattern safe for LIKE queries

## timeframe_condition(timeframe , table_alias: nil, column: "created_at") {: #method-c-timeframe_condition }
Build SQL condition for timeframe filtering
**`@param`** [nil, Range, Array<Range>] Time range(s)

**`@param`** [String, nil] Table alias (default: none)

**`@param`** [String] Column name (default: "created_at")

**`@return`** [String, nil] SQL condition or nil for no filter


