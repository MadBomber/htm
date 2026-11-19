# Class HTM::TimeframeExtractor <a id="class-HTM-TimeframeExtractor"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/timeframe_extractor.rb |

Timeframe Extractor - Extracts temporal expressions from queries

This service parses natural language time expressions from recall queries and
returns both the timeframe and the cleaned query text.

Supports:
*   Standard time expressions via Chronic gem ("yesterday", "last week", etc.)
*   "few" keyword mapped to FEW constant (e.g., "few days ago" → "3 days ago")
*   "recent/recently" without units defaults to FEW days

**@example Basic usage**
```ruby
result = TimeframeExtractor.extract("what did we discuss last week about PostgreSQL")
result[:query]     # => "what did we discuss about PostgreSQL"
result[:timeframe] # => #<Range: 2025-11-21..2025-11-28>
```

**@example With "few" keyword**
```ruby
result = TimeframeExtractor.extract("show me notes from a few days ago")
result[:timeframe] # => Time object for 3 days ago
```

**@example With "recently"**
```ruby
result = TimeframeExtractor.extract("what did we recently discuss")
result[:timeframe] # => Range from 3 days ago to now
```

## Constants
### `DEFAULT_RECENT_UNIT` <a id="constant-DEFAULT_RECENT_UNIT"></a> <a id="DEFAULT_RECENT_UNIT-constant"></a>
Default unit for "recently" when no time unit is specified

### `FEW` <a id="constant-FEW"></a> <a id="FEW-constant"></a>
The numeric value for "few" and "recently" without units

### `TEMPORAL_PATTERNS` <a id="constant-TEMPORAL_PATTERNS"></a> <a id="TEMPORAL_PATTERNS-constant"></a>
Patterns for temporal expressions (order matters - more specific first) Each
pattern should match ORIGINAL text (including "few", "a few")

### `TIME_UNITS` <a id="constant-TIME_UNITS"></a> <a id="TIME_UNITS-constant"></a>
Time unit patterns for matching

### `UNIT_SECONDS` <a id="constant-UNIT_SECONDS"></a> <a id="UNIT_SECONDS-constant"></a>
Seconds per singular time unit (used by parse_last_x and parse_recent)

### `WORD_NUMBERS` <a id="constant-WORD_NUMBERS"></a> <a id="WORD_NUMBERS-constant"></a>
Word-to-number mapping for written numbers

## Public Class Methods
### `extract(query)` <a id="method-c-extract"></a> <a id="extract-class_method"></a>
Extract timeframe from a query string
- **`@param`** `query` [String] The query to parse
- **`@return`** [Result] Struct with :query (cleaned), :timeframe, :original_expression

### `temporal?(query)` <a id="method-c-temporal-3F"></a> <a id="temporal?-class_method"></a>
Check if query contains a temporal expression
- **`@param`** `query` [String] The query to check
- **`@return`** [Boolean]
