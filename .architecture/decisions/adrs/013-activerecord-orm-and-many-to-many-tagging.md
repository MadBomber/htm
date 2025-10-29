# ADR-013: ActiveRecord ORM and Many-to-Many Tagging System

**Status**: Accepted

**Date**: 2025-10-29

**Decision Makers**: Dewayne VanHoozer, Claude (Anthropic)

---

## Context

HTM's database layer initially used direct SQL queries via PG gem for all database operations. As the system evolved, several pain points emerged:

- **Code duplication**: Similar SQL queries repeated across methods
- **No schema versioning**: Schema changes were manual and error-prone
- **Limited validation**: No model-level validations or constraints
- **Complex queries**: Hand-written SQL for relationships and joins
- **Testing difficulty**: Hard to mock database interactions
- **Migration management**: No systematic way to evolve schema

Additionally, the initial tagging system stored tags as a simple column in the nodes table, limiting flexibility:

- **Single tag per node**: Could not express multiple categories
- **No tag reuse**: Each node duplicated tag text
- **Difficult queries**: Finding nodes by tag required text matching
- **No tag hierarchy**: Could not organize tags into hierarchies

## Decision

We will:

1. **Adopt ActiveRecord ORM** for database interactions with PostgreSQL
2. **Implement proper ActiveRecord models**: Robot, Node, Tag, NodeTag
3. **Use ActiveRecord migrations** for schema version control
4. **Create many-to-many tagging** via join table (nodes_tags)
5. **Support hierarchical tags** using colon-separated namespaces

## Rationale

### Why ActiveRecord?

**Production-proven ORM**:
- Mature, battle-tested Rails component
- Extensive documentation and community support
- Works standalone without Rails framework
- Handles connection pooling automatically

**Schema Management**:
- Migration system provides version control for database changes
- Rollback capability for schema changes
- `schema.sql` dump for canonical schema representation
- Easy team collaboration on schema evolution

**Model Layer Benefits**:
- Associations handle complex joins automatically
- Validations at model level prevent bad data
- Callbacks for lifecycle hooks
- Scopes for reusable query patterns
- Testing helpers for mocking

**Query Building**:
- Chainable query interface (`.where().order().limit()`)
- Prevents SQL injection automatically
- Generates optimized SQL
- Database-agnostic (could switch from PostgreSQL if needed)

### Why Many-to-Many Tagging?

**Flexibility**:
- Nodes can have multiple tags
- Tags can be applied to multiple nodes
- Tag relationships are explicit and queryable

**Data Normalization**:
- Tags stored once, referenced many times
- Tag updates affect all associated nodes
- Referential integrity via foreign keys

**Hierarchical Organization**:
- Colon-separated namespaces: `ai:llm:embeddings`
- Query by prefix: `WHERE name LIKE 'ai:llm:%'`
- Enables ontology-like structure
- LLM can generate contextual tags

**Query Power**:
- Find all tags for a node (simple join)
- Find all nodes with tag (reverse join)
- Find related tags by shared nodes
- Combine with vector/full-text search

## Implementation Details

### ActiveRecord Models

```ruby
# lib/htm/models/robot.rb
class HTM::Models::Robot < ActiveRecord::Base
  has_many :nodes, dependent: :destroy
end

# lib/htm/models/node.rb
class HTM::Models::Node < ActiveRecord::Base
  belongs_to :robot
  has_many :node_tags, dependent: :destroy
  has_many :tags, through: :node_tags
end

# lib/htm/models/tag.rb
class HTM::Models::Tag < ActiveRecord::Base
  has_many :node_tags, dependent: :destroy
  has_many :nodes, through: :node_tags
  validates :name, presence: true, uniqueness: true
end

# lib/htm/models/node_tag.rb
class HTM::Models::NodeTag < ActiveRecord::Base
  self.table_name = 'nodes_tags'
  belongs_to :node
  belongs_to :tag
  validates :tag_id, uniqueness: { scope: :node_id }
end
```

### Database Schema

**robots** table:
- `id` (bigint, primary key)
- `name` (text)
- `created_at`, `last_active` (timestamptz)
- `metadata` (jsonb)

**nodes** table:
- `id` (bigint, primary key)
- `content`, `speaker` (text, not null)
- `type`, `category` (text)
- `importance` (double precision)
- `created_at`, `updated_at`, `last_accessed` (timestamptz)
- `token_count` (integer)
- `in_working_memory` (boolean)
- `robot_id` (bigint, foreign key → robots)
- `embedding` (vector(2000))
- `embedding_dimension` (integer)

**tags** table:
- `id` (bigint, primary key)
- `name` (text, unique, not null)
- `created_at` (timestamptz)

**nodes_tags** join table:
- `id` (bigint, primary key)
- `node_id` (bigint, foreign key → nodes)
- `tag_id` (bigint, foreign key → tags)
- `created_at` (timestamptz)
- Unique constraint on (node_id, tag_id)

### Migration System

Migrations in `db/migrate/`:
- `20250101000001_create_robots.rb`
- `20250101000002_create_nodes.rb`
- `20250101000005_create_tags.rb`

Apply: `bundle exec rake htm:db:migrate`
Dump: `bundle exec rake htm:db:schema:dump`

### Tag Hierarchy Examples

