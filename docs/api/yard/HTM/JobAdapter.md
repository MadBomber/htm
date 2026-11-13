# Module HTM::JobAdapter <a id="module-HTM-JobAdapter"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/job_adapter.rb |

Job adapter for pluggable background job backends

Supports multiple job backends to work seamlessly across different application
types (CLI, Sinatra, Rails).

Supported backends:
*   :active_job - Rails ActiveJob (recommended for Rails apps)
*   :sidekiq - Direct Sidekiq integration (recommended for Sinatra apps)
*   :inline - Synchronous execution (recommended for CLI and tests)
*   :thread - Background thread (legacy, for standalone apps)
*   :fiber - Fiber-based concurrency using async gem (recommended for
    I/O-bound jobs)

- **`@see`** `ADR-016:` Async Embedding and Tag Generation

**@example Configure job backend**
```ruby
HTM.configure do |config|
  config.job.backend = :active_job
end
```

**@example Enqueue a job**
```ruby
HTM::JobAdapter.enqueue(HTM::Jobs::GenerateEmbeddingJob, node_id: 123)
```

## Public Class Methods
### `enqueue(job_class, **params)` <a id="method-c-enqueue"></a> <a id="enqueue-class_method"></a>
Enqueue a background job using the configured backend
- **`@param`** `job_class` [Class] Job class to enqueue (must respond to :perform)
- **`@param`** `params` [Hash] Parameters to pass to the job
- **`@raise`** [HTM::Error] If job backend is unknown
- **`@return`** [void]

### `enqueue_parallel(jobs)` <a id="method-c-enqueue_parallel"></a> <a id="enqueue_parallel-class_method"></a>
Execute multiple jobs in parallel using fibers Best for I/O-bound jobs like
LLM API calls
- **`@param`** `jobs` [Array<Array>] Array of [job_class, params] pairs
- **`@return`** [void]

**@example Run embedding and tags jobs in parallel**
```ruby
JobAdapter.enqueue_parallel([
  [GenerateEmbeddingJob, { node_id: 123 }],
  [GenerateTagsJob, { node_id: 123 }]
])
```
