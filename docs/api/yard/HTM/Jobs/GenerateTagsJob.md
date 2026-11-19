# Class HTM::Jobs::GenerateTagsJob <a id="class-HTM-Jobs-GenerateTagsJob"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/jobs/generate_tags_job.rb |

Background job to generate and associate tags for nodes

- **`@see`** `ADR-016:` Async Embedding and Tag Generation
- **`@see`** `ADR-015:` Hierarchical Tag Ontology and LLM Extraction

## Public Class Methods
### `perform(node_id:)` <a id="method-c-perform"></a> <a id="perform-class_method"></a>
Generate tags for a node
- **`@param`** `node_id` [Integer] ID of the node to process
