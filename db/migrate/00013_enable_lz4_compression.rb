# frozen_string_literal: true

class EnableLz4Compression < ActiveRecord::Migration[7.0]
  def up
    # Switch TOAST compression from pglz to lz4 for better read performance
    # LZ4 decompression is ~32% faster than pglz with only marginally lower compression ratio
    # See: https://www.depesz.com/2025/11/29/using-json-json-vs-jsonb-pglz-vs-lz4-key-optimization-parsing-speed/

    # nodes.metadata - JSONB column for flexible key-value storage
    execute <<~SQL
      ALTER TABLE nodes ALTER COLUMN metadata SET COMPRESSION lz4;
    SQL

    # nodes.content - TEXT column containing memory content
    execute <<~SQL
      ALTER TABLE nodes ALTER COLUMN content SET COMPRESSION lz4;
    SQL

    # file_sources.frontmatter - JSONB column for parsed YAML frontmatter
    execute <<~SQL
      ALTER TABLE file_sources ALTER COLUMN frontmatter SET COMPRESSION lz4;
    SQL

    # Note: Existing rows retain their original compression until rewritten.
    # To recompress existing data, run: VACUUM FULL nodes; VACUUM FULL file_sources;
    # This is optional and can be done during a maintenance window.
  end

  def down
    # Revert to default pglz compression
    execute <<~SQL
      ALTER TABLE nodes ALTER COLUMN metadata SET COMPRESSION pglz;
    SQL

    execute <<~SQL
      ALTER TABLE nodes ALTER COLUMN content SET COMPRESSION pglz;
    SQL

    execute <<~SQL
      ALTER TABLE file_sources ALTER COLUMN frontmatter SET COMPRESSION pglz;
    SQL
  end
end
