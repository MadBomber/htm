# Class: HTM::PropositionService
**Inherits:** Object
    

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
# Class Methods
## circuit_breaker() {: #method-c-circuit_breaker }
Get or create the circuit breaker for proposition service
**`@return`** [HTM::CircuitBreaker] The circuit breaker instance

## extract(content ) {: #method-c-extract }
Extract propositions from text content
**`@param`** [String] Text to analyze

**`@raise`** [CircuitBreakerOpenError] If circuit breaker is open

**`@raise`** [PropositionError] If extraction fails

**`@return`** [Array<String>] Array of atomic propositions

## parse_propositions(raw_propositions ) {: #method-c-parse_propositions }
Parse proposition response (handles string or array input)
**`@param`** [String, Array] Raw response from extractor

**`@return`** [Array<String>] Parsed proposition strings

## reset_circuit_breaker!() {: #method-c-reset_circuit_breaker! }
Reset the circuit breaker (useful for testing)
**`@return`** [void] 

## valid_proposition?(proposition ) {: #method-c-valid_proposition? }
Validate single proposition
**`@param`** [String] Proposition to validate

**`@return`** [Boolean] True if valid

## validate_and_filter_propositions(propositions ) {: #method-c-validate_and_filter_propositions }
Validate and filter propositions
**`@param`** [Array<String>] Parsed propositions

**`@return`** [Array<String>] Valid propositions only


