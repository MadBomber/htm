# Class HTM::Models::Tag <a id="class-HTM-Models-Tag"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/models/tag.rb |

Tag model - represents unique tag names Tags have a many-to-many relationship
with nodes through node_tags

## Constants
### `TAG_FORMAT` <a id="constant-TAG_FORMAT"></a> <a id="TAG_FORMAT-constant"></a>
Tag name format regex

## Public Class Methods
### `calculate_node_positions(node, depth, positions, y_offset, h_spacing, v_spacing, parent_path = nil)` <a id="method-c-calculate_node_positions"></a> <a id="calculate_node_positions-class_method"></a>
Calculate node positions for SVG layout (internal helper)

### `calculate_tree_stats(node, depth = 0)` <a id="method-c-calculate_tree_stats"></a> <a id="calculate_tree_stats-class_method"></a>
Calculate tree statistics (internal helper)

### `empty_tree_svg(title)` <a id="method-c-empty_tree_svg"></a> <a id="empty_tree_svg-class_method"></a>
Generate SVG for empty tree (internal helper)

### `exists?(conditions = {})` <a id="method-c-exists-3F"></a> <a id="exists?-class_method"></a>
Check if a tag exists with the given conditions
- **`@param`** `conditions` [Hash] Conditions to check
- **`@return`** [Boolean] true if a matching tag exists

### `expand_hierarchy(tag_name)` <a id="method-c-expand_hierarchy"></a> <a id="expand_hierarchy-class_method"></a>
Expand a hierarchical tag name into all ancestor paths
- **`@param`** `tag_name` [String] Hierarchical tag (e.g., "a:b:c:d")
- **`@return`** [Array<String>] All paths from root to leaf

### `find_by_topic_prefix(prefix)` <a id="method-c-find_by_topic_prefix"></a> <a id="find_by_topic_prefix-class_method"></a>
Find tags with a given prefix (hierarchical query)
- **`@param`** `prefix` [String] Tag prefix to match (e.g., "database" matches "database:postgresql")
- **`@return`** [Sequel::Dataset] Tags matching the prefix

### `find_or_create_by_name(name)` <a id="method-c-find_or_create_by_name"></a> <a id="find_or_create_by_name-class_method"></a>
Find or create a tag by name
- **`@param`** `name` [String] Hierarchical tag name (e.g., "database:postgresql")
- **`@return`** [Tag] The found or created tag

### `find_or_create_with_ancestors(name)` <a id="method-c-find_or_create_with_ancestors"></a> <a id="find_or_create_with_ancestors-class_method"></a>
Find or create a tag and all its ancestor tags
- **`@param`** `name` [String] Hierarchical tag name (e.g., "database:postgresql:extensions")
- **`@return`** [Array<Tag>] All created/found tags from root to leaf

### `format_tree_branch(node, is_last_array = [])` <a id="method-c-format_tree_branch"></a> <a id="format_tree_branch-class_method"></a>
Format a tree branch recursively (internal helper)

### `generate_mermaid_nodes(node, parent_path, lines, node_ids, counter)` <a id="method-c-generate_mermaid_nodes"></a> <a id="generate_mermaid_nodes-class_method"></a>
Generate Mermaid nodes recursively (internal helper)

### `generate_tree_svg(tree_data, positions, width, height, padding, node_width, node_height, title)` <a id="method-c-generate_tree_svg"></a> <a id="generate_tree_svg-class_method"></a>
Generate SVG tree visualization (internal helper)

### `popular_tags(limit = 10)` <a id="method-c-popular_tags"></a> <a id="popular_tags-class_method"></a>
Get the most frequently used tags
- **`@param`** `limit` [Integer] Maximum number of tags to return (default: 10)
- **`@return`** [Array<Tag>] Tags with usage_count attribute

### `svg_edge_path(x1, y1, x2, y2)` <a id="method-c-svg_edge_path"></a> <a id="svg_edge_path-class_method"></a>
Not documented.

