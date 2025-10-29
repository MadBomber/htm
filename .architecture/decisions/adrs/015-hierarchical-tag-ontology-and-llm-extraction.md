# ADR-015: Hierarchical Tag Ontology and LLM Extraction

**Status**: ~~Accepted (Manual) / Proposed (LLM)~~ **SUPERSEDED** (2025-10-29)

**Superseded By**: ADR-016 (Async Embedding and Tag Generation)

**Date**: 2025-10-29

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## ⚠️ DECISION SUPERSEDED (2025-10-29)

**This ADR has been superseded by ADR-016.**

**Reason**: The manual-first, LLM-later approach has been replaced with automatic async LLM extraction via `TagService` and background jobs. Key changes:
- LLM tag extraction is now implemented (not future)
- Runs automatically via `GenerateTagsJob` background job
- Uses `TagService` class (parallel to `EmbeddingService`)
- No manual tagging step required

See [ADR-016: Async Embedding and Tag Generation](./016-async-embedding-and-tag-generation.md) for current architecture.

---

## Context (Historical)

HTM's tagging system enables organizing memories with hierarchical, namespace-based tags. Following the removal of database-side LLM extraction (ADR-012 reversal), the architecture for tag generation and ontology management needs clear documentation.

### Current State

**What Exists**:
- Many-to-many tagging via `nodes_tags` join table (ADR-013)
- Hierarchical namespace format: `root:level1:level2`
- Manual tag assignment via `add_tag()` method
- Tag queries and relationship analysis

**What's Missing**:
- Automatic tag extraction from content
- LLM-driven topic identification
- Tag normalization and merging
- Ontology evolution strategies

### The Ontology Vision

**Emerging Knowledge Structure**:
- Tags create navigable hierarchies across all memories
- Multiple classification paths for same content
- Complements vector embeddings (symbolic + sub-symbolic)
- Reveals patterns in knowledge base over time

**Example Ontology**:
```
ai:llm:embeddings
ai:llm:prompts
ai:rag:retrieval
database:postgresql:indexes
database:postgresql:pgvector
programming:ruby:activerecord
programming:ruby:gems
performance:optimization:database
```

---

## Decision

HTM will support **hierarchical tags with manual assignment now** and **LLM-driven extraction in the future**, using a **client-side extraction approach** that learns from existing ontology.

### Phase 1: Manual Tagging (Current - ACCEPTED)

**Implementation**:
```ruby
# Add single tag
ltm.add_tag(node_id: node.id, tag: 'database:postgresql')

# Add multiple tags during node creation
htm.add_message(
  "PostgreSQL with pgvector provides vector search",
  tags: [
    'database:postgresql',
    'database:pgvector',
    'ai:embeddings'
  ]
)

# Query nodes by tag
nodes = ltm.nodes_with_tag('database:postgresql')

# Query by tag prefix (hierarchical)
nodes = ltm.nodes_with_tag_prefix('database:')  # All database-related
```

**Current API** (in `lib/htm/long_term_memory.rb`):
```ruby
class HTM::LongTermMemory
  # Add tag to existing node
  def add_tag(node_id:, tag:)
    tag_record = HTM::Models::Tag.find_or_create_by(name: tag)
    HTM::Models::NodeTag.create(
      node_id: node_id,
      tag_id: tag_record.id
    )
  end

  # Get all tags for a node
  def node_topics(node_id)
    HTM::Models::Tag
      .joins(:node_tags)
      .where(nodes_tags: { node_id: node_id })
      .order(:name)
      .pluck(:name)
  end

  # Find related topics by shared nodes
  def topic_relationships(min_shared_nodes: 2, limit: 50)
    result = ActiveRecord::Base.connection.select_all(
      <<~SQL
        SELECT t1.name AS topic1, t2.name AS topic2,
               COUNT(DISTINCT nt1.node_id) AS shared_nodes
        FROM tags t1
        JOIN nodes_tags nt1 ON t1.id = nt1.tag_id
        JOIN nodes_tags nt2 ON nt1.node_id = nt2.node_id
        JOIN tags t2 ON nt2.tag_id = t2.id
        WHERE t1.name < t2.name
        GROUP BY t1.name, t2.name
        HAVING COUNT(DISTINCT nt1.node_id) >= #{min_shared_nodes}
        ORDER BY shared_nodes DESC
        LIMIT #{limit}
      SQL
    )
    result.to_a
  end
end
```

### Phase 2: LLM Extraction (Future - PROPOSED)