```ruby
# Programming tags
'programming:ruby:gems'
'programming:ruby:activerecord'
'programming:python:django'

# AI tags
'ai:llm:embeddings'
'ai:llm:prompts'
'ai:rag:retrieval'

# Database tags
'database:postgresql:indexes'
'database:postgresql:extensions'
```

Query patterns:
```sql
-- All Ruby-related tags
SELECT * FROM tags WHERE name LIKE 'programming:ruby:%';

-- All LLM-related nodes
SELECT n.* FROM nodes n
JOIN nodes_tags nt ON n.id = nt.node_id
JOIN tags t ON nt.tag_id = t.id
WHERE t.name LIKE 'ai:llm:%';
```

## Consequences

### Positive

✅ **Schema version control**: Migrations provide audit trail of all schema changes
✅ **Model validations**: Prevent invalid data at application layer
✅ **Association power**: `node.tags` and `tag.nodes` work automatically
✅ **Query safety**: ActiveRecord prevents SQL injection
✅ **Testing improvement**: Models can be easily stubbed/mocked
✅ **Code clarity**: `Node.where(type: 'fact')` vs raw SQL
✅ **Tag flexibility**: Multiple tags per node, hierarchical organization
✅ **Tag reuse**: Same tag on many nodes without duplication
✅ **Referential integrity**: Foreign keys enforce consistency
✅ **Cascade deletes**: Deleting node removes its tag associations

### Negative

❌ **Added dependency**: ActiveRecord gem and its dependencies
❌ **Learning curve**: Developers need to know ActiveRecord API
❌ **Abstraction overhead**: Slight performance cost vs raw SQL
❌ **Magic behavior**: Callbacks and hooks can surprise developers
❌ **Migration complexity**: Schema changes require migration files

### Neutral

➡️ **File organization**: Models in `lib/htm/models/`, migrations in `db/migrate/`
➡️ **Configuration**: `lib/htm/active_record_config.rb` manages setup
➡️ **Naming conventions**: Rails conventions (snake_case tables, CamelCase models)

## Removed Features

To streamline the schema, the following tables were removed:

**relationships table**: Originally intended for knowledge graph edges between nodes
- **Reason**: Not used in current implementation
- **Future**: Could be re-added via migration if graph features needed

**operations_log table**: Originally intended for audit trail
- **Reason**: Not used in current implementation
- **Future**: Could use ActiveRecord callbacks or separate audit gem

## Risks and Mitigations

### Risk: ActiveRecord Complexity

- **Risk**: Developers misuse callbacks or create N+1 queries
- **Likelihood**: Medium
- **Impact**: Medium (performance degradation)
- **Mitigation**: Code reviews, use `includes()` for associations, monitor query patterns

### Risk: Migration Conflicts

- **Risk**: Multiple developers create conflicting migrations
- **Likelihood**: Low (small team)
- **Impact**: Low (easy to resolve)
- **Mitigation**: Communication, timestamp-based migration names

### Risk: Tag Proliferation

- **Risk**: Too many similar tags created (typos, inconsistent naming)
- **Likelihood**: Medium
- **Impact**: Low (cluttered tag space)
- **Mitigation**: LLM-driven tag normalization, tag search/suggestion features

## Alternatives Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Raw SQL (PG gem) | Maximum control, no dependencies | Boilerplate, no validations, error-prone | ❌ Rejected |
| Sequel ORM | Lightweight, flexible | Less mature than ActiveRecord | ❌ Rejected |
| ActiveRecord | Production-proven, migrations, associations | Heavier, Rails conventions | ✅ **Accepted** |
| Single-table tags | Simpler schema | No tag reuse, limited queries | ❌ Rejected |
| EAV pattern | Maximum flexibility | Query complexity, performance | ❌ Rejected |
| Many-to-many tags | Normalized, flexible, powerful | Join table overhead | ✅ **Accepted** |

## Future Considerations

- **Tag autocomplete**: Suggest existing tags when tagging nodes
- **Tag merging**: Combine similar/duplicate tags
- **Tag statistics**: Most used tags, tag co-occurrence
- **Tag hierarchies**: Formal parent-child relationships beyond namespace convention
- **Tag permissions**: Some tags restricted to certain robots
- **ActiveRecord optimizations**: Eager loading, counter caches, read replicas

## References

- [ActiveRecord Documentation](https://api.rubyonrails.org/classes/ActiveRecord/Base.html)
- [ActiveRecord Migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [ActiveRecord Associations](https://guides.rubyonrails.org/association_basics.html)
- [ADR-001: PostgreSQL Storage](./001-use-postgresql-timescaledb-storage.md)
- [Schema Documentation](../../../docs/development/schema.md)

## Review Notes

**Systems Architect**: ✅ ActiveRecord is a solid choice for this scale. The many-to-many tagging provides good flexibility without over-engineering.

**Database Architect**: ✅ Proper foreign keys and unique constraints ensure data integrity. The join table follows best practices.

**Ruby Expert**: ✅ ActiveRecord integration is clean. Models follow Rails conventions which makes the codebase more approachable.

**Maintainability Expert**: ✅ Migrations provide crucial schema version control. Much better than manual SQL scripts.

**Performance Specialist**: ⚠️ Monitor for N+1 queries. Consider adding indexes on tag.name pattern queries and counter caches if tag counts are frequently accessed.
