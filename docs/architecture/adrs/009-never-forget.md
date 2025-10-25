# ADR-009: Never-Forget Philosophy with Explicit Deletion

**Status**: Accepted

**Date**: 2025-10-25

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Quick Summary

HTM implements a **never-forget philosophy** where memories are never automatically deleted. Eviction only moves memories from working to long-term storage. Deletion requires explicit confirmation (`:confirmed` symbol) and is permanently logged for audit trails.

**Why**: LLMs need persistent, never-forgetting memory for long-term context. Automatic deletion causes surprise, debugging difficulties, and lost knowledge.

**Impact**: Predictable behavior with complete data preservation, at the cost of unbounded storage growth and manual cleanup responsibility.

---

## Context

Traditional memory systems for LLMs face a critical design decision: when should memories be deleted?

### Alternative Approaches

1. **Automatic deletion**: LRU cache eviction, TTL expiration, capacity limits
2. **Never delete**: Unlimited growth, storage costs, degraded performance
3. **Manual deletion**: User explicitly deletes memories
4. **Hybrid**: Automatic archival + manual deletion for permanent removal

### Key Challenges

- **LLM context loss**: Deleting memories loses valuable knowledge
- **User surprise**: Automatic deletion feels like "forgetting" without consent
- **Debugging**: Hard to debug if memories disappear automatically
- **Storage costs**: Unlimited storage is expensive
- **Performance**: Large datasets slow down queries

HTM's core purpose is to provide **persistent, never-forgetting memory** for LLM robots. The philosophy: "never forget unless explicitly told."

---

## Decision

We will implement a **never-forget philosophy** where:

1. Memories are never automatically deleted
2. Eviction only moves memories from working to long-term storage
3. Deletion requires explicit user confirmation
4. Confirmation must be `:confirmed` symbol to prevent accidental deletion
5. All deletions are logged for audit trail

### Deletion API

```ruby
# Attempting to delete without confirmation raises error
htm.forget("key_to_delete")
# => ArgumentError: Must pass confirm: :confirmed to delete

# Explicit confirmation required
htm.forget("key_to_delete", confirm: :confirmed)
# => true (deleted successfully)
```

### Eviction vs Deletion

!!! info "Critical Distinction"
    **Eviction (automatic, safe)**:

    - Triggered by working memory capacity limit
    - Moves memories from working memory to long-term memory
    - NO data loss, memories remain recallable
    - Logged as 'evict' operation

    **Deletion (explicit, destructive)**:

    - Triggered only by user calling `forget(confirm: :confirmed)`
    - Removes memory from both working and long-term storage
    - PERMANENT data loss
    - Logged as 'forget' operation

---

## Rationale

### Why Never-Forget?

**LLMs need long-term context**:

- Architectural decisions made months ago still matter
- User preferences should persist across sessions
- Bug fixes and resolutions are valuable knowledge
- Conversation history builds understanding over time

**Automatic deletion causes problems**:

- Surprise: User asks "didn't we discuss this?" → memory gone
- Debugging: Can't debug deleted memories
- Inconsistency: Same query returns different results over time
- Lost knowledge: Critical information disappears silently

**Two-tier architecture enables never-forget**:

- Working memory: Token-limited, evicts to long-term
- Long-term memory: Unlimited, persistent PostgreSQL
- Eviction ≠ deletion, just moves to cold storage
- Recall brings memories back to working memory

### Why Explicit Confirmation?

**Prevent accidental deletion**:

```ruby
# Easy typo or mistake
htm.forget("important_key")  # REJECTED - raises error

# Must be intentional
htm.forget("important_key", confirm: :confirmed)  # Allowed
```

**Confirmation is a speed bump**:

- Forces user to think before deleting
- Symbol `:confirmed` (not boolean) prevents `confirm: true` shortcuts
- Clear intent signal in code review

**Audit trail for safety**:

- All deletions logged with robot_id and timestamp
- Can investigate "who deleted this?"
- Provides recovery information (log has the deleted value)

### Why Log Before Deleting?

**Foreign key constraint safety**:

```ruby
# Log operation BEFORE deleting
@long_term_memory.log_operation(
  operation: 'forget',
  node_id: node_id,  # Still exists
  robot_id: @robot_id,
  details: { key: key }
)

# Now safe to delete
@long_term_memory.delete(key)
```

**Audit trail preservation**:

- Deletion log entry survives even if something goes wrong
- Can reconstruct what was deleted and when
- Supports future "undo delete" feature

---

## Implementation Details

### Forget Method

```ruby
def forget(key, confirm: false)
  raise ArgumentError, "Must pass confirm: :confirmed to delete" unless confirm == :confirmed

  node_id = @long_term_memory.get_node_id(key)

  # Log operation BEFORE deleting (audit trail)
  @long_term_memory.log_operation(
    operation: 'forget',
    node_id: node_id,
    robot_id: @robot_id,
    details: { key: key }
  )

  # Delete from long-term memory and working memory
  @long_term_memory.delete(key)
  @working_memory.remove(key)

  update_robot_activity
  true
end
```

---

## Consequences

### Positive

- Never lose knowledge: Memories persist unless explicitly deleted
- Predictable behavior: No surprise deletions, no data loss
- Debugging friendly: All memories available for analysis
- Audit trail: Every deletion logged with who/when/what
- Safe eviction: Working memory overflow doesn't lose data
- Recallable: Evicted memories return via recall()
- Intentional deletion: Confirmation prevents accidents

### Negative

- Unbounded growth: Database grows indefinitely without cleanup
- Storage costs: Long-term storage has financial cost
- Query performance: Larger datasets slow down searches
- Manual cleanup: User must periodically delete unneeded memories
- No automatic expiration: Can't set TTL for temporary memories
- Privacy concerns: Sensitive data persists until deleted

### Neutral

- User responsibility: User must manage memory lifecycle
- Explicit is better: Pythonic philosophy, clear intent
- Retention policies: Future feature, not v1

---

## Use Cases

### Use Case 1: Accidental Deletion Attempt

```ruby
# User typo or mistake
htm.forget("important_decision")

# Result: ArgumentError raised
# => ArgumentError: Must pass confirm: :confirmed to delete

# Memory remains safe
```

### Use Case 2: Intentional Deletion

```ruby
# User wants to delete temporary test data
htm.add_node("test_key", "temporary test data", importance: 1.0)

# Later: delete intentionally
htm.forget("test_key", confirm: :confirmed)
# => true (deleted)

# Deletion logged for audit trail
```

### Use Case 3: Eviction (Not Deletion)

```ruby
# Working memory full (128,000 tokens)
# Add large new memory (10,000 tokens)

htm.add_node("new_large_memory", large_text, importance: 7.0)

# Result: HTM evicts low-importance memories to make space
# Evicted memories moved to long-term storage (NOT deleted)
# Can be recalled later:

memories = htm.recall(timeframe: "last month", topic: "evicted topic")
# => Evicted memories returned
```

### Use Case 4: Audit Trail Query

```sql
-- Who deleted this memory?
SELECT robot_id, created_at, details
FROM operations_log
WHERE operation = 'forget'
AND details->>'key' = 'important_key'

-- Result:
-- robot_id: "f47ac10b-..."
-- created_at: 2025-10-25 14:32:15
-- details: {"key": "important_key"}
```

### Use Case 5: Bulk Cleanup (Manual)

```ruby
# User wants to clean up old test data
test_keys = [
  "test_001",
  "test_002",
  "test_003"
]

test_keys.each do |key|
  htm.forget(key, confirm: :confirmed)
end

# All deletions logged individually
# User must explicitly confirm each deletion
```

### Use Case 6: Never-Forget in Practice

```ruby
# Session 1: Important decision
htm.add_node("decision_001",
             "We decided to use PostgreSQL for HTM storage",
             type: :decision,
             importance: 10.0)

# ... 90 days later, many sessions, many memories added ...
# Working memory evicted this decision to long-term storage

# Session 100: User asks about database choice
memories = htm.recall(timeframe: "last 3 months", topic: "database storage")

# Result: Decision recalled from long-term memory
# Never forgotten, always available
```

---

## Deletion Lifecycle

### 1. User Initiates Deletion

```ruby
htm.forget("key_to_delete", confirm: :confirmed)
```

