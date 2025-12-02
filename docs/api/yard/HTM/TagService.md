# Class: HTM::TagService
**Inherits:** Object
    

Tag Service - Processes and validates hierarchical tags

This service wraps the configured tag extractor and provides:
*   Response parsing (string or array)
*   Format validation (lowercase, alphanumeric, hyphens, colons)
*   Depth validation (max 5 levels)
*   Ontology consistency
*   Circuit breaker protection for external LLM failures

The actual LLM call is delegated to HTM.configuration.tag_extractor


# Class Methods
## circuit_breaker() [](#method-c-circuit_breaker)
Get or create the circuit breaker for tag service
**@return** [HTM::CircuitBreaker] The circuit breaker instance

## extract(content , existing_ontology: []) [](#method-c-extract)
Extract tags with validation and processing
**@param** [String] Text to analyze

**@param** [Array<String>] Sample of existing tags for context

**@raise** [CircuitBreakerOpenError] If circuit breaker is open

**@return** [Array<String>] Validated tag names

## parse_hierarchy(tag ) [](#method-c-parse_hierarchy)
Parse hierarchical structure of a tag
**@param** [String] Hierarchical tag (e.g., "ai:llm:embedding")

**@return** [Hash] Hierarchy structure
{
  full: "ai:llm:embedding",
  root: "ai",
  parent: "ai:llm",
  levels: ["ai", "llm", "embedding"],
  depth: 3
}

## parse_tags(raw_tags ) [](#method-c-parse_tags)
Parse tag response (handles string or array input)
**@param** [String, Array] Raw response from extractor

**@return** [Array<String>] Parsed tag strings

## reset_circuit_breaker!() [](#method-c-reset_circuit_breaker!)
Reset the circuit breaker (useful for testing)
**@return** [void] 

## valid_tag?(tag ) [](#method-c-valid_tag?)
Validate single tag format
**@param** [String] Tag to validate

**@return** [Boolean] True if valid

## validate_and_filter_tags(tags ) [](#method-c-validate_and_filter_tags)
Validate and filter tags
**@param** [Array<String>] Parsed tags

**@return** [Array<String>] Valid tags only


