# Class HTM::Models::NodeTag <a id="class-HTM-Models-NodeTag"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/models/node_tag.rb |

NodeTag model - join table for many-to-many relationship between nodes and
tags

## Public Class Methods
### `link(node_id:, tag_id:)` <a id="method-c-link"></a> <a id="link-class_method"></a>
Link a node to a tag, restoring a soft-deleted link if one exists

The unique index on (node_id, tag_id) covers soft-deleted rows, which the
default scope hides, so find_or_create would try to INSERT a duplicate.
- **`@param`** `node_id` [Integer] Node database ID
- **`@param`** `tag_id` [Integer] Tag database ID
- **`@return`** [NodeTag] the active link

## Public Instance Methods
### `before_create()` <a id="method-i-before_create"></a> <a id="before_create-instance_method"></a>
Hooks

### `deleted?()` <a id="method-i-deleted-3F"></a> <a id="deleted?-instance_method"></a>
Check if entry is soft-deleted
- **`@return`** [Boolean] true if deleted_at is set

### `restore!()` <a id="method-i-restore-21"></a> <a id="restore!-instance_method"></a>
Restore a soft-deleted entry
- **`@return`** [Boolean] true if restored successfully

### `soft_delete!()` <a id="method-i-soft_delete-21"></a> <a id="soft_delete!-instance_method"></a>
Soft delete - mark as deleted without removing from database
- **`@return`** [Boolean] true if soft deleted successfully

### `validate()` <a id="method-i-validate"></a> <a id="validate-instance_method"></a>
Validations
