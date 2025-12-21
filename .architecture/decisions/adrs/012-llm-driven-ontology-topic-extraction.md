# ADR-012: LLM-Driven Ontology Topic Extraction

**Status**: ~~Accepted~~ **PARTIALLY SUPERSEDED** (2025-10-27)

**Date**: 2025-10-26

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## ⚠️ IMPLEMENTATION STATUS (2025-10-27)

**Database-side topic extraction via pgai has been removed** following the reversal of ADR-011.

**What Remains**:
- The ontology concept (hierarchical topics in `root:level1:level2` format)
- Database schema support (tags table, ontology views)
- Manual topic tagging capability

**What Was Removed**:
- Automatic LLM-driven topic extraction via pgai triggers
- Database-side LLM calls using `ai.ollama_generate()`
- Automatic topic generation on INSERT/UPDATE

**Future Consideration**: Client-side LLM topic extraction may be implemented in the future, but the database-side approach proved impractical due to pgai installation issues (see ADR-011 reversal).

**Related Change (2025-10-28)**: The TimescaleDB extension was also removed from HTM as it was not providing sufficient value for proof-of-concept applications. See [ADR-001](001-use-postgresql-timescaledb-storage.md) for details.

---

## Original Quick Summary (Historical)

HTM uses **LLM-driven hierarchical topic extraction** via pgai database triggers to automatically generate ontological tags from node content, creating an emergent knowledge structure.

**Why**: Automatic topic extraction builds a browsable ontology that complements vector embeddings, enabling both structured navigation and semantic discovery. Database-side extraction via pgai follows the same proven pattern as embedding generation (ADR-011).

**Impact**: Nodes automatically tagged with hierarchical topics (e.g., `database:postgresql:performance`), enabling ontology-based navigation alongside vector similarity search.

---

## Context

### Problem: Limited Content Organization

HTM currently provides two organization mechanisms:

1. **Vector embeddings** (ADR-011): Semantic similarity search
   - Excellent for: "Find things like this"
   - Limitation: No visible structure, discovery-only

2. **Flat category field**: Single-level classification
   - Simple but limiting: Cannot represent hierarchies
   - Inconsistent: Manual categorization prone to errors
   - Redundant: Duplicates root-level topic information

### The Ontology Gap

**Symbolic vs. Sub-symbolic Retrieval**:

| Aspect | Vector Embeddings (Sub-symbolic) | Ontological Tags (Symbolic) |
|--------|----------------------------------|----------------------------|
| **Nature** | Implicit semantic representation | Explicit hierarchical structure |
| **Structure** | No visible structure | Browsable hierarchy |
| **Retrieval** | Fuzzy, associative | Precise, categorical |
| **Use Case** | "Find similar content" | "Show me all about X" |
| **Interpretability** | Opaque numbers | Clear semantic meaning |

**They are complementary, not redundant**:
- Tags = Vision (see the structure)
- Embeddings = Intuition (feel the similarity)

### Hierarchical Topics Concept

Format: `root:level1:level2:level3...`

Examples:
```
database:postgresql:timescaledb:hypertables
database:postgresql:pgvector:indexes
ai:embeddings:ollama:nomic-embed-text
ai:llm:providers:anthropic
programming:ruby:gems:htm
performance:optimization:database
```

Benefits:
- **Multiple classification paths**: Same content can have multiple topic hierarchies
- **Browsable structure**: Navigate from broad to specific
- **Semantic relationships**: Hierarchy encodes is-a relationships
- **Machine-readable**: Colon-separated format enables programmatic processing

---

## Decision

We will implement **automatic LLM-driven topic extraction** using pgai database triggers, following the same architectural pattern as embedding generation (ADR-011).

### Implementation Strategy

**1. Database Trigger for Topic Extraction**

