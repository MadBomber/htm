# Module HTM::Sinatra <a id="module-HTM-Sinatra"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/integrations/sinatra.rb |

Sinatra helpers for HTM integration

Provides convenient helper methods for using HTM in Sinatra applications.

**@example Basic usage**
```ruby
require 'htm/integrations/sinatra'

class MyApp < Sinatra::Base
  register_htm

  before do
    init_htm(robot_name: session[:user_id] || 'guest')
  end

  post '/remember' do
    node_id = remember(params[:content])
    json status: 'ok', node_id: node_id
  end

  get '/recall' do
    memories = recall(params[:topic], limit: 10)
    json memories: memories
  end
end
```
