# Class HTM::Workflows::RememberWorkflow <a id="class-HTM-Workflows-RememberWorkflow"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/workflows/remember_workflow.rb |

RememberWorkflow orchestrates the parallel processing of node enrichment

Uses simple_flow to manage the dependency graph and parallel execution of
embedding generation, tag extraction, and proposition extraction.

The workflow structure:
    save_node (no deps) -> embedding, tags, propositions (parallel)

**@example Basic usage with fiber concurrency**
```ruby
workflow = HTM::Workflows::RememberWorkflow.new(htm_instance)
node_id = workflow.call(content: "PostgreSQL is great", tags: ["database"])
```

**@example With inline execution (for testing)**
```ruby
workflow = HTM::Workflows::RememberWorkflow.new(htm_instance, concurrency: :threads)
node_id = workflow.call(content: "Test content")
```

## Attributes
### `htm` [R] <a id="attribute-i-htm"></a> <a id="htm-instance_method"></a>
Returns the value of attribute htm.

### `pipeline` [R] <a id="attribute-i-pipeline"></a> <a id="pipeline-instance_method"></a>
Returns the value of attribute pipeline.

## Public Instance Methods
### `call(content:, tags: [], metadata: {})` <a id="method-i-call"></a> <a id="call-instance_method"></a>
Execute the remember workflow
- **`@param`** `content` [String] Content to remember
- **`@param`** `tags` [Array<String>] Manual tags to assign
- **`@param`** `metadata` [Hash] Metadata for the node
- **`@return`** [Integer] Node ID of the created memory

### `execution_plan()` <a id="method-i-execution_plan"></a> <a id="execution_plan-instance_method"></a>
Get execution plan
- **`@return`** [String] Execution plan description

### `initialize(htm, concurrency: :auto)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
Initialize the remember workflow
- **`@param`** `htm` [HTM] HTM instance for the robot
- **`@param`** `concurrency` [Symbol] Concurrency model (:auto, :threads, :async)
- **`@return`** [RememberWorkflow] a new instance of RememberWorkflow

### `to_mermaid()` <a id="method-i-to_mermaid"></a> <a id="to_mermaid-instance_method"></a>
Get visualization of the workflow as Mermaid diagram
- **`@return`** [String] Mermaid diagram source
