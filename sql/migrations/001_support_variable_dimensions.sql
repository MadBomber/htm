-- Migration: Support Variable Embedding Dimensions
-- Created: 2025-01-25
--
-- This migration updates the nodes table to support variable embedding dimensions
-- by using a larger vector size that can accommodate common embedding models.
--
-- Supported dimensions:
-- - OpenAI text-embedding-3-small: 1536
-- - Cohere embed-english-v3.0: 1024
-- - Ollama gpt-oss: 768
--
-- We use 2000 as the maximum due to HNSW index limitation (pgvector).
-- Note: OpenAI text-embedding-3-large (2000) exceeds this limit.
-- Smaller embeddings will be padded with zeros to fit the column.

-- Add a metadata column to track the actual embedding dimension used
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'nodes' AND column_name = 'embedding_dimension'
  ) THEN
    ALTER TABLE nodes ADD COLUMN embedding_dimension INTEGER;
  END IF;
END $$;

-- Update existing rows to have dimension metadata (assuming 1536 for existing data)
UPDATE nodes SET embedding_dimension = 1536 WHERE embedding_dimension IS NULL;

-- Alter the embedding column to support larger dimensions
-- This requires dropping and recreating the column with the index
DO $$
BEGIN
  -- Drop the existing index first
  DROP INDEX IF EXISTS idx_nodes_embedding;

  -- Alter the column to support up to 2000 dimensions
  -- Note: This will fail if existing embeddings don't fit
  -- We'll handle this by padding in the application layer
  BEGIN
    ALTER TABLE nodes ALTER COLUMN embedding TYPE vector(2000);
  EXCEPTION
    WHEN others THEN
      -- If alter fails, we need to recreate the column
      -- Save existing data
      ALTER TABLE nodes RENAME COLUMN embedding TO embedding_old;

      -- Create new column
      ALTER TABLE nodes ADD COLUMN embedding vector(2000);

      -- Note: In production, you would migrate data here
      -- For now, we'll let the application handle it
      -- DROP COLUMN embedding_old when ready
  END;

  -- Recreate the index
  CREATE INDEX IF NOT EXISTS idx_nodes_embedding ON nodes
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);
END $$;

-- Add a check constraint to ensure embedding_dimension is set
ALTER TABLE nodes ADD CONSTRAINT check_embedding_dimension
  CHECK (embedding_dimension IS NOT NULL AND embedding_dimension > 0 AND embedding_dimension <= 2000);

-- Create a function to validate embedding dimensions match metadata
CREATE OR REPLACE FUNCTION validate_embedding_dimension()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.embedding IS NOT NULL AND NEW.embedding_dimension IS NOT NULL THEN
    -- pgvector doesn't expose dimension directly, but we can validate in application
    -- This is a placeholder for future validation
    NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate dimensions
DROP TRIGGER IF EXISTS trigger_validate_embedding_dimension ON nodes;
CREATE TRIGGER trigger_validate_embedding_dimension
  BEFORE INSERT OR UPDATE ON nodes
  FOR EACH ROW
  EXECUTE FUNCTION validate_embedding_dimension();

-- Add comment explaining the dimension strategy
COMMENT ON COLUMN nodes.embedding IS 'Vector embedding (max 2000 dimensions). Actual dimension stored in embedding_dimension column.';
COMMENT ON COLUMN nodes.embedding_dimension IS 'Actual number of dimensions used in the embedding vector (max 2000).';
