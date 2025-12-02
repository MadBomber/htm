# Class: HTM::Timeframe
**Inherits:** Object
    

Timeframe - Normalizes various timeframe inputs for database queries

Handles multiple input types and normalizes them to either:
*   nil (no timeframe filter)
*   Range (single time window)
*   Array<Range> (multiple time windows, OR'd together)


**@example**
```ruby
Timeframe.normalize(nil)                    # => nil (no filter)
Timeframe.normalize(Date.today)             # => Range for entire day
Timeframe.normalize(Time.now)               # => Range for entire day
Timeframe.normalize("last week")            # => Range from chronic/extractor
Timeframe.normalize(:auto, query: "...")    # => Extract from query text
Timeframe.normalize(range1..range2)         # => Pass through
Timeframe.normalize([range1, range2])       # => Array of ranges
```
# Class Methods
## normalize(input , query: nil) [](#method-c-normalize)
Normalize a timeframe input to nil, Range, or Array<Range>
**@param** [nil, Range, Array, Date, DateTime, Time, String, Symbol] Timeframe specification

**@param** [String, nil] Query text (required when input is :auto)

**@return** [nil, Range, Array<Range>] Normalized timeframe

**@return** [Result] When input is :auto, returns Result with :timeframe, :query, :extracted

## valid?(input ) [](#method-c-valid?)
Check if a value is a valid timeframe input
**@param** [Object] Value to check

**@return** [Boolean] 


