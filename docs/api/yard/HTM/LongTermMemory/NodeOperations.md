# Module HTM::LongTermMemory::NodeOperations <a id="module-HTM-LongTermMemory-NodeOperations"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/long_term_memory/node_operations.rb |

Node CRUD operations for LongTermMemory

Handles creating, reading, updating, and deleting memory nodes with:
*   Content deduplication via SHA-256 hash
*   Soft delete restoration on duplicate content
*   Robot-node linking with remember tracking
*   Bulk access tracking

## Public Instance Methods
### `add(content:, robot_id:, token_count: 0, embedding: nil, metadata: {})` <a id="method-i-add"></a> <a id="add-instance_method"></a>
Add a node to long-term memory (with deduplication)

If content already exists (by content_hash), links the robot to the existing
node and updates timestamps. Otherwise creates a new node.
- **`@param`** `content` [String] Conversation message/utterance
- **`@param`** `token_count` [Integer] Token count
- **`@param`** `robot_id` [Integer] Robot identifier
- **`@param`** `embedding` [Array<Float>, nil] Pre-generated embedding vector
- **`@param`** `metadata` [Hash] Flexible metadata for the node (default: {})
- **`@raise`** [ArgumentError] If metadata is not a Hash
- **`@return`** [Hash] { node_id:, is_new:, robot_node: }

### `delete(node_id)` <a id="method-i-delete"></a> <a id="delete-instance_method"></a>
Delete a node
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [void]

### `exists?(node_id)` <a id="method-i-exists-3F"></a> <a id="exists?-instance_method"></a>
Check if a node exists
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [Boolean] True if node exists

### `link_robot_to_node(robot_id:, node:, working_memory: false)` <a id="method-i-link_robot_to_node"></a> <a id="link_robot_to_node-instance_method"></a>
Link a robot to a node (create or update robot_node record)
- **`@param`** `robot_id` [Integer] Robot ID
- **`@param`** `node` [HTM::Models::Node] Node to link
- **`@param`** `working_memory` [Boolean] Whether node is in working memory (default: false)
- **`@return`** [HTM::Models::RobotNode] The robot_node link record

### `mark_evicted(robot_id:, node_ids:)` <a id="method-i-mark_evicted"></a> <a id="mark_evicted-instance_method"></a>
Mark nodes as evicted from working memory

Sets working_memory = false on the robot_nodes join table for the specified
robot and node IDs.
- **`@param`** `robot_id` [Integer] Robot ID whose working memory is being evicted
- **`@param`** `node_ids` [Array<Integer>] Node IDs to mark as evicted
- **`@return`** [void]

### `retrieve(node_id)` <a id="method-i-retrieve"></a> <a id="retrieve-instance_method"></a>
Retrieve a node by ID

Automatically tracks access by incrementing access_count and updating
last_accessed. Uses a single UPDATE query instead of separate increment! and
touch calls.
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [Hash, nil] Node data or nil

### `track_access(node_ids)` <a id="method-i-track_access"></a> <a id="track_access-instance_method"></a>
Track access for multiple nodes (bulk operation)

Updates access_count and last_accessed for all nodes in the array
- **`@param`** `node_ids` [Array<Integer>] Node IDs that were accessed
- **`@return`** [void]

### `update_last_accessed(node_id)` <a id="method-i-update_last_accessed"></a> <a id="update_last_accessed-instance_method"></a>
Update last_accessed timestamp
- **`@param`** `node_id` [Integer] Node database ID
- **`@return`** [void]
