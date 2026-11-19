# Class HTM::Jobs::GenerateEmbeddingJob <a id="class-HTM-Jobs-GenerateEmbeddingJob"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/jobs/generate_embedding_job.rb |

Background job to generate and store vector embeddings for nodes

- **`@see`** `ADR-016:` Async Embedding and Tag Generation

## Public Class Methods
### `perform(node_id:)` <a id="method-c-perform"></a> <a id="perform-class_method"></a>
Generate embedding for a node
- **`@param`** `node_id` [Integer] ID of the node to process
