# Class HTM::Models::Robot <a id="class-HTM-Models-Robot"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/models/robot.rb |

Robot model - represents an LLM agent using the HTM system

Robots can share memories through the many-to-many relationship with nodes.
When a robot is deleted, only the robot_nodes links are removed; shared nodes
remain in the database for other robots.

## Public Class Methods
### `find_or_create_by_name(robot_name)` <a id="method-c-find_or_create_by_name"></a> <a id="find_or_create_by_name-class_method"></a>
Find or create a robot by name
- **`@param`** `robot_name` [String] Name of the robot
- **`@return`** [Robot] The found or created robot

## Public Instance Methods
### `before_create()` <a id="method-i-before_create"></a> <a id="before_create-instance_method"></a>
Hooks

### `memory_summary()` <a id="method-i-memory_summary"></a> <a id="memory_summary-instance_method"></a>
Get a summary of this robot's memory state
- **`@return`** [Hash] Summary including:
- :total_nodes [Integer] Total nodes associated with this robot
- :in_working_memory [Integer] Nodes currently in working memory
- :with_embeddings [Integer] Nodes that have embeddings generated

### `node_count()` <a id="method-i-node_count"></a> <a id="node_count-instance_method"></a>
Get the total number of nodes associated with this robot
- **`@return`** [Integer] Number of nodes

### `nodes_with_metadata(limit = 10)` <a id="method-i-nodes_with_metadata"></a> <a id="nodes_with_metadata-instance_method"></a>
Get nodes with their remember metadata for this robot
- **`@param`** `limit` [Integer] Max nodes to return
- **`@return`** [Array<Hash>] Nodes with remember_count, first/last_remembered_at

### `recent_nodes(limit = 10)` <a id="method-i-recent_nodes"></a> <a id="recent_nodes-instance_method"></a>
Get the most recent nodes for this robot
- **`@param`** `limit` [Integer] Maximum number of nodes to return (default: 10)
- **`@return`** [Array<Node>] Recent nodes ordered by created_at desc

### `validate()` <a id="method-i-validate"></a> <a id="validate-instance_method"></a>
Validations
