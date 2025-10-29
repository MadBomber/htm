# ADR-016: Async Embedding and Tag Generation with Background Jobs

**Status**: Accepted

**Date**: 2025-10-29

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Context

The initial architecture (ADR-014, ADR-015) proposed synchronous embedding generation before node save, which would add 50-500ms latency to every node creation. For a responsive user experience, we need to:

1. Save nodes immediately (fast response)
2. Generate embeddings asynchronously
3. Generate tags asynchronously
4. Handle failures gracefully without blocking the user

### User Experience Requirements

**Fast Node Creation**:
- User creates a memory/message
- System responds immediately (< 50ms)
- Embedding and tagging happen in background
- User doesn't wait for LLM operations

**Eventual Consistency**:
- Node available immediately for retrieval
- Embedding added when ready (enables vector search)
- Tags added when ready (enables hierarchical navigation)
- System remains usable while jobs are processing

---

## Decision

We will use **async-job** for background processing with two parallel jobs triggered on node creation:

1. **Save node immediately** (no embedding, no tags)
2. **Enqueue `GenerateEmbeddingJob`** to add embedding
3. **Enqueue `GenerateTagsJob`** to extract and add tags

Both jobs have equal priority and run in parallel. Errors are logged but do not block or retry excessively.

---

## Architecture

### Node Creation Flow

```ruby
# 1. User API call
node = htm.add_message("PostgreSQL supports vector search via pgvector")

# 2. Node saved immediately to database
# - content: "PostgreSQL supports vector search via pgvector"
# - speaker: "user"
# - embedding: nil (will be added by job)
# - tags: none (will be added by job)
# Response time: ~10-20ms

# 3. Two async jobs enqueued (non-blocking)
GenerateEmbeddingJob.perform_later(node.id)  # Job 1
GenerateTagsJob.perform_later(node.id)       # Job 2

# 4. Jobs run in background (parallel, same priority)
# - Job 1: Generate embedding via EmbeddingService → Update node.embedding
# - Job 2: Generate tags via TagService → Create Tag records → Create NodeTag associations

# 5. Node is eventually fully enriched
# - Has embedding (enables vector search)
# - Has tags (enables hierarchical navigation)
```

### Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         User Request                         │
│                  add_message(content, ...)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    HTM Main Class                            │
│  - Create Node record (immediate save)                       │
│  - Enqueue GenerateEmbeddingJob                              │
│  - Enqueue GenerateTagsJob                                   │
│  - Return node to user (fast response)                       │
└──────────────┬──────────────────────────┬───────────────────┘
               │                          │
               │ Async                    │ Async
               │ (parallel)               │ (parallel)
               ▼                          ▼