**Client-Side Extraction Service**:
```ruby
class HTM::TopicExtractor
  def initialize(llm_provider: :ollama, model: 'llama3', base_url: nil)
    @provider = llm_provider
    @model = model
    @base_url = base_url || ENV['OLLAMA_URL'] || 'http://localhost:11434'
  end

  # Extract hierarchical topics from content
  # @param content [String] Text to analyze
  # @param existing_ontology [Array<String>] Current tags for context
  # @return [Array<String>] Extracted topic tags
  def extract_topics(content, existing_ontology: [])
    prompt = build_extraction_prompt(content, existing_ontology)
    response = call_llm(prompt)
    parse_and_validate_topics(response)
  end

  private

  def build_extraction_prompt(content, ontology_sample)
    ontology_context = if ontology_sample.any?
      "Existing ontology includes: #{ontology_sample.sample(20).join(', ')}"
    else
      "This is a new ontology - create appropriate hierarchical tags."
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
      system: 'You are a precise topic extraction system. Output only topic tags in hierarchical format: root:subtopic:detail'
    })

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)
    result['response']
  end

  def parse_and_validate_topics(response)
    # Parse response (one tag per line)
    tags = response.split("\n").map(&:strip).reject(&:empty?)

    # Validate format: lowercase alphanumeric + hyphens + colons
    valid_tags = tags.select do |tag|
      tag =~ /^[a-z0-9\-]+(:[a-z0-9\-]+)*$/
    end

    # Limit depth to 5 levels
    valid_tags.select { |tag| tag.count(':') < 5 }
  end
end
```

**Integration with HTM**:
```ruby
class HTM
  def add_message(content, speaker: 'user', auto_tag: false, **options)
    # Generate embedding
    embedding = @embedding_service.embed(content)

    # Extract topics if auto_tag enabled
    tags = if auto_tag && @topic_extractor
      existing_ontology = @ltm.all_tags  # Sample for context
      @topic_extractor.extract_topics(content, existing_ontology: existing_ontology)
    else
      options[:tags] || []
    end

    # Create node
    node = @ltm.add(
      content: content,
      speaker: speaker,
      robot_id: @robot.id,
      embedding: embedding,
      **options
    )

    # Add tags
    tags.each do |tag|
      @ltm.add_tag(node_id: node.id, tag: tag)
    end

    node
  end
end
```

**Usage**:
```ruby
# Enable auto-tagging
htm = HTM.new(
  robot_name: 'CodeBot',
  auto_tag: true,
  topic_extractor: HTM::TopicExtractor.new(:ollama, model: 'llama3')
)

# Topics automatically extracted and added
node = htm.add_message("PostgreSQL supports vector similarity search via pgvector")
# Auto-generated tags: database:postgresql, database:pgvector, ai:vectors
```

---

## Rationale

### Why Hierarchical Tags?

**Structure and Flexibility**:
- ✅ Multiple abstraction levels: `ai` → `ai:llm` → `ai:llm:embeddings`
- ✅ Multiple classification paths: Same content can be `database:postgresql` AND `performance:optimization`
- ✅ Browsable hierarchy: Navigate from broad to specific
- ✅ Pattern recognition: See knowledge base emphasis by root tags

**Complementary to Vector Search**:
```ruby
# Filtered semantic search
results = ltm.search(
  query_embedding: query_embedding,
  tag_filter: 'database:postgresql'  # Limit search scope by tag
)

# Discover cross-domain connections
similar_nodes = ltm.vector_search(node.embedding)
# Node about "database optimization" finds similar "ai model training"
# (both are optimization problems)
```

### Why Manual First, LLM Later?

**Start Simple** (Current):
- ✅ No LLM dependency for basic tagging
- ✅ User controls ontology evolution
- ✅ Predictable behavior
- ✅ Works offline

**Add Intelligence** (Future):
- ✅ Consistent automated tagging
- ✅ Discovers implicit topics
- ✅ Learns from existing ontology
- ✅ Scales to large knowledge bases

### Why Client-Side LLM Extraction?

Following ADR-014 pattern (client-side embedding):
- ✅ No database extension dependencies
- ✅ Easy debugging (Ruby stack traces)
- ✅ Flexible prompt engineering
- ✅ Can provide ontology context to LLM
- ✅ Testable and mockable

---

## Tag Hierarchy Guidelines

### Naming Conventions

**Format**: `root:level1:level2:level3:level4`

**Rules**:
- Lowercase letters, numbers, hyphens only
- Colon separates hierarchy levels
- Maximum 5 levels deep
- Use hyphens for multi-word terms: `natural-language-processing`

**Examples**:
```
ai:llm:providers:anthropic
ai:llm:providers:openai
ai:llm:techniques:prompting
ai:llm:techniques:rag
ai:embeddings:models:ollama
ai:embeddings:models:openai
database:postgresql:extensions:pgvector
database:postgresql:extensions:pg-trgm
database:postgresql:performance:indexes
programming:ruby:gems:activerecord
programming:ruby:gems:pg
programming:ruby:testing:minitest
performance:optimization:database
performance:optimization:algorithms
```

### Root Category Suggestions

Common root tags for software knowledge bases:

- `ai` - Artificial intelligence, ML, LLM
- `database` - Databases, SQL, NoSQL
- `programming` - Languages, frameworks, libraries
- `architecture` - System design, patterns
- `performance` - Optimization, profiling
- `security` - Authentication, encryption, vulnerabilities
- `devops` - Deployment, CI/CD, infrastructure
- `testing` - Unit tests, integration tests, QA
- `documentation` - README, API docs, tutorials
- `tools` - CLI tools, IDEs, utilities
- `concepts` - General CS concepts, algorithms
- `business` - Domain logic, requirements, processes

### Tag Relationships

**Parent-Child** (via prefix):
```ruby
# Get all children of 'ai:llm'
tags = Tag.where("name LIKE 'ai:llm:%'")
# Returns: ai:llm:embeddings, ai:llm:prompts, ai:llm:providers, etc.
```

**Siblings** (same prefix):
```ruby
# Get siblings of 'ai:llm:embeddings'
parent = 'ai:llm'
tags = Tag.where("name LIKE '#{parent}:%' AND name NOT LIKE '#{parent}:%:%'")
# Returns: ai:llm:embeddings, ai:llm:prompts, ai:llm:providers
```

**Related Topics** (co-occurrence):
```ruby
# Find topics that frequently appear together
ltm.topic_relationships(min_shared_nodes: 5)
# Example: 'database:postgresql' often appears with 'performance:optimization'
```

---

## Ontology Evolution Strategies

### 1. Tag Normalization

**Problem**: Similar tags with inconsistent naming
- `database:postgres` vs `database:postgresql`
- `ai:large-language-models` vs `ai:llm`

**Solution**: Merge tags
```ruby
class TagMerger
  def merge(from_tag:, to_tag:)
    from_record = Tag.find_by(name: from_tag)
    to_record = Tag.find_or_create_by(name: to_tag)

    # Update all node associations
    NodeTag.where(tag_id: from_record.id).update_all(tag_id: to_record.id)

    # Delete old tag
    from_record.destroy
  end
end

# Usage
merger = TagMerger.new
merger.merge(from_tag: 'database:postgres', to_tag: 'database:postgresql')
```

### 2. Tag Splitting

**Problem**: Tag too broad, needs sub-categories
- `programming` → `programming:ruby`, `programming:python`

**Solution**: Retroactive sub-categorization
```ruby
class TagSplitter
  def split(broad_tag:, specific_tags:)
    nodes = Node.joins(:tags).where(tags: { name: broad_tag })

    nodes.each do |node|
      # LLM determines which specific tag(s) apply
      specific = determine_specific_tags(node.content, specific_tags)

      specific.each do |tag|
        ltm.add_tag(node_id: node.id, tag: tag)
      end

      # Optionally remove broad tag
      ltm.remove_tag(node_id: node.id, tag: broad_tag)
    end
  end
end
```

### 3. Orphan Tag Detection

**Problem**: Single-use tags clutter ontology

**Solution**: Identify and consolidate
```ruby
class OntologyAnalyzer
  def find_orphans(min_usage: 2)
    Tag.joins(:node_tags)
       .group('tags.id')
       .having('COUNT(node_tags.id) < ?', min_usage)
       .pluck(:name)
  end

  def suggest_merges
    orphans = find_orphans
    # Use LLM or string similarity to suggest merge candidates
  end
end
```

### 4. Ontology Visualization

**Problem**: Hard to see structure of large ontology

**Solution**: Generate hierarchy tree
```ruby
class OntologyVisualizer
  def render_tree(root: nil)
    tags = root ? Tag.where("name LIKE '#{root}:%'") : Tag.all
    build_tree(tags)
  end

  private

  def build_tree(tags)
    tree = {}
    tags.each do |tag|
      parts = tag.name.split(':')
      insert_into_tree(tree, parts)
    end
    tree
  end
end

# Output:
# ai/
#   llm/
#     embeddings/ (5 nodes)
#     prompts/ (12 nodes)
#   rag/
#     retrieval/ (8 nodes)
```

---

## Consequences

### Positive

✅ **Structured navigation**: Browse memories by category hierarchy
✅ **Multiple perspectives**: Same content tagged from different angles
✅ **Complementary to vectors**: Symbolic + sub-symbolic retrieval
✅ **Emergent ontology**: Knowledge structure evolves with content
✅ **Pattern recognition**: See knowledge base emphasis
✅ **Cross-domain discovery**: Find unexpected connections
✅ **Manual control**: User directs ontology evolution (Phase 1)
✅ **Automatic extraction**: LLM discovers topics (Phase 2)
✅ **Learning ontology**: LLM uses existing tags for consistency

### Negative

