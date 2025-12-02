# Module: HTM::JobAdapter
    

Job adapter for pluggable background job backends

Supports multiple job backends to work seamlessly across different application
types (CLI, Sinatra, Rails).

Supported backends:
*   :active_job - Rails ActiveJob (recommended for Rails apps)
*   :sidekiq - Direct Sidekiq integration (recommended for Sinatra apps)
*   :inline - Synchronous execution (recommended for CLI and tests)
*   :thread - Background thread (legacy, for standalone apps)

**@see** [] Async Embedding and Tag Generation


**@example**
```ruby
HTM.configure do |config|
  config.job_backend = :active_job
end
```
**@example**
```ruby
HTM::JobAdapter.enqueue(HTM::Jobs::GenerateEmbeddingJob, node_id: 123)
```
# Class Methods
## enqueue(job_class , **params ) [](#method-c-enqueue)
Enqueue a background job using the configured backend
**@param** [Class] Job class to enqueue (must respond to :perform)

**@param** [Hash] Parameters to pass to the job

**@raise** [HTM::Error] If job backend is unknown

**@return** [void] 


