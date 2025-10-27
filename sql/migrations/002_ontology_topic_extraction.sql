-- Migration: Ontology Support for Hierarchical Topics
-- Created: 2025-10-26
-- Updated: 2025-10-27 (Removed automatic LLM extraction, see ADR-012 reversal)
--
-- This migration provides schema support for hierarchical topic organization.
-- Topics use colon-delimited format (e.g., database:postgresql:performance)
-- and are stored in the existing tags table.
--
-- Topic assignment is now done manually via the tags parameter when adding messages.
-- Future implementations may add client-side LLM topic extraction.

-- Index for efficient topic hierarchy queries
-- This supports queries like: WHERE tag LIKE 'database:postgresql%'
CREATE INDEX IF NOT EXISTS idx_tags_tag_pattern ON tags(tag text_pattern_ops);

-- View to explore the ontology structure
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

-- View to see topic co-occurrence (nodes that share topics)
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

-- Comment explaining the ontology system
COMMENT ON VIEW ontology_structure IS
  'Provides a hierarchical view of all topics in the knowledge base. Topics are in colon-delimited format (e.g., database:postgresql:timescaledb) and are assigned manually via tags.';
COMMENT ON VIEW topic_relationships IS
  'Shows which topics co-occur on the same nodes, revealing cross-topic relationships in the knowledge base.';
