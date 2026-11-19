# Class HTM::Models::NodeRelationship <a id="class-HTM-Models-NodeRelationship"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/models/node_relationship.rb |

NodeRelationship model - weighted directed edge between two nodes

Edges are stored in both directions so the CTE traversal only needs WHERE
source_id IN (seeds) rather than an OR across both columns.

Weights are Jaccard similarity scores for tag_cooccurrence edges:
    weight = |tags(A) ∩ tags(B)| / |tags(A) ∪ tags(B)|

## Constants
### `ORIGINS` <a id="constant-ORIGINS"></a> <a id="ORIGINS-constant"></a>
Not documented.

### `REL_TYPES` <a id="constant-REL_TYPES"></a> <a id="REL_TYPES-constant"></a>
Not documented.

## Public Instance Methods
### `before_create()` <a id="method-i-before_create"></a> <a id="before_create-instance_method"></a>
Hooks

### `before_save()` <a id="method-i-before_save"></a> <a id="before_save-instance_method"></a>
Not documented.

### `validate()` <a id="method-i-validate"></a> <a id="validate-instance_method"></a>
Validations
