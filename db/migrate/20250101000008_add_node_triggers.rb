# frozen_string_literal: true

class AddNodeTriggers < ActiveRecord::Migration[7.1]
  def up
    # Function to update updated_at timestamp
    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
      END;
      $$ language 'plpgsql'
    SQL

    # Trigger for nodes table
    execute <<-SQL
      DROP TRIGGER IF EXISTS update_nodes_updated_at ON nodes
    SQL

    execute <<-SQL
      CREATE TRIGGER update_nodes_updated_at
        BEFORE UPDATE ON nodes
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column()
    SQL

    # Function to validate embedding dimensions
    execute <<-SQL
      CREATE OR REPLACE FUNCTION validate_embedding_dimension()
      RETURNS TRIGGER AS $$
      BEGIN
        IF NEW.embedding IS NOT NULL AND NEW.embedding_dimension IS NOT NULL THEN
          -- Validation happens at application layer
          -- This function is a placeholder for future validation logic
          NULL;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql
    SQL

    # Trigger for embedding validation
    execute <<-SQL
      DROP TRIGGER IF EXISTS trigger_validate_embedding_dimension ON nodes
    SQL

    execute <<-SQL
      CREATE TRIGGER trigger_validate_embedding_dimension
        BEFORE INSERT OR UPDATE ON nodes
        FOR EACH ROW
        EXECUTE FUNCTION validate_embedding_dimension()
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS trigger_validate_embedding_dimension ON nodes'
    execute 'DROP TRIGGER IF EXISTS update_nodes_updated_at ON nodes'
    execute 'DROP FUNCTION IF EXISTS validate_embedding_dimension()'
    execute 'DROP FUNCTION IF EXISTS update_updated_at_column()'
  end
end
