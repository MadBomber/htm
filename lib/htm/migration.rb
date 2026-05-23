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
    def create_table(name, **, &)
      db.create_table(name, **, &)
    end

    def drop_table(name, **)
      db.drop_table(name, **)
    end

    def alter_table(name, &)
      db.alter_table(name, &)
    end

    def add_index(table, columns, **)
      db.add_index(table, columns, **)
    end

    def drop_index(table, columns, **)
      db.drop_index(table, columns, **)
    end

    def run(sql)
      db.run(sql)
    end

    def execute(sql)
      db.run(sql)
    end
  end
end
