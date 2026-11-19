# Module HTM::Sinatra::Helpers <a id="module-HTM-Sinatra-Helpers"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/integrations/sinatra.rb |

## Public Instance Methods
### `htm()` <a id="method-i-htm"></a> <a id="htm-instance_method"></a>
Get current HTM instance
- **`@raise`** [RuntimeError] If HTM not initialized (call init_htm first)
- **`@return`** [HTM] HTM instance for this request

### `init_htm(robot_name: 'guest', working_memory_size: 128_000)` <a id="method-i-init_htm"></a> <a id="init_htm-instance_method"></a>
Initialize HTM instance for current request
- **`@param`** `robot_name` [String] Robot identifier (typically user/session ID)
- **`@param`** `working_memory_size` [Integer] Token limit for working memory
- **`@return`** [HTM] HTM instance for this request

### `json(data)` <a id="method-i-json"></a> <a id="json-instance_method"></a>
JSON response helper
- **`@param`** `data` [Hash] Data to convert to JSON
- **`@return`** [String] JSON response

### `recall(topic)` <a id="method-i-recall"></a> <a id="recall-instance_method"></a>
Recall memories (convenience method)
- **`@param`** `topic` [String] Topic to search for
- **`@param`** `options` [Hash] Recall options (timeframe, limit, strategy, etc.)
- **`@return`** [Array<Hash>] Matching memories

### `remember(content, tags: [])` <a id="method-i-remember"></a> <a id="remember-instance_method"></a>
Remember information (convenience method)
- **`@param`** `content` [String] Content to remember
- **`@param`** `tags` [Array<String>] Optional tags to assign
- **`@return`** [Integer] Node ID
