# Class HTM::NotFoundError <a id="class-HTM-NotFoundError"></a>

|  |  |
| --- | --- |
| **Inherits** | [HTM::Error](Error.md) |
| **Defined in** | lib/htm/errors.rb |

Raised when a requested resource cannot be found

Common causes:
*   Node ID does not exist
*   Robot not registered
*   File source not found

**`@example`**
```ruby
htm.forget(999999)  # => raises NotFoundError if node doesn't exist
```
