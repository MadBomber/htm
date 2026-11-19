# Class HTM::Models::Node <a id="class-HTM-Models-Node"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/models/node.rb |

Node model - represents a memory node (conversation message)

Nodes are globally unique by content (via content_hash) and can be linked to
multiple robots through the robot_nodes join table.

## Public Class Methods
### `find_by_content(content)` <a id="method-c-find_by_content"></a> <a id="find_by_content-class_method"></a>
Find a node by content hash, or return nil
- **`@param`** `content` [String] The content to search for
- **`@return`** [Node, nil] The existing node or nil

### `generate_content_hash(content)` <a id="method-c-generate_content_hash"></a> <a id="generate_content_hash-class_method"></a>
Generate SHA-256 hash for content
- **`@param`** `content` [String] Content to hash
- **`@return`** [String] 64-character hex hash

### `purge_deleted(older_than:)` <a id="method-c-purge_deleted"></a> <a id="purge_deleted-class_method"></a>
Permanently delete all soft-deleted nodes older than the specified time
- **`@param`** `older_than` [Time] Delete nodes soft-deleted before this time
- **`@return`** [Integer] Number of nodes permanently deleted

## Public Instance Methods
### `add_tags(tag_names)` <a id="method-i-add_tags"></a> <a id="add_tags-instance_method"></a>
Add tags to this node (creates tags and all parent tags if they don't exist)
- **`@param`** `tag_names` [Array<String>, String] Tag name(s) to add
- **`@return`** [void]

### `before_create()` <a id="method-i-before_create"></a> <a id="before_create-instance_method"></a>
Not documented.

### `before_save()` <a id="method-i-before_save"></a> <a id="before_save-instance_method"></a>
Not documented.

### `before_validation()` <a id="method-i-before_validation"></a> <a id="before_validation-instance_method"></a>
Hooks

### `deleted?()` <a id="method-i-deleted-3F"></a> <a id="deleted?-instance_method"></a>
Check if node is soft-deleted
- **`@return`** [Boolean] true if deleted_at is set

### `embedding()` <a id="method-i-embedding"></a> <a id="embedding-instance_method"></a>
Override embedding getter to return Array instead of String pgvector stores as
string format "[0.1,0.2,...]" and we need Array<Float>

### `embedding_array()` <a id="method-i-embedding_array"></a> <a id="embedding_array-instance_method"></a>
Get embedding as an Array (handles both String and Array storage) Note: The
`embedding` getter already returns Array, this is an alias for compatibility
- **`@return`** [Array<Float>, nil] The embedding vector as an array

### `nearest_neighbors(limit: 10, distance: "cosine")` <a id="method-i-nearest_neighbors"></a> <a id="nearest_neighbors-instance_method"></a>
Find nearest neighbors to this node's embedding
- **`@param`** `limit` [Integer] number of neighbors to return (default: 10)
- **`@param`** `distance` [String] distance metric (default: "cosine")
- **`@return`** [Array<Node>] ordered by distance (closest first)

### `neighbor_distance()` <a id="method-i-neighbor_distance"></a> <a id="neighbor_distance-instance_method"></a>
Accessor for neighbor_distance from nearest_neighbors query Works with both:
*   Instance method (stores in @neighbor_distance)
*   Dataset method (stores in values hash from SELECT)

### `proposition?()` <a id="method-i-proposition-3F"></a> <a id="proposition?-instance_method"></a>
Check if node is a proposition (extracted atomic fact)
- **`@return`** [Boolean] true if metadata['is_proposition'] is true

### `remove_tag(tag_name)` <a id="method-i-remove_tag"></a> <a id="remove_tag-instance_method"></a>
Remove a tag from this node
- **`@param`** `tag_name` [String] Tag name to remove
- **`@return`** [void]

### `restore!()` <a id="method-i-restore-21"></a> <a id="restore!-instance_method"></a>
Restore a soft-deleted node
- **`@return`** [Boolean] true if restored successfully

### `similarity_to(other)` <a id="method-i-similarity_to"></a> <a id="similarity_to-instance_method"></a>
Calculate cosine similarity to another embedding or node
- **`@param`** `other` [Array, Node] query embedding vector or another Node
- **`@return`** [Float] similarity score (0.0 to 1.0, higher is more similar)

### `soft_delete!()` <a id="method-i-soft_delete-21"></a> <a id="soft_delete!-instance_method"></a>
Soft delete - mark node as deleted without removing from database
- **`@return`** [Boolean] true if soft deleted successfully

### `tag_names()` <a id="method-i-tag_names"></a> <a id="tag_names-instance_method"></a>
Get all tag names associated with this node
- **`@return`** [Array<String>] Array of hierarchical tag names

### `to_hash()` <a id="method-i-to_hash"></a> <a id="to_hash-instance_method"></a>
Convert to hash (for compatibility with existing code)
- **`@return`** [Hash] Hash representation of the node

### `validate()` <a id="method-i-validate"></a> <a id="validate-instance_method"></a>
Validations
