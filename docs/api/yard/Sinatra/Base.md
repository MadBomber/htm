# Class Sinatra::Base <a id="class-Sinatra-Base"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/integrations/sinatra.rb |

## Public Class Methods
### `register_htm()` <a id="method-c-register_htm"></a> <a id="register_htm-class_method"></a>
Register HTM with Sinatra application

Automatically configures HTM for Sinatra apps:
*   Adds helpers
*   Adds middleware
*   Configures logger
**`@example`**
```ruby
class MyApp < Sinatra::Base
  register_htm

  post '/remember' do
    remember(params[:content])
  end
end
```
