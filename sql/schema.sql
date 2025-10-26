-- HTM Database Schema for PostgreSQL/TimescaleDB
-- Enable required extensions

CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS ai CASCADE;  -- pgai for intelligent embedding generation

-- Main nodes table
CREATE TABLE IF NOT EXISTS nodes (
  id BIGSERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  type TEXT,  -- fact, context, code, preference, decision, question
  category TEXT,
  importance REAL DEFAULT 1.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  last_accessed TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  token_count INTEGER,
  in_working_memory BOOLEAN DEFAULT FALSE,
  robot_id TEXT NOT NULL,
  embedding vector(2000),  -- Support up to 2000 dimensions (HNSW index limitation)
  embedding_dimension INTEGER  -- Actual dimension used (required for validation)
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
  node_id BIGINT REFERENCES nodes(id) ON DELETE SET NULL,
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
CREATE INDEX IF NOT EXISTS idx_nodes_in_working_memory ON nodes(in_working_memory);

-- Vector similarity search index (HNSW for better performance)
CREATE INDEX IF NOT EXISTS idx_nodes_embedding ON nodes
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- Full-text search
CREATE INDEX IF NOT EXISTS idx_nodes_value_gin ON nodes USING gin(to_tsvector('english', value));
CREATE INDEX IF NOT EXISTS idx_nodes_key_gin ON nodes USING gin(to_tsvector('english', key));

-- Trigram indexes for fuzzy matching
CREATE INDEX IF NOT EXISTS idx_nodes_value_trgm ON nodes USING gin(value gin_trgm_ops);

-- Relationship indexes
CREATE INDEX IF NOT EXISTS idx_relationships_from ON relationships(from_node_id);
CREATE INDEX IF NOT EXISTS idx_relationships_to ON relationships(to_node_id);

-- Tags indexes
CREATE INDEX IF NOT EXISTS idx_tags_node_id ON tags(node_id);
CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag);

-- Operation log indexes
CREATE INDEX IF NOT EXISTS idx_operations_log_timestamp ON operations_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_operations_log_robot_id ON operations_log(robot_id);
CREATE INDEX IF NOT EXISTS idx_operations_log_operation ON operations_log(operation);

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

-- pgai Configuration and Vectorizer Setup
-- This enables automatic embedding generation using pgai

-- Function to generate embeddings using pgai
-- Supports multiple providers: ollama (default), openai
CREATE OR REPLACE FUNCTION generate_node_embedding()
RETURNS TRIGGER AS $$
DECLARE
  embedding_provider TEXT;
  embedding_model TEXT;
  ollama_host TEXT;
  embedding_dim INTEGER;
  generated_embedding vector;
BEGIN
  -- Get configuration from environment or use defaults
  -- These can be set via: SELECT set_config('htm.embedding_provider', 'ollama', false);
  embedding_provider := COALESCE(current_setting('htm.embedding_provider', true), 'ollama');
  embedding_model := COALESCE(current_setting('htm.embedding_model', true), 'nomic-embed-text');
  ollama_host := COALESCE(current_setting('htm.ollama_url', true), 'http://localhost:11434');
  embedding_dim := COALESCE(current_setting('htm.embedding_dimension', true)::INTEGER, 768);

  -- Generate embedding based on provider
  IF embedding_provider = 'ollama' THEN
    -- Use pgai's ollama embedding function
    generated_embedding := ai.ollama_embed(
      embedding_model,
      NEW.value,
      host => ollama_host
    );
  ELSIF embedding_provider = 'openai' THEN
    -- Use pgai's openai embedding function
    -- Requires OPENAI_API_KEY to be set in PostgreSQL environment
    generated_embedding := ai.openai_embed(
      embedding_model,
      NEW.value,
      api_key => current_setting('htm.openai_api_key', true)
    );
  ELSE
    RAISE EXCEPTION 'Unknown embedding provider: %. Use ollama or openai.', embedding_provider;
  END IF;

  -- Set the embedding and dimension
  NEW.embedding := generated_embedding;
  NEW.embedding_dimension := array_length(generated_embedding::real[], 1);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically generate embeddings on INSERT and UPDATE
DROP TRIGGER IF EXISTS nodes_generate_embedding ON nodes;
CREATE TRIGGER nodes_generate_embedding
  BEFORE INSERT OR UPDATE OF value ON nodes
  FOR EACH ROW
  WHEN (NEW.embedding IS NULL OR NEW.value IS DISTINCT FROM OLD.value)
  EXECUTE FUNCTION generate_node_embedding();

-- Helper function to set pgai configuration
CREATE OR REPLACE FUNCTION htm_set_embedding_config(
  provider TEXT DEFAULT 'ollama',
  model TEXT DEFAULT 'nomic-embed-text',
  ollama_url TEXT DEFAULT 'http://localhost:11434',
  openai_api_key TEXT DEFAULT NULL,
  dimension INTEGER DEFAULT 768
) RETURNS void AS $$
BEGIN
  PERFORM set_config('htm.embedding_provider', provider, false);
  PERFORM set_config('htm.embedding_model', model, false);
  PERFORM set_config('htm.ollama_url', ollama_url, false);
  PERFORM set_config('htm.embedding_dimension', dimension::TEXT, false);

  IF openai_api_key IS NOT NULL THEN
    PERFORM set_config('htm.openai_api_key', openai_api_key, false);
  END IF;

  RAISE NOTICE 'HTM embedding configuration updated: provider=%, model=%, dimension=%', provider, model, dimension;
END;
$$ LANGUAGE plpgsql;

-- Set default configuration for Ollama with nomic-embed-text (768 dimensions)
SELECT htm_set_embedding_config();