┌──────────────────────────┐  ┌──────────────────────────────┐
│  GenerateEmbeddingJob    │  │    GenerateTagsJob           │
│                          │  │                              │
│  1. Load Node            │  │  1. Load Node                │
│  2. EmbeddingService     │  │  2. Load existing ontology   │
│  3. Generate embedding   │  │  3. TagService               │
│  4. Update node.embedding│  │  4. Extract tags             │
│  5. Log errors           │  │  5. Create Tag records       │
│                          │  │  6. Create NodeTag records   │
│                          │  │  7. Log errors               │
└──────────────────────────┘  └──────────────────────────────┘
```

---

## Implementation

### 1. TagService (New)

Parallel to `EmbeddingService`, handles LLM-based tag extraction:

```ruby
# lib/htm/tag_service.rb
class HTM::TagService
  # Default models for tag extraction
  DEFAULT_MODELS = {
    ollama: 'llama3',
    openai: 'gpt-4o-mini'
  }.freeze

  attr_reader :provider, :model

  # Initialize tag extraction service
  #
  # @param provider [Symbol] LLM provider (:ollama, :openai)
  # @param model [String] Model name
  # @param base_url [String] Base URL for Ollama
  #
  def initialize(provider = :ollama, model: nil, base_url: nil)
    @provider = provider
    @model = model || DEFAULT_MODELS[provider]
    @base_url = base_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
  end

  # Extract hierarchical tags from content
  #
  # @param content [String] Text to analyze
  # @param existing_ontology [Array<String>] Sample of existing tags for context
  # @return [Array<String>] Extracted tag names in format root:level1:level2
  #
  def extract_tags(content, existing_ontology: [])
    prompt = build_extraction_prompt(content, existing_ontology)
    response = call_llm(prompt)
    parse_and_validate_tags(response)
  end

  private

  def build_extraction_prompt(content, ontology_sample)
    ontology_context = if ontology_sample.any?
      sample_tags = ontology_sample.sample([ontology_sample.size, 20].min)
      "Existing ontology includes: #{sample_tags.join(', ')}\n"
    else
      "This is a new ontology - create appropriate hierarchical tags.\n"
    end

    <<~PROMPT
      Extract hierarchical topic tags from the following text.

      #{ontology_context}
      Format: root:level1:level2:level3 (use colons to separate levels)

      Rules:
      - Use lowercase letters, numbers, and hyphens only
      - Maximum depth: 5 levels
      - Return 2-5 tags per text
      - Tags should be reusable and consistent
      - Prefer existing ontology tags when applicable
      - Use hyphens for multi-word terms (e.g., natural-language-processing)

      Text: #{content}

      Return ONLY the topic tags, one per line, no explanations.
    PROMPT
  end

  def call_llm(prompt)
    case @provider
    when :ollama
      call_ollama(prompt)
    when :openai
      call_openai(prompt)
    else
      raise HTM::TagError, "Unknown provider: #{@provider}"
    end
  end

  def call_ollama(prompt)
    require 'net/http'
    require 'json'

    uri = URI("#{@base_url}/api/generate")
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate({
      model: @model,
      prompt: prompt,
      stream: false,
      system: 'You are a precise topic extraction system. Output only topic tags in hierarchical format: root:subtopic:detail',
      options: {
        temperature: 0  # Deterministic output
      }
    })

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise HTM::TagError, "Ollama API error: #{response.code} #{response.message}"
    end

    result = JSON.parse(response.body)
    result['response']
  rescue JSON::ParserError => e
    raise HTM::TagError, "Failed to parse Ollama response: #{e.message}"
  rescue StandardError => e
    raise HTM::TagError, "Failed to call Ollama: #{e.message}"
  end

  def call_openai(prompt)
    require 'net/http'
    require 'json'

    api_key = ENV['OPENAI_API_KEY']
    raise HTM::TagError, "OPENAI_API_KEY not set" unless api_key

    uri = URI('https://api.openai.com/v1/chat/completions')
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{api_key}"
    request.body = JSON.generate({
      model: @model,
      messages: [
        {
          role: 'system',
          content: 'You are a precise topic extraction system. Output only topic tags in hierarchical format: root:subtopic:detail'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0
    })

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise HTM::TagError, "OpenAI API error: #{response.code} #{response.message}"
    end

    result = JSON.parse(response.body)
    result.dig('choices', 0, 'message', 'content')
  rescue JSON::ParserError => e
    raise HTM::TagError, "Failed to parse OpenAI response: #{e.message}"
  rescue StandardError => e
    raise HTM::TagError, "Failed to call OpenAI: #{e.message}"
  end

  def parse_and_validate_tags(response)
    return [] if response.nil? || response.strip.empty?

    # Parse response (one tag per line)
    tags = response.split("\n").map(&:strip).reject(&:empty?)

    # Validate format: lowercase alphanumeric + hyphens + colons
    valid_tags = tags.select do |tag|
      tag =~ /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/
    end

    # Limit depth to 5 levels (4 colons maximum)
    valid_tags.select { |tag| tag.count(':') < 5 }
  end
end
```

### 2. Background Jobs

Using `async-job` gem:

```ruby
# lib/htm/jobs/generate_embedding_job.rb
require 'async/job'

class HTM::GenerateEmbeddingJob < Async::Job
  # Generate embedding for node content and update database
  #
  # @param node_id [Integer] ID of node to process
  #
  def perform(node_id)
    node = HTM::Models::Node.find(node_id)

    # Skip if already has embedding
    return if node.embedding.present?

    # Initialize embedding service
    embedding_service = HTM::EmbeddingService.new(
      :ollama,
      model: ENV['EMBEDDING_MODEL'] || 'nomic-embed-text'
    )

    # Generate embedding
    embedding = embedding_service.embed(node.content)

    # Update node
    node.update!(
      embedding: embedding,
      embedding_dimension: embedding.length
    )

    logger.info("Generated embedding for node #{node_id} (#{embedding.length} dimensions)")

  rescue HTM::EmbeddingError => e
    logger.error("Embedding generation failed for node #{node_id}: #{e.message}")
    # Don't retry - node remains without embedding
  rescue StandardError => e
    logger.error("Unexpected error generating embedding for node #{node_id}: #{e.class} - #{e.message}")
    logger.error(e.backtrace.join("\n"))
  end
end
```

```ruby
# lib/htm/jobs/generate_tags_job.rb
require 'async/job'

class HTM::GenerateTagsJob < Async::Job
  # Extract tags from node content and update database
  #
  # @param node_id [Integer] ID of node to process
  #
  def perform(node_id)
    node = HTM::Models::Node.find(node_id)

    # Skip if already has tags
    return if node.tags.any?

    # Initialize tag service
    tag_service = HTM::TagService.new(
      :ollama,
      model: ENV['TAG_MODEL'] || 'llama3'
    )

    # Get sample of existing ontology for context
    existing_tags = HTM::Models::Tag
      .order('RANDOM()')  # PostgreSQL random sampling
      .limit(50)
      .pluck(:name)

    # Extract tags
    tag_names = tag_service.extract_tags(
      node.content,
      existing_ontology: existing_tags
    )

    # Create tags and associations
    tag_names.each do |tag_name|
      # Find or create tag record
      tag = HTM::Models::Tag.find_or_create_by(name: tag_name)

      # Create association (skip if already exists)
      HTM::Models::NodeTag.create(
        node_id: node.id,
        tag_id: tag.id
      )
    rescue ActiveRecord::RecordNotUnique
      # Tag association already exists, skip
      next
    end

    logger.info("Generated #{tag_names.size} tags for node #{node_id}: #{tag_names.join(', ')}")

  rescue HTM::TagError => e
    logger.error("Tag generation failed for node #{node_id}: #{e.message}")
    # Don't retry - node remains without tags
  rescue StandardError => e
    logger.error("Unexpected error generating tags for node #{node_id}: #{e.class} - #{e.message}")
    logger.error(e.backtrace.join("\n"))
  end
end
```

### 3. HTM Main Class Integration

```ruby
# lib/htm.rb
class HTM
  def add_message(content, speaker: 'user', type: nil, category: nil, importance: 1.0)
    # 1. Save node immediately (no embedding, no tags)
    node = @ltm.add(
      content: content,
      speaker: speaker,
      robot_id: @robot.id,
      type: type,
      category: category,
      importance: importance,
      token_count: @embedding_service.count_tokens(content)
    )

    # 2. Add to working memory
    @working_memory.add(node)

    # 3. Enqueue async jobs (non-blocking)
    GenerateEmbeddingJob.perform_later(node.id)
    GenerateTagsJob.perform_later(node.id)

    # 4. Return immediately
    node
  end
end
```

### 4. Error Handling Class

```ruby
# lib/htm/errors.rb
class HTM
  class Error < StandardError; end
  class EmbeddingError < Error; end
  class TagError < Error; end
  class DatabaseError < Error; end
end
```

---

## Query Behavior with Async Jobs

### Vector Search

Nodes without embeddings are excluded automatically:

```ruby
# lib/htm/long_term_memory.rb
def vector_search(query_embedding:, limit: 10, **filters)
  HTM::Models::Node
    .where.not(embedding: nil)  # Exclude nodes without embeddings
    .where(filters)
    .order(Arel.sql("embedding <=> ?::vector", query_embedding.to_s))
    .limit(limit)
end
```

**Behavior**:
- New node created → Not in vector search results yet
- Embedding job completes → Node appears in vector search results
- Eventual consistency: Node becomes searchable within seconds

### Tag Search

Nodes without tags are excluded implicitly:

```ruby
def nodes_with_tag(tag_name)
  HTM::Models::Node
    .joins(:tags)
    .where(tags: { name: tag_name })
end

def nodes_with_tag_prefix(prefix)
  HTM::Models::Node
    .joins(:tags)
    .where("tags.name LIKE ?", "#{prefix}%")
end
```

**Behavior**:
- New node created → Not in tag-based queries yet
- Tag job completes → Node appears in tag queries
- Eventual consistency: Node becomes navigable within seconds

### Full-Text Search

Works immediately (doesn't depend on embeddings or tags):

```ruby
def fulltext_search(query:, limit: 20)
  HTM::Models::Node
    .where("to_tsvector('english', content) @@ plainto_tsquery('english', ?)", query)
    .order("ts_rank(to_tsvector('english', content), plainto_tsquery('english', ?)) DESC", query)
    .limit(limit)
end
```

---

## Configuration

### Environment Variables

```bash
# Embedding configuration
export EMBEDDING_MODEL=nomic-embed-text  # Ollama model for embeddings
export OLLAMA_URL=http://localhost:11434

# Tag extraction configuration
export TAG_MODEL=llama3  # Ollama model for tag extraction

# Alternative: OpenAI
export OPENAI_API_KEY=sk-...
```

### Async Job Configuration

```ruby
# config/async_job.rb (example)
Async::Job.configure do |config|
  config.backend = :sidekiq  # or :async (in-process), :delayed_job, etc.
  config.queue = :default
  config.retry_limit = 0  # Don't retry (errors are logged)
end
```

---

## Performance Characteristics

### Node Creation (User-Facing)

| Operation | Time | Notes |
|-----------|------|-------|
| Save node to database | ~10ms | Fast INSERT |
| Enqueue 2 jobs | ~5ms | Add to job queue |
| **Total user-facing latency** | **~15ms** | Excellent UX |

### Background Processing (Async)

| Job | Time | Notes |
|-----|------|-------|
| GenerateEmbeddingJob | ~50-100ms | Ollama local |
| GenerateTagsJob | ~500-1000ms | LLM generation + parsing |
| **Total background** | ~1 second | User doesn't wait |

### Eventual Consistency Windows

| Feature | Available After | Notes |
|---------|----------------|-------|
| Full-text search | Immediate | No dependencies |
| Basic retrieval | Immediate | Get by ID, speaker, etc. |
| Vector search | ~100ms | After embedding job |
| Tag navigation | ~1 second | After tag extraction job |

---

## Consequences

### Positive

✅ **Fast response time**: User sees node created in ~15ms
✅ **Non-blocking**: LLM operations don't block user
✅ **Parallel processing**: Embedding and tagging happen simultaneously
✅ **Graceful degradation**: Errors don't prevent node creation
✅ **Scalable**: Job queue can be scaled independently
✅ **Simple error handling**: Just log errors, no complex retry logic
✅ **Eventual consistency**: All features work, just slightly delayed

### Negative

❌ **Eventual consistency**: Small window where features unavailable
❌ **Job queue dependency**: Requires async-job infrastructure
❌ **Debugging complexity**: Errors happen in background, not in request
❌ **State tracking**: Node may be in various states of completion

### Neutral

➡️ **Job framework**: Using async-job (could swap for Sidekiq, etc.)
➡️ **Priority**: Both jobs equal priority (can adjust if needed)
➡️ **Retries**: No automatic retries (errors just logged)

---

## Monitoring and Observability

### Logging Strategy

```ruby
# Successful operations
logger.info("Generated embedding for node #{node_id} (768 dimensions)")
logger.info("Generated 3 tags for node #{node_id}: ai:llm, database:postgresql, performance")

# Errors (no retry)
logger.error("Embedding generation failed for node #{node_id}: Ollama connection refused")
logger.error("Tag generation failed for node #{node_id}: Invalid response format")
```

### Metrics to Track

```ruby
# Example metrics
{
  nodes_created: counter,
  embeddings_generated: counter,
  embeddings_failed: counter,
  tags_generated: counter,
  tags_failed: counter,
  embedding_duration_ms: histogram,
  tag_extraction_duration_ms: histogram,
  job_queue_depth: gauge
}
```

### Health Checks

```ruby
def system_health
  {
    ollama_available: check_ollama_connection,
    job_queue_healthy: check_job_queue_depth,
    recent_failures: count_recent_job_failures
  }
end
```

---

## Future Enhancements

### 1. Progress Tracking (Optional)

```ruby
# Add columns to nodes table
class AddJobStatusToNodes < ActiveRecord::Migration
  add_column :nodes, :embedding_status, :string, default: 'pending'
  add_column :nodes, :tagging_status, :string, default: 'pending'
  add_index :nodes, :embedding_status
  add_index :nodes, :tagging_status
end

# Update in jobs
node.update!(embedding_status: 'completed')
node.update!(tagging_status: 'completed')
```

### 2. Retry with Exponential Backoff

```ruby
# If needed in future
class GenerateEmbeddingJob < Async::Job
  retry_on HTM::EmbeddingError, wait: :exponentially_longer, attempts: 3
end
```

### 3. Batch Processing

```ruby
# Process multiple nodes in one job
class GenerateEmbeddingsBatchJob < Async::Job
  def perform(node_ids)
    nodes = HTM::Models::Node.where(id: node_ids, embedding: nil)
    # Batch embed for efficiency
  end
end
```

### 4. Priority Queue

```ruby
# High-priority nodes processed first
GenerateEmbeddingJob.set(priority: :high).perform_later(important_node_id)
```

---

## Related ADRs

**Supersedes**:
- ADR-014 (Client-Side Embedding) - Replaced with async approach
- ADR-015 (Manual Tagging + Future LLM) - LLM extraction now implemented via TagService

**References**:
- ADR-001 (PostgreSQL Storage)
- ADR-013 (ActiveRecord + Many-to-Many Tags)

---

## Review Notes

**User (Dewayne)**: ✅ Async approach with two parallel jobs. Use async-job. TagService parallel to EmbeddingService.

**Systems Architect**: ✅ Async processing greatly improves UX. Eventual consistency is acceptable trade-off.

**Performance Specialist**: ✅ 15ms user-facing latency vs. 500ms+ synchronous is massive improvement.

**Ruby Expert**: ✅ TagService design mirrors EmbeddingService well. Consistent architecture.

**AI Engineer**: ✅ Parallel embedding and tagging is efficient. LLM operations don't block users.
