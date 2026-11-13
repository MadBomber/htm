# Class HTM::TagService <a id="class-HTM-TagService"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/tag_service.rb |

Tag Service - Processes and validates hierarchical tags

This service wraps the configured tag extractor and provides:
*   Response parsing (string or array)
*   Format validation (lowercase, alphanumeric, hyphens, colons)
*   Depth validation (max 5 levels)
*   Ontology consistency
*   Circuit breaker protection for external LLM failures

The actual LLM call is delegated to HTM.configuration.tag_extractor

## Constants
### `SINGULARIZE_SKIP_LIST` <a id="constant-SINGULARIZE_SKIP_LIST"></a> <a id="SINGULARIZE_SKIP_LIST-constant"></a>
Words that should NOT be singularized (proper nouns, technical terms, etc.)

### `TAG_FORMAT` <a id="constant-TAG_FORMAT"></a> <a id="TAG_FORMAT-constant"></a>
Validation regex

## Public Class Methods
### `circuit_breaker()` <a id="method-c-circuit_breaker"></a> <a id="circuit_breaker-class_method"></a>
Get or create the circuit breaker for tag service
- **`@return`** [HTM::CircuitBreaker] The circuit breaker instance

### `extract(content, existing_ontology: [])` <a id="method-c-extract"></a> <a id="extract-class_method"></a>
Extract tags with validation and processing
- **`@param`** `content` [String] Text to analyze
- **`@param`** `existing_ontology` [Array<String>] Sample of existing tags for context
- **`@raise`** [CircuitBreakerOpenError] If circuit breaker is open
- **`@return`** [Array<String>] Validated tag names

### `max_depth()` <a id="method-c-max_depth"></a> <a id="max_depth-class_method"></a>
Maximum tag hierarchy depth (configurable, default 4)
- **`@return`** [Integer] Max depth (3 colons max by default)

### `parse_hierarchy(tag)` <a id="method-c-parse_hierarchy"></a> <a id="parse_hierarchy-class_method"></a>
Parse hierarchical structure of a tag
- **`@param`** `tag` [String] Hierarchical tag (e.g., "ai:llm:embedding")
- **`@return`** [Hash] Hierarchy structure
{
  full: "ai:llm:embedding",
  root: "ai",
  parent: "ai:llm",
  levels: ["ai", "llm", "embedding"],
  depth: 3
}

### `parse_tags(raw_tags)` <a id="method-c-parse_tags"></a> <a id="parse_tags-class_method"></a>
Parse tag response (handles string or array input)
- **`@param`** `raw_tags` [String, Array] Raw response from extractor
- **`@return`** [Array<String>] Parsed tag strings

### `reset_circuit_breaker!()` <a id="method-c-reset_circuit_breaker-21"></a> <a id="reset_circuit_breaker!-class_method"></a>
Reset the circuit breaker (useful for testing)
- **`@return`** [void]

### `singularize_level(level)` <a id="method-c-singularize_level"></a> <a id="singularize_level-class_method"></a>
Singularize a single tag level with safety checks
- **`@param`** `level` [String] Single tag level
- **`@return`** [String] Singularized level or original if skipped

### `singularize_tag_levels(tag)` <a id="method-c-singularize_tag_levels"></a> <a id="singularize_tag_levels-class_method"></a>
Normalize tag levels to singular form

Converts plural levels to singular using ActiveSupport's singularize. This
ensures taxonomy consistency (e.g., "users" -> "user").

Skips:
*   Proper nouns and technical terms (Rails, MkDocs, etc.)
*   Words ending in -ics (analytics, robotics, etc.)
*   Words that don't end in common plural patterns
- **`@param`** `tag` [String] Tag with potentially plural levels
- **`@return`** [String] Tag with all levels singularized

### `valid_tag?(tag)` <a id="method-c-valid_tag-3F"></a> <a id="valid_tag?-class_method"></a>
Validate single tag format
- **`@param`** `tag` [String] Tag to validate
- **`@return`** [Boolean] True if valid

### `validate_and_filter_tags(tags)` <a id="method-c-validate_and_filter_tags"></a> <a id="validate_and_filter_tags-class_method"></a>
Validate and filter tags
- **`@param`** `tags` [Array<String>] Parsed tags
- **`@return`** [Array<String>] Valid tags only
