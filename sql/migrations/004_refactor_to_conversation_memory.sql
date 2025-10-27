-- Migration: Refactor nodes table to conversation memory model
--
-- BREAKING CHANGE: This migration fundamentally changes the data model
-- from a key/value store to a conversation memory system.
--
-- Changes:
-- 1. Remove 'key' column (was UNIQUE NOT NULL)
-- 2. Rename 'value' → 'content' (the conversation message)
-- 3. Add 'speaker' column (who said it: 'user' or robot name)
-- 4. Change PRIMARY KEY from (id) → (id, created_at) for hypertable support
-- 5. Update indexes: remove key indexes, add speaker index
-- 6. Drop and recreate full-text search indexes on content

-- WARNING: This migration will fail if the nodes table contains data
-- You must either:
-- A) Drop all data: DROP TABLE nodes CASCADE; then run htm:db:setup
-- B) Manually migrate data with custom transformation logic

-- Step 1: Drop old indexes that reference key/value
DROP INDEX IF EXISTS idx_nodes_key_gin;
DROP INDEX IF EXISTS idx_nodes_value_gin;
DROP INDEX IF EXISTS idx_nodes_value_trgm;

-- Step 2: Rename value → content
ALTER TABLE nodes
  RENAME COLUMN value TO content;

-- Step 3: Drop the key column
-- This will fail if there are foreign key references
ALTER TABLE nodes
  DROP COLUMN IF EXISTS key CASCADE;

-- Step 4: Add speaker column
ALTER TABLE nodes
  ADD COLUMN IF NOT EXISTS speaker TEXT NOT NULL DEFAULT 'unknown';

-- Step 5: Update primary key to composite (id, created_at) for hypertable support
ALTER TABLE nodes
  DROP CONSTRAINT IF EXISTS nodes_pkey CASCADE;

ALTER TABLE nodes
  ADD CONSTRAINT nodes_pkey PRIMARY KEY (id, created_at);

-- Step 6: Create new indexes
CREATE INDEX IF NOT EXISTS idx_nodes_speaker ON nodes(speaker);
CREATE INDEX IF NOT EXISTS idx_nodes_content_gin ON nodes USING gin(to_tsvector('english', content));
CREATE INDEX IF NOT EXISTS idx_nodes_content_trgm ON nodes USING gin(content gin_trgm_ops);

-- Note: Foreign key constraints from relationships table will need to be recreated
-- if they existed, as the CASCADE on DROP CONSTRAINT would have removed them

-- Log the migration
DO $$
BEGIN
  RAISE NOTICE 'HTM refactored to conversation memory model: key/value → content/speaker';
  RAISE NOTICE 'Nodes table now ready for hypertable conversion';
END $$;
