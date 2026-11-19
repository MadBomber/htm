# Class HTM::Timeframe <a id="class-HTM-Timeframe"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/timeframe.rb |

Timeframe - Normalizes various timeframe inputs for database queries

Handles multiple input types and normalizes them to either:
*   nil (no timeframe filter)
*   Range (single time window)
*   Array<Range> (multiple time windows, OR'd together)

**@example Various input types**
```ruby
Timeframe.normalize(nil)                    # => nil (no filter)
Timeframe.normalize(Date.today)             # => Range for entire day
Timeframe.normalize(Time.now)               # => Range for entire day
Timeframe.normalize("last week")            # => Range from chronic/extractor
Timeframe.normalize(:auto, query: "...")    # => Extract from query text
Timeframe.normalize(range1..range2)         # => Pass through
Timeframe.normalize([range1, range2])       # => Array of ranges
```

## Public Class Methods
### `normalize(input, query: nil)` <a id="method-c-normalize"></a> <a id="normalize-class_method"></a>
Normalize a timeframe input to nil, Range, or Array<Range>
- **`@param`** `input` [nil, Range, Array, Date, DateTime, Time, String, Symbol] Timeframe specification
- **`@param`** `query` [String, nil] Query text (required when input is :auto)
- **`@return`** [nil, Range, Array<Range>] Normalized timeframe
- **`@return`** [Result] When input is :auto, returns Result with :timeframe, :query, :extracted

### `valid?(input)` <a id="method-c-valid-3F"></a> <a id="valid?-class_method"></a>
Check if a value is a valid timeframe input
- **`@param`** `input` [Object] Value to check
- **`@return`** [Boolean]
