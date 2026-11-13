# Class HTM::Jobs::GeneratePropositionsJob <a id="class-HTM-Jobs-GeneratePropositionsJob"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/jobs/generate_propositions_job.rb |

Background job to extract propositions from nodes and create new nodes

- **`@see`** `PropositionService`

## Public Class Methods
### `perform(node_id:, robot_id:)` <a id="method-c-perform"></a> <a id="perform-class_method"></a>
Generate propositions for a node
- **`@param`** `node_id` [Integer] ID of the node to process
- **`@param`** `robot_id` [Integer] ID of the robot that owns this node
