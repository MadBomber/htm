# Exception: HTM::QueryTimeoutError
**Inherits:** HTM::DatabaseError
    

Raised when a database query exceeds the configured timeout

Default timeout is 30 seconds. Configure via db_query_timeout parameter when
initializing HTM.


**`@example`**
```ruby
begin
  htm.recall("complex query", strategy: :hybrid)
rescue HTM::QueryTimeoutError
  # Retry with simpler query or smaller limit
end
```

