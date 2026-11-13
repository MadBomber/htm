# Module HTM::Jobs <a id="module-HTM-Jobs"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/jobs/generate_tags_job.rb, lib/htm/jobs/generate_embedding_job.rb, lib/htm/jobs/generate_propositions_job.rb, lib/htm/jobs/generate_relationships_job.rb |

## Constants
### `MAX_EDGES_PER_NODE` <a id="constant-MAX_EDGES_PER_NODE"></a> <a id="MAX_EDGES_PER_NODE-constant"></a>
Not documented.

### `MIN_WEIGHT_THRESHOLD` <a id="constant-MIN_WEIGHT_THRESHOLD"></a> <a id="MIN_WEIGHT_THRESHOLD-constant"></a>
Background job to compute and upsert weighted edges between nodes.

Runs after GenerateTagsJob so the node's tags are already present. For each
node, finds all other nodes sharing at least one tag and computes Jaccard
similarity as the edge weight:

    weight = |tags(A) ∩ tags(B)| / |tags(A) ∪ tags(B)|

Both directions are stored (A→B and B→A) so the CTE traversal only needs WHERE
source_id IN (seeds) with a plain btree index hit.

Edges with weight below MIN_WEIGHT_THRESHOLD are skipped. At most
MAX_EDGES_PER_NODE edges are created (highest-weight first).
