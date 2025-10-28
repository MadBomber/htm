# frozen_string_literal: true

class EnableExtensions < ActiveRecord::Migration[7.1]
  def up
    # Note: On TimescaleDB Cloud, the extension is named 'vector' not 'pgvector'
    enable_extension 'vector'
    enable_extension 'pg_trgm'
  end

  def down
    disable_extension 'pg_trgm'
    disable_extension 'vector'
  end
end
