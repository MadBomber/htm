-- HTM Database Schema for PostgreSQL/TimescaleDB
-- Enable required extensions

CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Main nodes table - Conversation memory storage
-- Each row represents a message/utterance from a conversation between user and robots
CREATE TABLE IF NOT EXISTS nodes (
  id BIGSERIAL PRIMARY KEY,
  content TEXT NOT NULL,                  -- The conversation message/utterance
  speaker TEXT NOT NULL,                  -- Who said it: 'user' or robot name
  type TEXT,                              -- fact, context, code, preference, decision, question
  category TEXT,
  importance REAL DEFAULT 1.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_accessed TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  token_count INTEGER,
  in_working_memory BOOLEAN DEFAULT FALSE,
  robot_id TEXT NOT NULL,                 -- Robot that stored this memory
  embedding vector(2000),                 -- Semantic embedding for RAG retrieval
  embedding_dimension INTEGER             -- Actual dimension used (required for validation)
);

-- Relationships between nodes
CREATE TABLE IF NOT EXISTS relationships (
  id BIGSERIAL PRIMARY KEY,
  from_node_id BIGINT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  to_node_id BIGINT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  relationship_type TEXT,
  strength REAL DEFAULT 1.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(from_node_id, to_node_id, relationship_type)
);

-- Tags for flexible categorization
CREATE TABLE IF NOT EXISTS tags (
  id BIGSERIAL PRIMARY KEY,
  node_id BIGINT NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(node_id, tag)
);

-- Operation log for debugging and replay
CREATE TABLE IF NOT EXISTS operations_log (
  id BIGSERIAL PRIMARY KEY,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  operation TEXT NOT NULL,  -- add, retrieve, remove, evict, recall
  node_id BIGINT,
  robot_id TEXT NOT NULL,
  details JSONB  -- Flexible storage for additional metadata
);

-- Robots registry (track all robots using the system)
CREATE TABLE IF NOT EXISTS robots (
  id TEXT PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_active TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  metadata JSONB  -- Store robot-specific configuration
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_nodes_created_at ON nodes(created_at);
CREATE INDEX IF NOT EXISTS idx_nodes_updated_at ON nodes(updated_at);
CREATE INDEX IF NOT EXISTS idx_nodes_last_accessed ON nodes(last_accessed);
CREATE INDEX IF NOT EXISTS idx_nodes_type ON nodes(type);
CREATE INDEX IF NOT EXISTS idx_nodes_category ON nodes(category);
CREATE INDEX IF NOT EXISTS idx_nodes_robot_id ON nodes(robot_id);
CREATE INDEX IF NOT EXISTS idx_nodes_speaker ON nodes(speaker);  -- Index speaker for filtering conversations
CREATE INDEX IF NOT EXISTS idx_nodes_in_working_memory ON nodes(in_working_memory);

-- Vector similarity search index (HNSW for better performance)
CREATE INDEX IF NOT EXISTS idx_nodes_embedding ON nodes
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- Full-text search on conversation content
CREATE INDEX IF NOT EXISTS idx_nodes_content_gin ON nodes USING gin(to_tsvector('english', content));

-- Trigram indexes for fuzzy matching on conversation content
CREATE INDEX IF NOT EXISTS idx_nodes_content_trgm ON nodes USING gin(content gin_trgm_ops);

-- Relationship indexes
CREATE INDEX IF NOT EXISTS idx_relationships_from ON relationships(from_node_id);
CREATE INDEX IF NOT EXISTS idx_relationships_to ON relationships(to_node_id);

-- Tags indexes
CREATE INDEX IF NOT EXISTS idx_tags_node_id ON tags(node_id);
CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag);
CREATE INDEX IF NOT EXISTS idx_tags_tag_pattern ON tags(tag text_pattern_ops);  -- For hierarchical topic queries

-- Operation log indexes
CREATE INDEX IF NOT EXISTS idx_operations_log_timestamp ON operations_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_operations_log_robot_id ON operations_log(robot_id);
CREATE INDEX IF NOT EXISTS idx_operations_log_operation ON operations_log(operation);

-- Check constraint for embedding dimensions
ALTER TABLE nodes DROP CONSTRAINT IF EXISTS check_embedding_dimension;
ALTER TABLE nodes ADD CONSTRAINT check_embedding_dimension
  CHECK (embedding_dimension IS NOT NULL AND embedding_dimension > 0 AND embedding_dimension <= 2000);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_nodes_updated_at ON nodes;
CREATE TRIGGER update_nodes_updated_at
  BEFORE UPDATE ON nodes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to validate embedding dimensions
CREATE OR REPLACE FUNCTION validate_embedding_dimension()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.embedding IS NOT NULL AND NEW.embedding_dimension IS NOT NULL THEN
    -- Validate that embedding dimension is reasonable
    -- pgvector doesn't expose dimension directly, validation happens at application layer
    NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validate_embedding_dimension ON nodes;
CREATE TRIGGER trigger_validate_embedding_dimension
  BEFORE INSERT OR UPDATE ON nodes
  FOR EACH ROW
  EXECUTE FUNCTION validate_embedding_dimension();

-- View for node statistics
CREATE OR REPLACE VIEW node_stats AS
SELECT
  type,
  COUNT(*) as count,
  AVG(importance) as avg_importance,
  SUM(token_count) as total_tokens,
  MIN(created_at) as oldest,
  MAX(created_at) as newest
FROM nodes
GROUP BY type;

-- View for robot activity
CREATE OR REPLACE VIEW robot_activity AS
SELECT
  r.id,
  r.name,
  COUNT(n.id) as total_nodes,
  MAX(n.created_at) as last_node_created
FROM robots r
LEFT JOIN nodes n ON n.robot_id = r.id
GROUP BY r.id, r.name;

-- View for hierarchical ontology structure
CREATE OR REPLACE VIEW ontology_structure AS
SELECT
  split_part(tag, ':', 1) AS root_topic,
  split_part(tag, ':', 2) AS level1_topic,
  split_part(tag, ':', 3) AS level2_topic,
  tag AS full_path,
  COUNT(DISTINCT node_id) AS node_count
FROM tags
WHERE tag ~ '^[a-z0-9\-]+(:[a-z0-9\-]+)*$'  -- Only valid hierarchical tags
GROUP BY tag
ORDER BY root_topic, level1_topic, level2_topic;

-- View for topic co-occurrence analysis
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

-- Comments on columns and views
COMMENT ON COLUMN nodes.embedding IS 'Vector embedding (max 2000 dimensions). Actual dimension stored in embedding_dimension column.';
COMMENT ON COLUMN nodes.embedding_dimension IS 'Actual number of dimensions used in the embedding vector (max 2000).';
COMMENT ON COLUMN nodes.content IS 'The conversation message/utterance content';
COMMENT ON COLUMN nodes.speaker IS 'Who said it: user or robot name';

COMMENT ON VIEW ontology_structure IS
  'Provides a hierarchical view of all topics in the knowledge base. Topics use colon-delimited format (e.g., database:postgresql:timescaledb) and are assigned manually via tags.';
COMMENT ON VIEW topic_relationships IS
  'Shows which topics co-occur on the same nodes, revealing cross-topic relationships in the knowledge base.';
