# Class HTM::Models::RobotNode <a id="class-HTM-Models-RobotNode"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/models/robot_node.rb |

RobotNode Join Model - Links robots to nodes (many-to-many)

This model represents the relationship between a robot and a node, tracking
when and how many times a robot has "remembered" a piece of content.

## Public Instance Methods
### `deleted?()` <a id="method-i-deleted-3F"></a> <a id="deleted?-instance_method"></a>
Check if entry is soft-deleted
- **`@return`** [Boolean] true if deleted_at is set

### `record_remember!()` <a id="method-i-record_remember-21"></a> <a id="record_remember!-instance_method"></a>
Record that a robot remembered this content again
- **`@return`** [RobotNode] Updated record

### `restore!()` <a id="method-i-restore-21"></a> <a id="restore!-instance_method"></a>
Restore a soft-deleted entry
- **`@return`** [Boolean] true if restored successfully

### `soft_delete!()` <a id="method-i-soft_delete-21"></a> <a id="soft_delete!-instance_method"></a>
Soft delete - mark as deleted without removing from database
- **`@return`** [Boolean] true if soft deleted successfully

### `validate()` <a id="method-i-validate"></a> <a id="validate-instance_method"></a>
Validations

### `working_memory?()` <a id="method-i-working_memory-3F"></a> <a id="working_memory?-instance_method"></a>
Check if this node is in working memory
- **`@return`** [Boolean] true if working_memory is set