```sql
CREATE OR REPLACE FUNCTION extract_ontology_topics()
RETURNS TRIGGER AS $$
DECLARE
  topic_provider TEXT;
  topic_model TEXT;
  base_url TEXT;
  llm_prompt TEXT;
  llm_response TEXT;
  extracted_topics TEXT[];
  topic TEXT;
BEGIN
  -- Get configuration from session variables
  topic_provider := COALESCE(current_setting('htm.topic_provider', true), 'ollama');
  topic_model := COALESCE(current_setting('htm.topic_model', true), 'llama3');
  base_url := COALESCE(current_setting('htm.topic_base_url', true), 'http://localhost:11434');

  -- Build prompt for LLM
  llm_prompt := 'Extract hierarchical topic tags from this text.
Format as colon-separated paths (e.g., database:postgresql:performance).
Use lowercase with hyphens for multi-word terms.
Return ONLY the topic tags, one per line, no explanations.
Maximum depth: 5 levels.

Text: ' || NEW.value;

  -- Call LLM via pgai to extract topics
  IF topic_provider = 'ollama' THEN
    llm_response := ai.ollama_generate(
      topic_model,
      llm_prompt,
      system_prompt => 'You are a precise topic extraction system. Output only topic tags in the format root:subtopic:detail.',
      host => base_url
    )->>'response';
  END IF;

  -- Parse response and insert validated topics into tags table
  extracted_topics := string_to_array(trim(llm_response), E'\n');

  FOREACH topic IN ARRAY extracted_topics LOOP
    topic := trim(topic);
    IF topic ~ '^[a-z0-9\-]+(:[a-z0-9\-]+)*$' THEN
      INSERT INTO tags (node_id, tag, created_at)
      VALUES (NEW.id, topic, CURRENT_TIMESTAMP)
      ON CONFLICT (node_id, tag) DO NOTHING;
    END IF;
  END LOOP;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Topic extraction failed for node %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER nodes_extract_topics
  AFTER INSERT OR UPDATE OF value ON nodes
  FOR EACH ROW
  EXECUTE FUNCTION extract_ontology_topics();
```

**2. Configuration via Session Variables**

```ruby
# In LongTermMemory#initialize
def configure_topic_settings(conn)
  provider = ENV.fetch('HTM_TOPIC_PROVIDER', 'ollama')
  model = ENV.fetch('HTM_TOPIC_MODEL', 'llama3')
  base_url = ENV.fetch('HTM_TOPIC_BASE_URL', 'http://localhost:11434')

  conn.exec_params("SELECT set_config('htm.topic_provider', $1, false)", [provider])
  conn.exec_params("SELECT set_config('htm.topic_model', $1, false)", [model])
  conn.exec_params("SELECT set_config('htm.topic_base_url', $1, false)", [base_url])
end
```

**3. Environment Variables**

```bash
# .envrc
export HTM_TOPIC_PROVIDER=ollama
export HTM_TOPIC_MODEL=llama3
export HTM_TOPIC_BASE_URL=http://localhost:11434
```

**4. Ontology Exploration Views**

```sql
-- View the ontology structure
CREATE OR REPLACE VIEW ontology_structure AS
SELECT
  split_part(tag, ':', 1) AS root_topic,
  split_part(tag, ':', 2) AS level1_topic,
  split_part(tag, ':', 3) AS level2_topic,
  tag AS full_path,
  COUNT(DISTINCT node_id) AS node_count
FROM tags
WHERE tag ~ '^[a-z0-9\-]+(:[a-z0-9\-]+)*$'
GROUP BY tag
ORDER BY root_topic, level1_topic, level2_topic;

-- View topic relationships (co-occurrence)
CREATE OR REPLACE VIEW topic_relationships AS
SELECT
  t1.tag AS topic1,
  t2.tag AS topic2,
  COUNT(DISTINCT t1.node_id) AS shared_nodes
FROM tags t1
JOIN tags t2 ON t1.node_id = t2.node_id AND t1.tag < t2.tag
GROUP BY t1.tag, t2.tag
HAVING COUNT(DISTINCT t1.node_id) >= 2
ORDER BY shared_nodes DESC;
```

---

## Rationale

### Why LLM-Driven Extraction?

**Consistency**:
- LLM applies uniform reasoning about topic hierarchies
- No human inconsistency in categorization
- Same text always produces same topics (with temperature=0)

**Depth**:
- Identifies topics at multiple abstraction levels simultaneously
- Captures nuanced semantic relationships
- Represents complex subjects with multiple classification paths

**Discovery**:
- Finds classifications humans might miss
- Identifies cross-domain connections
- Reveals implicit semantic structure

**Evolution**:
- Ontology emerges organically from collective knowledge
- No manual taxonomy maintenance
- Adapts to new domains automatically

### Why Database-Side via pgai?

Following the proven pattern from ADR-011 (embedding generation):

**Performance**:
- No Ruby HTTP overhead
- Connection reuse to LLM provider
- Parallel execution via connection pool

