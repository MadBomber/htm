# Class HTM::PropositionService <a id="class-HTM-PropositionService"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/proposition_service.rb |

Proposition Service - Extracts atomic factual propositions from text

This service breaks complex text into simple, self-contained factual
statements that can be stored as independent memory nodes. Each proposition:
*   Expresses a single fact
*   Is understandable without context
*   Uses full names, not pronouns
*   Includes relevant dates/qualifiers
*   Contains one subject-predicate relationship

The actual LLM call is delegated to HTM.configuration.proposition_extractor

**`@example`**
```ruby
propositions = HTM::PropositionService.extract(
  "In 1969, Neil Armstrong became the first person to walk on the Moon during Apollo 11."
)
# => ["Neil Armstrong was an astronaut.",
#     "Neil Armstrong walked on the Moon in 1969.",
#     "Neil Armstrong was the first person to walk on the Moon.",
#     "Neil Armstrong walked on the Moon during the Apollo 11 mission.",
#     "The Apollo 11 mission occurred in 1969."]
```

## Constants
### `META_RESPONSE_PATTERNS` <a id="constant-META_RESPONSE_PATTERNS"></a> <a id="META_RESPONSE_PATTERNS-constant"></a>
Patterns that indicate meta-responses (LLM asking for input instead of
extracting)

## Public Class Methods
### `circuit_breaker()` <a id="method-c-circuit_breaker"></a> <a id="circuit_breaker-class_method"></a>
Get or create the circuit breaker for proposition service
- **`@return`** [HTM::CircuitBreaker] The circuit breaker instance

### `extract(content)` <a id="method-c-extract"></a> <a id="extract-class_method"></a>
Extract propositions from text content
- **`@param`** `content` [String] Text to analyze
- **`@raise`** [CircuitBreakerOpenError] If circuit breaker is open
- **`@raise`** [PropositionError] If extraction fails
- **`@return`** [Array<String>] Array of atomic propositions

### `max_length()` <a id="method-c-max_length"></a> <a id="max_length-class_method"></a>
Get maximum character length from config
- **`@return`** [Integer] Maximum character count for valid propositions

### `meta_response?(proposition)` <a id="method-c-meta_response-3F"></a> <a id="meta_response?-class_method"></a>
Check if proposition is a meta-response (LLM asking for input)
- **`@param`** `proposition` [String] Proposition to check
- **`@return`** [Boolean] True if it's a meta-response

### `min_length()` <a id="method-c-min_length"></a> <a id="min_length-class_method"></a>
Get minimum character length from config
- **`@return`** [Integer] Minimum character count for valid propositions

### `min_words()` <a id="method-c-min_words"></a> <a id="min_words-class_method"></a>
Get minimum words from config
- **`@return`** [Integer] Minimum word count for valid propositions

### `parse_propositions(raw_propositions)` <a id="method-c-parse_propositions"></a> <a id="parse_propositions-class_method"></a>
Parse proposition response (handles string or array input)
- **`@param`** `raw_propositions` [String, Array] Raw response from extractor
- **`@return`** [Array<String>] Parsed proposition strings

### `reset_circuit_breaker!()` <a id="method-c-reset_circuit_breaker-21"></a> <a id="reset_circuit_breaker!-class_method"></a>
Reset the circuit breaker (useful for testing)
- **`@return`** [void]

### `valid_proposition?(proposition)` <a id="method-c-valid_proposition-3F"></a> <a id="valid_proposition?-class_method"></a>
Validate single proposition
- **`@param`** `proposition` [String] Proposition to validate
- **`@return`** [Boolean] True if valid

### `validate_and_filter_propositions(propositions)` <a id="method-c-validate_and_filter_propositions"></a> <a id="validate_and_filter_propositions-class_method"></a>
Validate and filter propositions
- **`@param`** `propositions` [Array<String>] Parsed propositions
- **`@return`** [Array<String>] Valid propositions only