### `svg_node_coords(pos, parent_pos, padding, node_width, node_height)` <a id="method-c-svg_node_coords"></a> <a id="svg_node_coords-class_method"></a>
Not documented.

### `svg_node_elements(path, pos, parent_pos, colors, padding, node_width, node_height)` <a id="method-c-svg_node_elements"></a> <a id="svg_node_elements-class_method"></a>
Not documented.

### `svg_node_label(x, y, node_width, node_height, label)` <a id="method-c-svg_node_label"></a> <a id="svg_node_label-class_method"></a>
Not documented.

### `svg_node_rect(x, y, node_width, node_height, color)` <a id="method-c-svg_node_rect"></a> <a id="svg_node_rect-class_method"></a>
Not documented.

### `svg_title_element(width, title)` <a id="method-c-svg_title_element"></a> <a id="svg_title_element-class_method"></a>
Not documented.

### `tree()` <a id="method-c-tree"></a> <a id="tree-class_method"></a>
Returns a nested hash tree structure from the current scope
- **`@return`** [Hash] Nested hash representing the tag hierarchy

### `tree_mermaid(direction: 'TD')` <a id="method-c-tree_mermaid"></a> <a id="tree_mermaid-class_method"></a>
Returns a Mermaid flowchart representation of the tag tree
- **`@param`** `direction` [String] Flow direction: 'TD' (top-down), 'LR' (left-right), 'BT', 'RL'
- **`@return`** [String] Mermaid flowchart syntax

### `tree_string()` <a id="method-c-tree_string"></a> <a id="tree_string-class_method"></a>
Returns a formatted string representation of the tag tree
- **`@return`** [String] Formatted tree string

### `tree_svg(title: 'HTM Tag Hierarchy')` <a id="method-c-tree_svg"></a> <a id="tree_svg-class_method"></a>
Returns an SVG representation of the tag tree
- **`@param`** `title` [String] Optional title for the SVG
- **`@return`** [String] SVG markup

## Public Instance Methods
### `before_create()` <a id="method-i-before_create"></a> <a id="before_create-instance_method"></a>
Hooks

### `deleted?()` <a id="method-i-deleted-3F"></a> <a id="deleted?-instance_method"></a>
Check if tag is soft-deleted
- **`@return`** [Boolean] true if deleted_at is set

### `depth()` <a id="method-i-depth"></a> <a id="depth-instance_method"></a>
Get the depth (number of levels) of this tag
- **`@return`** [Integer] Number of hierarchy levels

### `hierarchical?()` <a id="method-i-hierarchical-3F"></a> <a id="hierarchical?-instance_method"></a>
Check if this tag is hierarchical (has child levels)
- **`@return`** [Boolean] True if tag contains colons (hierarchy separators)

### `restore!()` <a id="method-i-restore-21"></a> <a id="restore!-instance_method"></a>
Restore a soft-deleted tag
- **`@return`** [Boolean] true if restored successfully

### `root_topic()` <a id="method-i-root_topic"></a> <a id="root_topic-instance_method"></a>
Get the root (top-level) topic of this tag
- **`@return`** [String] The first segment of the hierarchical tag

### `soft_delete!()` <a id="method-i-soft_delete-21"></a> <a id="soft_delete!-instance_method"></a>
Soft delete - mark tag as deleted without removing from database
- **`@return`** [Boolean] true if soft deleted successfully

### `topic_levels()` <a id="method-i-topic_levels"></a> <a id="topic_levels-instance_method"></a>
Get all hierarchy levels of this tag
- **`@return`** [Array<String>] Array of topic segments

### `usage_count()` <a id="method-i-usage_count"></a> <a id="usage_count-instance_method"></a>
Get the number of nodes using this tag
- **`@return`** [Integer] Count of nodes with this tag

### `validate()` <a id="method-i-validate"></a> <a id="validate-instance_method"></a>
Validations
