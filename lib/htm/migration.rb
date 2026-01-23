# frozen_string_literal: true

class HTM
  # Base class for Sequel migrations
  #
  # Provides a simple interface for writing migrations compatible with
  # HTM's migration runner.
  #
  # @example
  #   class CreateUsers < HTM::Migration
  #     def up
  #       create_table(:users) do
  #         primary_key :id
  #         String :name, null: false
  #         DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
  #       end
  #     end
  #
  #     def down
  #       drop_table(:users)
  #     end
  #   end
  #
  class Migration
    attr_reader :db

    def initialize(db)
      @db = db
    end

    # Override in subclass
    def up
      raise NotImplementedError, "#{self.class}#up must be implemented"
    end

    # Override in subclass (optional for irreversible migrations)
    def down
      raise NotImplementedError, "#{self.class}#down must be implemented"
    end

    private

    # Delegate common methods to db
    def create_table(name, **options, &block)
      db.create_table(name, **options, &block)
    end

    def drop_table(name, **options)
      db.drop_table(name, **options)
    end

    def alter_table(name, &block)
      db.alter_table(name, &block)
    end

    def add_index(table, columns, **options)
      db.add_index(table, columns, **options)
    end

    def drop_index(table, columns, **options)
      db.drop_index(table, columns, **options)
    end

    def run(sql)
      db.run(sql)
    end

    def execute(sql)
      db.run(sql)
    end
  end
end
