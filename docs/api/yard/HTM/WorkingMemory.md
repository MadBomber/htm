# Class HTM::WorkingMemory <a id="class-HTM-WorkingMemory"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/working_memory.rb |

Working Memory - Token-limited active context for immediate LLM use

WorkingMemory manages the active conversation context within token limits.
When full, it evicts less important or older nodes back to long-term storage.

Thread Safety: All public methods are protected by a mutex to ensure safe
concurrent access from multiple threads.

## Attributes
### `max_tokens` [R] <a id="attribute-i-max_tokens"></a> <a id="max_tokens-instance_method"></a>
Returns the value of attribute max_tokens.

## Public Instance Methods
### `add(key, value, token_count:, access_count: 0, last_accessed: nil, from_recall: false)` <a id="method-i-add"></a> <a id="add-instance_method"></a>
Add a node to working memory
- **`@param`** `key` [String] Node identifier
- **`@param`** `value` [String] Node content
- **`@param`** `token_count` [Integer] Number of tokens in this node
- **`@param`** `access_count` [Integer] Access count from long-term memory (default: 0)
- **`@param`** `last_accessed` [Time, nil] Last access time from long-term memory
- **`@param`** `from_recall` [Boolean] Whether this node was recalled from long-term memory
- **`@return`** [void]

### `add_from_sync(id:, content:, token_count:, created_at:)` <a id="method-i-add_from_sync"></a> <a id="add_from_sync-instance_method"></a>
Add a node from sync notification (bypasses normal add flow)

Called by RobotGroup when another robot adds to working memory. Does not
trigger notifications to avoid infinite loops.
- **`@param`** `id` [Integer] Node database ID
- **`@param`** `content` [String] Node content
- **`@param`** `token_count` [Integer] Token count
- **`@param`** `created_at` [Time] When node was created
- **`@return`** [void]

### `assemble_context(strategy:, max_tokens: nil)` <a id="method-i-assemble_context"></a> <a id="assemble_context-instance_method"></a>
Assemble context string for LLM
- **`@param`** `strategy` [Symbol] Assembly strategy (:recent, :frequent, :balanced)
- :recent - Most recently accessed (LRU)
- :frequent - Most frequently accessed (LFU)
- :balanced - Combines frequency × recency
- **`@param`** `max_tokens` [Integer, nil] Optional token limit
- **`@return`** [String] Assembled context

### `clear()` <a id="method-i-clear"></a> <a id="clear-instance_method"></a>
Clear all nodes from working memory
- **`@return`** [void]

### `clear_from_sync()` <a id="method-i-clear_from_sync"></a> <a id="clear_from_sync-instance_method"></a>
Clear all nodes from sync notification

Called by RobotGroup when another robot clears working memory.
- **`@return`** [void]

### `evict_to_make_space(needed_tokens)` <a id="method-i-evict_to_make_space"></a> <a id="evict_to_make_space-instance_method"></a>
Evict nodes to make space

Uses LFU + LRU strategy: Least Frequently Used + Least Recently Used Nodes
with low access count and old timestamps are evicted first
- **`@param`** `needed_tokens` [Integer] Number of tokens needed
- **`@return`** [Array<Hash>] Evicted nodes

### `has_space?(token_count)` <a id="method-i-has_space-3F"></a> <a id="has_space?-instance_method"></a>
Check if there's space for a node
- **`@param`** `token_count` [Integer] Number of tokens needed
- **`@return`** [Boolean] true if space available

### `initialize(max_tokens:)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Initialize working memory
- **`@param`** `max_tokens` [Integer] Maximum tokens allowed in working memory
- **`@return`** [WorkingMemory] a new instance of WorkingMemory

### `node_count()` <a id="method-i-node_count"></a> <a id="node_count-instance_method"></a>
Get node count
- **`@return`** [Integer] Number of nodes in working memory

### `remove(key)` <a id="method-i-remove"></a> <a id="remove-instance_method"></a>
Remove a node from working memory
- **`@param`** `key` [String] Node identifier
- **`@return`** [void]

### `remove_from_sync(node_id)` <a id="method-i-remove_from_sync"></a> <a id="remove_from_sync-instance_method"></a>
Remove a node from sync notification

Called by RobotGroup when another robot evicts from working memory.
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [void]

### `token_count()` <a id="method-i-token_count"></a> <a id="token_count-instance_method"></a>
Get current token count
- **`@return`** [Integer] Total tokens in working memory

### `utilization_percentage()` <a id="method-i-utilization_percentage"></a> <a id="utilization_percentage-instance_method"></a>
Get utilization percentage
- **`@return`** [Float] Percentage of working memory used
