# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[7.1]
  def change
    create_table :tags, comment: 'Unique tag names for categorization' do |t|
      t.text :name, null: false, comment: 'Hierarchical tag in format: root:level1:level2 (e.g., database:postgresql:timescaledb)'
      t.timestamptz :created_at, default: -> { 'CURRENT_TIMESTAMP' }, comment: 'When this tag was created'
    end

    add_index :tags, :name, unique: true, name: 'idx_tags_name_unique'
    add_index :tags, :name, using: :btree, opclass: :text_pattern_ops, name: 'idx_tags_name_pattern'
  end
end
