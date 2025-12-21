# Timeframe Demo

This example demonstrates the flexible timeframe options for filtering memories by time in HTM recall queries.

**Source:** [`examples/timeframe_demo.rb`](https://github.com/madbomber/htm/blob/main/examples/timeframe_demo.rb)

## Overview

HTM supports natural language time expressions for filtering memories. This example shows:

- Date and Time object filtering
- Range-based precise filtering
- Natural language expressions ("yesterday", "last week")
- Automatic timeframe extraction from queries (`:auto`)
- Multiple time windows

## Running the Example

```bash
export HTM_DATABASE__URL="postgresql://user@localhost:5432/htm_development"
ruby examples/timeframe_demo.rb
```

## Timeframe Options

### No Filter (nil)

```ruby
# Search all memories regardless of time
htm.recall("PostgreSQL", timeframe: nil)
```

### Date Object

A Date is expanded to cover the entire day (00:00:00 to 23:59:59):

```ruby
htm.recall("meetings", timeframe: Date.today)
htm.recall("notes", timeframe: Date.new(2025, 11, 15))
```

### Range (Precise Control)

```ruby
start_time = Time.now - (7 * 24 * 60 * 60)  # 7 days ago
end_time = Time.now

htm.recall("updates", timeframe: start_time..end_time)
```

### Natural Language

HTM uses the Chronic gem for parsing natural language time expressions:

```ruby
htm.recall("notes", timeframe: "yesterday")
htm.recall("discussions", timeframe: "last week")
htm.recall("decisions", timeframe: "last month")
htm.recall("tasks", timeframe: "this morning")
```

#### Supported Expressions

| Expression | Meaning |
|------------|---------|
| `"yesterday"` | Previous day |
| `"last week"` | Previous 7 days |
| `"last month"` | Previous 30 days |
| `"today"` | Current day |
| `"this morning"` | Today before noon |
| `"few days ago"` | 3 days ago |
| `"last weekend"` | Previous Saturday-Monday |
| `"2 weekends ago"` | Two weekends back |

### Automatic Extraction (`:auto`)

Extract timeframe from the query text automatically:

```ruby
# The timeframe is extracted and removed from the search query
htm.recall("what did we discuss last week about databases", timeframe: :auto)
# Searches for: "what did we discuss about databases"
# Timeframe: last week's date range

htm.recall("show me notes from yesterday about PostgreSQL", timeframe: :auto)
# Searches for: "show me notes about PostgreSQL"
# Timeframe: yesterday's date range
```

### Multiple Time Windows

Search across multiple date ranges (OR'd together):

```ruby
today = Date.today
last_friday = today - ((today.wday + 2) % 7)
two_fridays_ago = last_friday - 7

htm.recall("standup notes", timeframe: [last_friday, two_fridays_ago])
```

SQL equivalent:
```sql
WHERE (created_at BETWEEN '...' AND '...')
   OR (created_at BETWEEN '...' AND '...')
```

## Configuration

```ruby
HTM.configure do |config|
  # Configure week start for "last weekend" calculations
  config.week_start = :sunday  # or :monday
end
```

## Summary Table

| Input Type | Behavior |
|------------|----------|
| `nil` | No time filter |
| `Date` | Entire day (00:00:00 to 23:59:59) |
| `DateTime` | Entire day (same as Date) |
| `Time` | Entire day (same as Date) |
| `Range` | Exact time window |
| `String` | Natural language parsing via Chronic |
| `:auto` | Extract from query, return cleaned query |
| `Array<Range>` | Multiple time windows OR'd together |

## Special Keywords

| Keyword | Meaning |
|---------|---------|
| `few`, `a few`, `several` | Maps to 3 |
| `recently`, `recent` | Last 3 days |
| `weekend before last` | 2 weekends ago (Sat-Mon) |
| `N weekends ago` | N weekends back (Sat-Mon range) |

## See Also

- [Recalling Memories Guide](../guides/recalling-memories.md)
- [Search Strategies Guide](../guides/search-strategies.md)
- [Timeframe API Reference](../api/yard/HTM/Timeframe.md)
