# frozen_string_literal: true

class CreateFileSources < ActiveRecord::Migration[7.1]
  def change
    create_table :file_sources, comment: 'Source file metadata for loaded documents' do |t|
      t.text :file_path, null: false, comment: 'Absolute path to source file'
      t.string :file_hash, limit: 64, comment: 'SHA-256 hash of file content'
      t.timestamptz :mtime, comment: 'File modification time'
      t.integer :file_size, comment: 'File size in bytes'
      t.jsonb :frontmatter, default: {}, comment: 'Parsed YAML frontmatter'
      t.timestamptz :last_synced_at, comment: 'When file was last synced to HTM'
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamptz :updated_at, default: -> { 'CURRENT_TIMESTAMP' }
    end

    add_index :file_sources, :file_path, unique: true, name: 'idx_file_sources_path_unique'
    add_index :file_sources, :file_hash, name: 'idx_file_sources_hash'
    add_index :file_sources, :last_synced_at, name: 'idx_file_sources_last_synced'
  end
end
