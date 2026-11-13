# Class HTM::ConfigurationError <a id="class-HTM-ConfigurationError"></a>

|  |  |
| --- | --- |
| **Inherits** | [HTM::Error](Error.md) |
| **Defined in** | lib/htm/errors.rb |

Raised when configuration is invalid or incomplete

Common causes:
*   Invalid HTM_ENV value (not defined in config)
*   Missing database configuration for environment
*   HTM_CONF pointing to non-existent file
*   Invalid YAML syntax in config file

**`@example`**
```ruby
HTM_ENV=staginr rake htm:db:create  # => raises ConfigurationError
HTM_ENV=defaults rake htm:db:setup  # => raises ConfigurationError
```
