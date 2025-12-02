# Exception: HTM::ValidationError
**Inherits:** HTM::Error
    

Raised when input validation fails

Common causes:
*   Empty or nil content for remember()
*   Content exceeding maximum size limit
*   Invalid tag format
*   Invalid recall strategy
*   Invalid timeframe format


**`@example`**
```ruby
htm.remember("")  # => raises ValidationError
htm.remember("x", tags: ["INVALID!"])  # => raises ValidationError
```

