# Class HTM::QueryTimeoutError <a id="class-HTM-QueryTimeoutError"></a>

|  |  |
| --- | --- |
| **Inherits** | [HTM::DatabaseError](DatabaseError.md) |
| **Defined in** | lib/htm/errors.rb |

Raised when a database query exceeds the configured timeout

Default timeout is 30 seconds. Configure via db_query_timeout parameter when
initializing HTM.

**@example Handling timeout**
```ruby
begin
  htm.recall("complex query", strategy: :hybrid)
rescue HTM::QueryTimeoutError
  # Retry with simpler query or smaller limit
end
```
