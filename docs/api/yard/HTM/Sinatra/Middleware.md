# Class HTM::Sinatra::Middleware <a id="class-HTM-Sinatra-Middleware"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/integrations/sinatra.rb |

Rack middleware for HTM connection management

Ensures database connections are properly managed across requests. With
Sequel's fiber-safe connection pooling, this is largely automatic.

**@example Use in Sinatra app**
```ruby
class MyApp < Sinatra::Base
  use HTM::Sinatra::Middleware
end
```

## Public Class Methods
### `store_config!()` <a id="method-c-store_config-21"></a> <a id="store_config!-class_method"></a>
Store the connection config at startup (called from register_htm)

## Public Instance Methods
### `call(env)` <a id="method-i-call"></a> <a id="call-instance_method"></a>
Not documented.

### `initialize(app, options = {})` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
- **`@return`** [Middleware] a new instance of Middleware
