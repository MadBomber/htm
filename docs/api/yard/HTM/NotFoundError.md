# Exception: HTM::NotFoundError
**Inherits:** HTM::Error
    

Raised when a requested resource cannot be found

Common causes:
*   Node ID does not exist
*   Robot not registered
*   File source not found


**`@example`**
```ruby
htm.forget(999999)  # => raises NotFoundError if node doesn't exist
```

