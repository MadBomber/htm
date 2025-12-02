# Tag Ontology Enhancement Ideas

## Problem Statement

HTM builds a dynamic hierarchical tag ontology but doesn't fully leverage it for retrieval. The tag extraction is sophisticated (LLM-based, ontology-consistent, hierarchical), but the retrieval capabilities are limited.

## Current State Analysis

### What's Working Well
- Sophisticated LLM-based tag extraction with ontology consistency
- Hierarchical format (`database:postgresql:indexes`)
- Beautiful visualization (tree, Mermaid, SVG)
- Tag relationship analysis (co-occurrence)
- Async generation via `GenerateTagsJob`

### What's Missing
1. **`search_by_tags()` and `nodes_by_topic()` exist in LongTermMemory but aren't exposed in the public HTM API**
2. `recall()` accepts `query_tags:` parameter but **ignores it** except for relevance scoring
3. No hierarchical traversal (parent/child/ancestor queries)
4. No tag-only retrieval (without text query)
5. No query expansion using tag relationships
6. No faceted navigation
7. No tag-based result grouping

---

## Proposed Enhancements

### 1. Expose Tag-Based Retrieval in HTM API

**Priority: High** - These methods already exist, just need to be exposed.

```ruby
# Browse by topic path (hierarchical navigation)
htm.browse("database:postgresql")  # All nodes under this branch

# Filter recall with tags
htm.recall("query", tags: ["database:postgresql"], match_all: false)

# Tag-only retrieval (no text query required)
htm.by_tags(["database:postgresql", "ai:embeddings"])
```

**Implementation:**
- Add `browse(topic_path, exact: false, limit: 20)` to HTM class
- Add `by_tags(tags, match_all: false, limit: 20)` to HTM class
- Wire `query_tags:` parameter through to actual filtering in `recall()`

---

### 2. Hierarchical Query Expansion

**Priority: High** - Leverages the hierarchical structure.

```ruby
# Searching "database:postgresql" should optionally include children:
#   database:postgresql:indexes
#   database:postgresql:extensions
#   database:postgresql:partitioning

htm.recall("indexes", tags: ["database:postgresql"], expand_children: true)

# Or expand upward to include parent context
htm.recall("specific query", tags: ["database:postgresql:indexes"], expand_ancestors: true)
```

**Implementation:**
- Add `expand_children:` and `expand_ancestors:` options
- Query `tags.name LIKE 'database:postgresql:%'` for children
- Parse tag path and query ancestors for upward expansion

---

### 3. Faceted Search / Tag Aggregation

**Priority: Medium** - Enables discovery and navigation.

```ruby
# "What topics are represented in my search results?"
results = htm.recall("machine learning")
facets = results.facet_by_tags
# => { "ai:ml" => 15, "ai:llm" => 8, "database:vector" => 5 }

# Or as a standalone method
htm.tag_facets(query: "machine learning", limit: 10)
```

**Implementation:**
- Return tag counts grouped by topic
- Weight by specificity (deeper tags = more specific)
- Consider returning hierarchical facet structure

---

### 4. Semantic Tag Matching in Recall

**Priority: Medium** - Auto-extract tags from query.

```ruby
# Auto-extract tags from query and use them to boost results
htm.recall("PostgreSQL vector search", auto_tag: true)
# Internally: extracts ["database:postgresql", "database:vector-search"]
# and uses these to boost relevant results
```

**Implementation:**
- Use `find_query_matching_tags()` (already exists in LongTermMemory)
- Boost results that match extracted tags
- Make this opt-in or opt-out via configuration

---

### 5. Tag-Based Context Assembly

**Priority: Medium** - Topic-focused context building.

```ruby
# Assemble context prioritizing specific topic branches
htm.assemble_context(
  token_budget: 4000,
  focus_topics: ["database:postgresql", "ai:embeddings"],
  strategy: :topic_balanced  # New strategy
)
```

**Implementation:**
- Add `:topic_balanced` strategy to WorkingMemory
- Weight nodes by tag overlap with focus topics
- Ensure diverse topic coverage within budget

---

### 6. Ontology-Aware Related Memories

**Priority: Low** - Nice-to-have for exploration.

```ruby
# Find related memories via shared tags (not just vector similarity)
htm.related_by_topic(node_id)
# Returns nodes sharing the most tags, weighted by specificity

# Compare to existing vector-based similarity
htm.similar(node_id)  # Vector similarity
htm.related_by_topic(node_id)  # Tag-based similarity
```

**Implementation:**
- Count shared tags between nodes
- Weight by tag depth (more specific = higher weight)
- Combine with vector similarity for hybrid relatedness

---

### 7. Tag Model Enhancements

**Priority: Medium** - Better hierarchy navigation.

```ruby
# Add to HTM::Models::Tag
tag.parent          # Parent tag (e.g., "database:postgresql" -> "database")
tag.children        # Child tags (e.g., "database" -> ["database:postgresql", "database:mysql"])
tag.siblings        # Same-level tags under same parent
tag.ancestors       # All ancestors up to root
tag.descendants     # All descendants (recursive)

# Class methods
Tag.roots           # All root-level tags
Tag.at_depth(2)     # All tags at specific depth
Tag.under("database")  # All tags in this branch
```

**Implementation:**
- Parse colon-separated paths
- Use SQL LIKE queries for efficient hierarchy traversal
- Consider materialized path or nested set for performance at scale

---

### 8. Tag-Based Grouping in Results

**Priority: Low** - Organizational feature.

```ruby
# Group results by their primary tag
results = htm.recall("query", group_by_tag: true)
# => {
#   "database:postgresql" => [node1, node2],
#   "ai:embeddings" => [node3, node4],
#   "uncategorized" => [node5]
# }
```

---

## Implementation Priority

### Phase 1 (High Value, Low Effort)
1. Expose existing `search_by_tags()` and `nodes_by_topic()` in HTM API
2. Wire `query_tags:` parameter through `recall()` for actual filtering

### Phase 2 (High Value, Medium Effort)
3. Add hierarchical query expansion (`expand_children:`, `expand_ancestors:`)
4. Add Tag model hierarchy methods (parent, children, ancestors, descendants)

### Phase 3 (Medium Value, Medium Effort)
5. Faceted search / tag aggregation
6. Semantic tag matching in recall (auto-extract from query)
7. Tag-based context assembly strategy

### Phase 4 (Nice to Have)
8. Ontology-aware related memories
9. Tag-based result grouping

---

## Notes

- All enhancements should maintain backward compatibility
- Consider adding configuration options for default behaviors
- Tag operations should be efficient (indexed queries)
- Consider caching popular tag queries
- Document new methods with YARD comments