**Simplicity**:
- Automatic on INSERT/UPDATE
- No application-side topic management
- Fewer bugs (can't forget to extract topics)

**Consistency**:
- Same LLM model for all operations
- Centralized configuration
- Automatic for all nodes

### Complementary to Vector Embeddings

**Use Both Together**:

1. **Filtered Similarity**: "Find similar nodes, but only within `database:postgresql`"
   - Topic filtering provides scope
   - Embedding search finds semantic matches within scope

2. **Cross-Topic Discovery**: "This node is about database performance, find similar concepts in other domains"
   - Embedding search finds semantically similar concepts
   - Topic tags reveal they're in unexpected domains (e.g., `ai:model-optimization`)

3. **Ontology Validation**:
   - If nodes with very different topics have similar embeddings
   - Suggests ontology might need refinement
   - Indicates concepts are more related than tags suggest

---

## Consequences

### Positive

- **Emergent ontology**: Knowledge structure discovered through AI analysis
- **Automatic tagging**: No manual categorization required
- **Hierarchical navigation**: Browse from broad to specific
- **Multi-perspective**: Same content tagged from different angles
- **Complementary to embeddings**: Symbolic + sub-symbolic retrieval
- **Pattern recognition**: Ontology reveals knowledge base emphasis
- **Cross-pollination**: Unexpected connections across topics
- **Consistency**: LLM applies uniform topic extraction logic

### Negative

- **LLM dependency**: Requires running LLM (Ollama/OpenAI)
- **Cost**: API calls for topic extraction (if using OpenAI)
- **Latency**: LLM call adds time to INSERT operations
- **Quality variation**: LLM mistakes in topic extraction
- **Ontology churn**: Inconsistent topics if LLM behavior changes
- **Debugging complexity**: Topic extraction errors in database triggers

### Neutral

- **Configuration**: Environment variables for topic settings
- **Storage**: Topics stored in existing tags table
- **Category field**: Becomes redundant with root topics (future: remove)

---

## Migration Path

### For New Installations

```bash
# 1. Set environment variables
export HTM_TOPIC_PROVIDER=ollama
export HTM_TOPIC_MODEL=llama3
export HTM_TOPIC_BASE_URL=http://localhost:11434

# 2. Run migrations
HTM::Database.migrate

# 3. Use HTM normally - topics extracted automatically!
htm.add_node('memory_001', 'PostgreSQL with TimescaleDB handles time-series data efficiently')
# Topics automatically extracted: database:postgresql, database:timescaledb, performance:time-series
```

### For Existing Installations

```bash
# 1. Run migration to add topic extraction trigger
HTM::Database.migrate

# 2. (Optional) Re-extract topics for existing nodes
psql $HTM_DATABASE__URL -c "UPDATE nodes SET value = value;"
# Triggers topic extraction for all existing nodes
```

---

## Risks and Mitigations

### Risk: LLM Produces Inconsistent Topics

**Likelihood**: Medium (LLM output varies)

**Impact**: Medium (ontology quality degrades)

**Mitigation**:
- Use temperature=0 for deterministic output
- Validate topic format with regex before inserting
- Log invalid topics as warnings
- Provide ontology refinement tools (future)

### Risk: Topic Extraction Fails

**Likelihood**: Medium (LLM downtime, errors)

**Impact**: Low (node insert succeeds without topics)

**Mitigation**:
- Exception handler in trigger (warn but don't fail)
- Retry logic for transient failures (future)
- Batch re-extraction for failed nodes (future)

### Risk: Performance Degradation on Bulk Inserts

**Likelihood**: High (LLM call per node)

**Impact**: High (batch operations much slower)

**Mitigation**:
- Disable trigger for bulk imports (ALTER TABLE ... DISABLE TRIGGER)
- Batch topic extraction after import
- Document bulk import best practices

### Risk: Ontology Quality Issues

**Likelihood**: Medium (LLM interpretation varies)

**Impact**: Medium (navigation less useful)

**Mitigation**:
- Provide ontology visualization tools
- Enable manual topic correction/refinement
- Ontology review and consolidation process (future)
- Allow providing existing ontology context to LLM (future)

---

## Future Enhancements

### 1. Ontology-Aware Extraction

```sql
-- Provide existing ontology to LLM for consistency
llm_prompt := 'Existing topics in ontology: ' || existing_topics_summary || '

Extract hierarchical topics for this text...';
```

### 2. Topic Confidence Scores

```sql
-- Store confidence alongside topics
ALTER TABLE tags ADD COLUMN confidence REAL;
INSERT INTO tags (node_id, tag, confidence) VALUES (...);
```

### 3. Ontology Refinement Tools

```ruby
class OntologyRefiner
  def suggest_merges    # Identify similar topic branches to merge
  def detect_orphans    # Find single-use topics to consolidate
  def validate_hierarchy # Check for hierarchy inconsistencies
end
```

### 4. Category Field Removal

```sql
-- Remove redundant category field
ALTER TABLE nodes DROP COLUMN category;

-- Derive category from root topic
CREATE VIEW nodes_with_category AS
SELECT *, split_part(tags.tag, ':', 1) AS category
FROM nodes
LEFT JOIN tags ON nodes.id = tags.node_id;
```

### 5. Batch Topic Extraction Mode

```sql
-- Async topic extraction for performance
CREATE TABLE topic_extraction_queue (
  node_id BIGINT,
  status TEXT,
  created_at TIMESTAMP
);

-- Background worker processes queue
```

---

## Alternatives Comparison

| Approach | Quality | Performance | Maintainability | Decision |
|----------|---------|-------------|-----------------|----------|
| **LLM Database Triggers** | **High** | **Medium** | **Good** | **ACCEPTED** |
| Manual categorization | Low | Fast | Poor | Rejected |
| Keyword extraction | Medium | Fast | Good | Rejected |
| Topic modeling (LDA) | Medium | Slow | Poor | Rejected |
| Ruby-side LLM extraction | High | Slow | Medium | Rejected |

---

## References

- [ontology_notes.md](../../../ontology_notes.md) - Detailed ontology design discussion
- [ADR-011: Database-Side Embedding Generation](011-database-side-embedding-generation-with-pgai.md) - Same architectural pattern
- [pgai Documentation](https://github.com/timescale/pgai) - LLM integration via pgai
- [Knowledge Graph Concepts](https://en.wikipedia.org/wiki/Ontology_(information_science))
- [Folksonomy](https://en.wikipedia.org/wiki/Folksonomy) - Emergent classification systems

---

## Review Notes

**AI Engineer**: LLM-driven ontology is the right approach. Emergent structure beats manual taxonomy.

**Database Architect**: Following ADR-011 pattern is smart. Consider async extraction for bulk operations.

**Knowledge Engineer**: Hierarchical topics + vector embeddings = powerful combination. Validates ontology with similarity.

**Systems Architect**: Database-side extraction maintains consistency. Separation of concerns.

**Ruby Developer**: Environment variable configuration is clean. Session variables pattern works well.

---

## Related ADRs

Updates:
- [ADR-011: Database-Side Embedding Generation](011-database-side-embedding-generation-with-pgai.md) - Same architectural pattern

Future:
- ADR-013: Category Field Removal (pending - after ontology validation)

---

## Reversal Details (2025-10-27)

### Why the Partial Reversal?

Following the reversal of ADR-011, the pgai-based automatic topic extraction was also removed because:

1. **Dependency on pgai**: Topic extraction relied on `ai.ollama_generate()` function from pgai
2. **Installation Issues**: Same pgai installation problems that affected embedding generation
3. **Consistency**: Better to have a unified approach (no database-side LLM calls)
4. **Architectural Simplicity**: Avoid split between database-side and client-side processing

### What Remains

The **ontology concept is still valid and valuable**:
- Tags table supports hierarchical topic paths (`root:level1:level2`)
- Ontology structure views provide navigation
- Manual topic tagging works
- Applications can still implement topic extraction client-side

### Future Direction: Client-Side Topic Extraction

A future implementation may add client-side LLM-driven topic extraction:

```ruby
class TopicExtractor
  def initialize(llm_provider: :ollama, model: 'llama3')
    @provider = llm_provider
    @model = model
  end

  def extract_topics(content)
    # Generate prompt
    prompt = build_extraction_prompt(content)

    # Call LLM (Ruby-side)
    response = call_llm(prompt)

    # Parse and validate topics
    parse_topics(response)
  end

  private

  def build_extraction_prompt(content)
    <<~PROMPT
      Extract hierarchical topic tags from this text.
      Format: root:level1:level2 (lowercase, hyphens for spaces)
      Maximum depth: 5 levels

      Text: #{content}
    PROMPT
  end
end

# Usage in HTM
topics = topic_extractor.extract_topics(content)
htm.add_message(content, tags: topics, ...)
```

**Benefits of Client-Side Approach**:
- ✅ No database extension dependencies
- ✅ Easier debugging (errors in Ruby)
- ✅ More flexible (can modify extraction logic easily)
- ✅ Works on all platforms
- ✅ Can provide context (existing ontology) to LLM more easily

**Trade-offs**:
- ❌ Slightly slower (HTTP call from Ruby)
- ❌ Not automatic on UPDATE (must be called explicitly)
- ❌ Application must manage topic extraction lifecycle

### Current Recommendation

**For now**: Use manual topic tagging via the `tags` parameter:
```ruby
htm.add_message(
  "PostgreSQL with TimescaleDB handles time-series efficiently",
  tags: ["database:postgresql", "database:timescaledb", "performance:time-series"]
)
```

**Future**: Implement optional client-side topic extraction for automatic tagging

---

## Changelog

- **2025-10-27**: **DATABASE-SIDE EXTRACTION REMOVED** - Removed pgai-based automatic extraction following ADR-011 reversal. Ontology concept and schema remain.
- **2025-10-26**: Initial version - LLM-driven ontology topic extraction with pgai triggers
