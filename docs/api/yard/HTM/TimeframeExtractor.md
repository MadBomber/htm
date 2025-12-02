# Class: HTM::TimeframeExtractor
**Inherits:** Object
    

Timeframe Extractor - Extracts temporal expressions from queries

This service parses natural language time expressions from recall queries and
returns both the timeframe and the cleaned query text.

Supports:
*   Standard time expressions via Chronic gem ("yesterday", "last week", etc.)
*   "few" keyword mapped to FEW constant (e.g., "few days ago" → "3 days ago")
*   "recent/recently" without units defaults to FEW days


**@example**
```ruby
result = TimeframeExtractor.extract("what did we discuss last week about PostgreSQL")
result[:query]     # => "what did we discuss about PostgreSQL"
result[:timeframe] # => #<Range: 2025-11-21..2025-11-28>
```
**@example**
```ruby
result = TimeframeExtractor.extract("show me notes from a few days ago")
result[:timeframe] # => Time object for 3 days ago
```
**@example**
```ruby
result = TimeframeExtractor.extract("what did we recently discuss")
result[:timeframe] # => Range from 3 days ago to now
```
# Class Methods
## extract(query ) [](#method-c-extract)
Extract timeframe from a query string
**@param** [String] The query to parse

**@return** [Result] Struct with :query (cleaned), :timeframe, :original_expression

## temporal?(query ) [](#method-c-temporal?)
Check if query contains a temporal expression
**@param** [String] The query to check

**@return** [Boolean] 


