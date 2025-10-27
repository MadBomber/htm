-- Migration: Ontology Topic Extraction with LLM
-- Created: 2025-10-26
--
-- This migration implements automatic hierarchical topic extraction from node content
-- using pgai's LLM integration. Topics are extracted in a colon-delimited format
-- (e.g., database:postgresql:performance) and stored in the tags table.
--
-- The topic extraction follows the same pattern as embedding generation (ADR-011)
-- with database-side AI processing via pgai triggers.
--
-- Environment Configuration:
-- - HTM_TOPIC_PROVIDER: LLM provider (default: 'ollama')
-- - HTM_TOPIC_MODEL: Model for topic extraction (default: 'llama3')
-- - HTM_TOPIC_BASE_URL: LLM endpoint (default: 'http://localhost:11434')

-- Function to extract ontological topics using pgai
CREATE OR REPLACE FUNCTION extract_ontology_topics()
RETURNS TRIGGER AS $$
DECLARE
  topic_provider TEXT;
  topic_model TEXT;
  base_url TEXT;
  llm_prompt TEXT;
  llm_response TEXT;
  extracted_topics TEXT[];
  topic TEXT;
BEGIN
  -- Get configuration from session variables or use defaults
  topic_provider := COALESCE(current_setting('htm.topic_provider', true), 'ollama');
  topic_model := COALESCE(current_setting('htm.topic_model', true), 'llama3');
  base_url := COALESCE(current_setting('htm.topic_base_url', true), 'http://localhost:11434');

  -- Build prompt for LLM with strict output formatting instructions
  llm_prompt := 'Extract hierarchical topic tags from this text.
Format as colon-separated paths (e.g., database:postgresql:performance).
Use lowercase with hyphens for multi-word terms (e.g., machine-learning).
Return ONLY the topic tags, one per line, no explanations or additional text.
Maximum depth: 5 levels.

Text: ' || NEW.value;

  -- Call LLM via pgai to extract topics
  IF topic_provider = 'ollama' THEN
    llm_response := ai.ollama_generate(
      topic_model,
      llm_prompt,
      system_prompt => 'You are a precise topic extraction system. Output only topic tags in the format root:subtopic:detail. No explanations.',
      host => base_url
    )->>'response';
  ELSE
    RAISE WARNING 'Topic provider % not yet supported. Only ollama is currently implemented.', topic_provider;
    RETURN NEW;
  END IF;

  -- Parse LLM response into array (split by newlines)
  extracted_topics := string_to_array(trim(llm_response), E'\n');

  -- Insert extracted topics into tags table with validation
  FOREACH topic IN ARRAY extracted_topics LOOP
    topic := trim(topic);

    -- Validate format: lowercase alphanumeric with hyphens, colon-separated
    -- Pattern: word(:word)* where word is [a-z0-9\-]+
    IF topic ~ '^[a-z0-9\-]+(:[a-z0-9\-]+)*$' THEN
      -- Insert topic, ignore if already exists for this node
      INSERT INTO tags (node_id, tag, created_at)
      VALUES (NEW.id, topic, CURRENT_TIMESTAMP)
      ON CONFLICT (node_id, tag) DO NOTHING;
    ELSE
      -- Log invalid topics as warnings
      RAISE WARNING 'Invalid topic format ignored: "%". Expected format: root:sub:detail', topic;
    END IF;
  END LOOP;

  RETURN NEW;

EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the INSERT/UPDATE
    -- This ensures topic extraction failures don't block normal operations
    RAISE WARNING 'Topic extraction failed for node %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically extract topics on INSERT and UPDATE
DROP TRIGGER IF EXISTS nodes_extract_topics ON nodes;
CREATE TRIGGER nodes_extract_topics
  AFTER INSERT OR UPDATE OF value ON nodes
  FOR EACH ROW
  EXECUTE FUNCTION extract_ontology_topics();

-- Helper function to configure topic extraction settings
CREATE OR REPLACE FUNCTION htm_set_topic_config(
  provider TEXT DEFAULT 'ollama',
  model TEXT DEFAULT 'llama3',
  base_url TEXT DEFAULT 'http://localhost:11434'
) RETURNS void AS $$
BEGIN
  PERFORM set_config('htm.topic_provider', provider, false);
  PERFORM set_config('htm.topic_model', model, false);
  PERFORM set_config('htm.topic_base_url', base_url, false);

  RAISE NOTICE 'HTM topic extraction configured: provider=%, model=%, base_url=%', provider, model, base_url;
END;
$$ LANGUAGE plpgsql;

-- Set default configuration for Ollama with llama3
SELECT htm_set_topic_config();

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
COMMENT ON TRIGGER nodes_extract_topics ON nodes IS
  'Automatically extracts hierarchical ontological topics from node content using LLM via pgai. Topics stored in tags table with colon-delimited format (e.g., database:postgresql:timescaledb).';
COMMENT ON FUNCTION extract_ontology_topics() IS
  'Calls LLM (via pgai) to extract hierarchical topic tags from node content. Validates format and stores in tags table. Errors logged as warnings without failing the operation.';
COMMENT ON FUNCTION htm_set_topic_config(TEXT, TEXT, TEXT) IS
  'Configure LLM settings for topic extraction: provider (ollama), model (llama3), and base_url (http://localhost:11434).';
