-- Migration: Add composite primary keys for TimescaleDB hypertables
--
-- TimescaleDB requires that the partitioning column be part of the primary key
-- when converting tables to hypertables. This migration updates the primary keys
-- to include the time-partitioning columns.
--
-- Changes:
-- - operations_log: PRIMARY KEY (id) -> PRIMARY KEY (id, timestamp)
-- - nodes: PRIMARY KEY (id) -> PRIMARY KEY (id, created_at)

-- Operations Log: Add timestamp to primary key
-- This allows TimescaleDB to partition by timestamp
ALTER TABLE operations_log
  DROP CONSTRAINT IF EXISTS operations_log_pkey CASCADE;

ALTER TABLE operations_log
  ADD CONSTRAINT operations_log_pkey PRIMARY KEY (id, timestamp);

-- Nodes: Add created_at to primary key
-- This allows TimescaleDB to partition by created_at
ALTER TABLE nodes
  DROP CONSTRAINT IF EXISTS nodes_pkey CASCADE;

ALTER TABLE nodes
  ADD CONSTRAINT nodes_pkey PRIMARY KEY (id, created_at);

-- Note: Foreign key constraints that reference these tables may need to be updated
-- if they exist. The CASCADE on DROP CONSTRAINT will handle removing them,
-- but they would need to be recreated if necessary.

-- Log the migration
DO $$
BEGIN
  RAISE NOTICE 'HTM composite primary keys configured for TimescaleDB hypertables';
END $$;