### 2. Validation

```ruby
raise ArgumentError, "Must pass confirm: :confirmed to delete" unless confirm == :confirmed
```

### 3. Retrieve Node ID

```ruby
node_id = @long_term_memory.get_node_id("key_to_delete")
# => 42
```

### 4. Log Operation (Before Deletion)

```ruby
@long_term_memory.log_operation(
  operation: 'forget',
  node_id: 42,  # Still exists at this point
  robot_id: @robot_id,
  details: { key: "key_to_delete" }
)
```

### 5. Delete from Long-Term Memory

```sql
DELETE FROM nodes WHERE key = 'key_to_delete'

-- Cascades to:
-- - relationships (foreign key cascade)
-- - tags (foreign key cascade)
```

### 6. Remove from Working Memory

```ruby
@working_memory.remove("key_to_delete")
```

### 7. Update Robot Activity

```ruby
@long_term_memory.update_robot_activity(@robot_id)
```

### 8. Return Success

```ruby
return true
```

---

## Performance Characteristics

### Deletion Performance

- **Node ID lookup**: O(log n) with index on key
- **Log operation**: O(1) insert
- **Delete query**: O(1) with primary key
- **Cascade deletes**: O(m) where m = related records
- **Working memory remove**: O(1) hash delete
- **Total**: < 10ms for typical deletion

### Audit Log Growth

- **One log entry per deletion**: Minimal overhead
- **Log table indexed**: Fast queries by operation, robot_id, timestamp
- **Partitioning**: Can partition by timestamp if needed

### Storage Growth (Never-Forget)

- **Long-term memory**: Grows unbounded without cleanup
- **Typical growth**: ~100-1000 nodes per day (varies widely)
- **Storage**: ~1-10 KB per node (text + embedding)
- **Annual growth estimate**: ~365-3650 MB per year

---

## Design Decisions

### Decision: Confirmation Symbol (`:confirmed`) Instead of Boolean

**Rationale**:

- Boolean `confirm: true` is too easy to add casually
- Symbol `:confirmed` requires deliberate intent
- Harder to accidentally pass `true` vs `:confirmed`

**Alternative**: `confirm: true`

**Rejected**: Too casual, easy to misuse

**Alternative**: `confirm: "I am sure"`

**Rejected**: String matching is fragile

### Decision: Raise Error on Missing Confirmation

**Rationale**: Fail-safe default, loud failure prevents data loss

```ruby
htm.forget("key")  # Raises ArgumentError
```

**Alternative**: Silently ignore (return false)

**Rejected**: Silent failures are dangerous

**Alternative**: Prompt user for confirmation

**Rejected**: Not appropriate for library code

### Decision: Log Before Delete (Not After)

**Rationale**: Avoid foreign key constraint violations

**Alternative**: Log after delete

**Rejected**: Foreign key violation if node_id referenced

**Alternative**: Allow NULL node_id in logs

**Rejected**: Lose referential integrity

### Decision: Eviction Preserves in Long-Term Memory

**Rationale**: Core never-forget philosophy

**Alternative**: Eviction = deletion

**Rejected**: Violates never-forget principle

**Alternative**: Archive to separate table

**Deferred**: Can optimize with archival tables later

### Decision: No TTL (Time-To-Live) Feature

**Rationale**: Simplicity, never-forget philosophy

**Alternative**: Optional TTL per memory

**Deferred**: Can add later if needed

---

## Risks and Mitigations

### Risk: Unbounded Storage Growth

!!! warning "Risk"
    Database grows indefinitely, storage costs increase

**Likelihood**: High (by design, never-forget)

**Impact**: Medium (storage costs, query slowdown)

**Mitigation**:

- Monitor database size
- Implement archival strategies (future)
- Document cleanup procedures
- Compression policies (TimescaleDB)
- User-driven cleanup with bulk delete utilities

### Risk: Accidental Deletion Despite Confirmation

!!! danger "Risk"
    User confirms deletion by mistake

**Likelihood**: Low (confirmation is speed bump)

**Impact**: High (permanent data loss)

**Mitigation**:

- Audit log preserves what was deleted
- Future: "undo delete" within time window
- Future: "soft delete" with archival table
- Document deletion is permanent

