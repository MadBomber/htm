# frozen_string_literal: true

require_relative '../../lib/htm/migration'

class CreateFileSources < HTM::Migration
  def up
    create_table(:file_sources) do
      primary_key :id
      String :file_path, text: true, null: false
      String :file_hash, size: 64
      DateTime :mtime
      Integer :file_size
      column :frontmatter, :jsonb, default: Sequel.lit("'{}'::jsonb")
      DateTime :last_synced_at
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, default: Sequel::CURRENT_TIMESTAMP
    end

    add_index :file_sources, :file_path, unique: true, name: :idx_file_sources_path_unique
    add_index :file_sources, :file_hash, name: :idx_file_sources_hash
    add_index :file_sources, :last_synced_at, name: :idx_file_sources_last_synced

    run "COMMENT ON TABLE file_sources IS 'Source file metadata for loaded documents'"
    run "COMMENT ON COLUMN file_sources.file_path IS 'Absolute path to source file'"
    run "COMMENT ON COLUMN file_sources.file_hash IS 'SHA-256 hash of file content'"
    run "COMMENT ON COLUMN file_sources.mtime IS 'File modification time'"
    run "COMMENT ON COLUMN file_sources.file_size IS 'File size in bytes'"
    run "COMMENT ON COLUMN file_sources.frontmatter IS 'Parsed YAML frontmatter'"
    run "COMMENT ON COLUMN file_sources.last_synced_at IS 'When file was last synced to HTM'"

    # LZ4 compression for better read performance on JSONB column
    run "ALTER TABLE file_sources ALTER COLUMN frontmatter SET COMPRESSION lz4"
  end

  def down
    drop_table(:file_sources)
  end
end
