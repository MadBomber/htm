-- Migration: Primary key policy
--
-- All tables use simple PRIMARY KEY (id), not composite keys.
-- No hypertable conversions are performed.
--
-- Tables:
-- - nodes: PRIMARY KEY (id) - uses indexed created_at for time-range queries
-- - operations_log: PRIMARY KEY (id) - uses indexed timestamp for time-range queries
-- - relationships: PRIMARY KEY (id)
-- - tags: PRIMARY KEY (id)
-- - robots: PRIMARY KEY (id)

-- No changes needed - all tables already have simple PRIMARY KEY (id)

-- Log the migration
DO $$
BEGIN
  RAISE NOTICE 'HTM primary key policy: All tables use simple PRIMARY KEY (id)';
  RAISE NOTICE 'Time-based tables (nodes, operations_log) use indexed timestamp columns for queries';
END $$;