❌ **Manual effort**: Phase 1 requires manual tagging (time-consuming)
❌ **Consistency**: Manual tagging prone to inconsistencies
❌ **LLM cost**: Phase 2 requires LLM calls (OpenAI cost or Ollama latency)
❌ **Quality variation**: LLM may generate suboptimal tags
❌ **Maintenance**: Ontology needs periodic cleanup/consolidation

### Neutral

➡️ **Schema complexity**: Many-to-many adds join table queries
➡️ **Storage overhead**: Tags stored separately from nodes
➡️ **Configuration**: LLM settings for topic extraction

---

## Performance Considerations

### Query Patterns

**Find nodes by tag**:
```sql
-- Optimized with idx_nodes_tags_tag_id
SELECT n.*
FROM nodes n
JOIN nodes_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name = 'database:postgresql';
```

**Find nodes by tag prefix** (hierarchical):
```sql
-- Uses idx_tags_name_pattern for LIKE with text_pattern_ops
SELECT n.*
FROM nodes n
JOIN nodes_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name LIKE 'ai:llm:%';
```

**Combined vector + tag search**:
```sql
-- Most powerful: semantic similarity within category
SELECT n.*, n.embedding <=> $1::vector AS distance
FROM nodes n
JOIN nodes_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name LIKE 'database:%'
  AND n.embedding IS NOT NULL
ORDER BY distance
LIMIT 10;
```

### LLM Extraction Latency (Future)

| Operation | Time | Notes |
|-----------|------|-------|
| Extract topics (Ollama) | ~500ms | LLM generation time |
| Extract topics (OpenAI) | ~200ms | Network + API processing |
| Tag insertion | ~5ms | Per tag (database INSERT) |
| **Total per node** | ~550ms | Ollama local |

**Optimization**: Batch extraction for multiple nodes
```ruby
# Extract topics for 10 nodes in one LLM call
topics_batch = topic_extractor.extract_topics_batch(nodes.map(&:content))
```

---

## Future Enhancements

### 1. Tag Confidence Scores

```ruby
# Store confidence with tag association
class AddConfidenceToNodesTags < ActiveRecord::Migration
  add_column :nodes_tags, :confidence, :real, default: 1.0
end

# Usage
ltm.add_tag(node_id: node.id, tag: 'database:postgresql', confidence: 0.95)
```

### 2. Ontology Templates

```ruby
# Pre-defined ontology templates for domains
class OntologyTemplate
  RUBY_GEMS = {
    root: 'programming:ruby:gems',
    tags: [
      'programming:ruby:gems:activerecord',
      'programming:ruby:gems:sinatra',
      'programming:ruby:gems:rails'
    ]
  }

  def apply(template_name)
    template = const_get(template_name)
    template[:tags].each do |tag|
      Tag.find_or_create_by(name: tag)
    end
  end
end
```

### 3. Tag Synonyms

```ruby
# Map synonyms to canonical tags
class TagSynonym < ActiveRecord::Base
  belongs_to :canonical_tag, class_name: 'Tag'
end

# When user tags with 'db', map to 'database'
TagSynonym.create(synonym: 'db', canonical_tag: 'database')
```

### 4. Batch Topic Extraction

```ruby
# Extract topics for multiple nodes efficiently
def extract_topics_batch(nodes)
  combined_prompt = build_batch_prompt(nodes)
  response = call_llm(combined_prompt)
  parse_batch_response(response, nodes)
end
```

### 5. Ontology Import/Export

```ruby
# Export ontology to YAML for sharing
class OntologyExporter
  def export
    {
      version: 1,
      exported_at: Time.current,
      tags: Tag.all.map { |t| { name: t.name, usage_count: t.nodes.count } }
    }.to_yaml
  end

  def import(yaml)
    data = YAML.load(yaml)
    data[:tags].each do |tag_data|
      Tag.find_or_create_by(name: tag_data[:name])
    end
  end
end
```

---

## Related ADRs

- [ADR-013: ActiveRecord ORM and Many-to-Many Tagging](./013-activerecord-orm-and-many-to-many-tagging.md) - Database schema
- [ADR-012: LLM-Driven Ontology (PARTIALLY SUPERSEDED)](./012-llm-driven-ontology-topic-extraction.md) - Previous database-side approach
- [ADR-014: Client-Side Embedding Generation](./014-client-side-embedding-generation-workflow.md) - Parallel pattern for LLM extraction

---

## Review Notes

**AI Engineer**: ✅ Hierarchical tags + LLM extraction is powerful. Client-side approach provides flexibility.

**Knowledge Engineer**: ✅ Ontology evolution strategies are essential. Tag normalization will be critical.

**Ruby Expert**: ✅ Manual first, LLM later is pragmatic. Good use of ActiveRecord associations.

**Database Architect**: ✅ Indexes support hierarchical queries well. LIKE with pattern ops is efficient.

**Systems Architect**: ✅ Complementary to vector search. Provides structure that embeddings lack.