### Risk: Performance Degradation

!!! info "Risk"
    Large dataset slows down queries

**Likelihood**: Medium (depends on usage)

**Impact**: Medium (slower recall)

**Mitigation**:

- Indexes on key, robot_id, created_at, embedding
- TimescaleDB compression for old data
- Archival to separate table (future)
- Partitioning by time range

### Risk: Privacy Concerns

!!! danger "Risk"
    Sensitive data persists indefinitely

**Likelihood**: Medium (users may store sensitive info)

**Impact**: High (privacy violation)

**Mitigation**:

- Document data retention clearly
- Provide secure deletion utilities
- Encryption at rest (PostgreSQL)
- User awareness of never-forget philosophy

---

## Future Enhancements

### Soft Delete (Archival)

```ruby
# Mark as deleted instead of hard delete
htm.archive("key_to_archive", confirm: :confirmed)

# Archived memories excluded from queries
# But recoverable if needed
htm.unarchive("key_to_archive")
```

### Undo Delete (Time Window)

```ruby
# Soft delete with 30-day recovery window
htm.forget("key", confirm: :confirmed)

# Within 30 days: undo
htm.undo_forget("key")

# After 30 days: permanent deletion
```

### Retention Policies

```ruby
# Automatic archival based on age and importance
htm.configure_retention(
  archive_after_days: 365,
  min_importance: 5.0  # Don't archive high-importance
)
```

### Bulk Delete Utilities

```ruby
# Delete all nodes matching criteria
HTM::Cleanup.delete_by_tag("temporary", confirm: :confirmed)
HTM::Cleanup.delete_older_than(1.year.ago, confirm: :confirmed)
HTM::Cleanup.delete_by_robot("robot-123", confirm: :confirmed)
```

### Encryption for Sensitive Data

```ruby
# Encrypt sensitive memories
htm.add_node("api_key", sensitive_value,
             encrypt: true,
             importance: 10.0)

# Automatically encrypted in database
# Decrypted on retrieval
```

### Audit Log Analysis

```ruby
# Analyze deletion patterns
HTM::Analytics.deletion_report(timeframe: "last month")

# Who deletes the most?
# What types of memories are deleted?
# When are deletions happening?
```

---

## Alternatives Comparison

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **Never-Forget with Explicit Delete** | **Predictable, safe** | **Storage growth** | **ACCEPTED** |
| Automatic TTL | Automatic cleanup | Surprise deletions | Rejected |
| LRU with Deletion | Simple capacity management | Data loss | Rejected |
| No Deletion API | Simplest never-forget | No escape hatch | Rejected |
| Confirmation via Prompt | User-friendly | Not library-appropriate | Rejected |
| Soft Delete by Default | Recoverable | Complex, unclear | Deferred |

---

## References

- [Never Forget Principle](https://en.wikipedia.org/wiki/Persistence_(computer_science))
- [Audit Logging Best Practices](https://owasp.org/www-community/Audit_Logging)
- [Soft Deletion Pattern](https://en.wikipedia.org/wiki/Soft_deletion)
- [GDPR Right to Erasure](https://gdpr.eu/right-to-be-forgotten/)
- [Data Retention Policies](https://en.wikipedia.org/wiki/Data_retention)
- [ADR-002: Two-Tier Memory](002-two-tier-memory.md)
- [ADR-007: Eviction Strategy](007-eviction-strategy.md)
- [Long-Term Memory Guide](../../guides/long-term-memory.md)

---

## Review Notes

**Systems Architect**: Never-forget philosophy is core value proposition. Explicit deletion is correct.

**Security Specialist**: Document data retention clearly. Consider encryption for sensitive data. GDPR implications?

**Domain Expert**: Two-tier architecture enables never-forget without performance penalty. Smart design.

**Ruby Expert**: Symbol confirmation (`:confirmed`) is idiomatic Ruby. Better than boolean.

**AI Engineer**: Persistent memory is critical for LLM context. Automatic deletion would degrade performance.

**Performance Specialist**: Monitor storage growth. Plan for archival strategies. Compression will help.

**Database Architect**: Log-before-delete prevents foreign key violations. Consider partitioning for large datasets.
