# frozen_string_literal: true

class CreateViews < ActiveRecord::Migration[7.1]
  def up
    # View for node statistics
    execute <<-SQL
      CREATE OR REPLACE VIEW node_stats AS
      SELECT
        type,
        COUNT(*) as count,
        AVG(importance) as avg_importance,
        SUM(token_count) as total_tokens,
        MIN(created_at) as oldest,
        MAX(created_at) as newest
      FROM nodes
      GROUP BY type
    SQL

    execute "COMMENT ON VIEW node_stats IS 'Aggregated statistics by node type showing counts, importance, tokens, and age ranges.'"

    # View for robot activity
    execute <<-SQL
      CREATE OR REPLACE VIEW robot_activity AS
      SELECT
        r.id,
        r.name,
        COUNT(n.id) as total_nodes,
        MAX(n.created_at) as last_node_created
      FROM robots r
      LEFT JOIN nodes n ON n.robot_id = r.id
      GROUP BY r.id, r.name
    SQL

    execute "COMMENT ON VIEW robot_activity IS 'Robot usage metrics showing total nodes created and last activity timestamp.'"

    # View for hierarchical ontology structure
    execute <<-SQL
      CREATE OR REPLACE VIEW ontology_structure AS
      SELECT
        split_part(tag, ':', 1) AS root_topic,
        split_part(tag, ':', 2) AS level1_topic,
        split_part(tag, ':', 3) AS level2_topic,
        tag AS full_path,
        COUNT(DISTINCT node_id) AS node_count
      FROM tags
      WHERE tag ~ '^[a-z0-9\\-]+(:[a-z0-9\\-]+)*$'
      GROUP BY tag
      ORDER BY root_topic, level1_topic, level2_topic
    SQL

    execute "COMMENT ON VIEW ontology_structure IS 'Provides a hierarchical view of all topics in the knowledge base. Topics use colon-delimited format (e.g., database:postgresql:timescaledb) and are assigned manually via tags.'"

    # View for topic co-occurrence analysis
    execute <<-SQL
      CREATE OR REPLACE VIEW topic_relationships AS
      SELECT
        t1.tag AS topic1,
        t2.tag AS topic2,
        COUNT(DISTINCT t1.node_id) AS shared_nodes
      FROM tags t1
      JOIN tags t2 ON t1.node_id = t2.node_id AND t1.tag < t2.tag
      GROUP BY t1.tag, t2.tag
      HAVING COUNT(DISTINCT t1.node_id) >= 2
      ORDER BY shared_nodes DESC
    SQL

    execute "COMMENT ON VIEW topic_relationships IS 'Shows which topics co-occur on the same nodes, revealing cross-topic relationships in the knowledge base.'"
  end

  def down
    execute 'DROP VIEW IF EXISTS topic_relationships'
    execute 'DROP VIEW IF EXISTS ontology_structure'
    execute 'DROP VIEW IF EXISTS robot_activity'
    execute 'DROP VIEW IF EXISTS node_stats'
  end
end
