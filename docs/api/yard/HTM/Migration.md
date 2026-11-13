# Class HTM::Migration <a id="class-HTM-Migration"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/migration.rb |

Base class for Sequel migrations

Provides a simple interface for writing migrations compatible with HTM's
migration runner.

**`@example`**
```ruby
class CreateUsers < HTM::Migration
  def up
    create_table(:users) do
      primary_key :id
      String :name, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  def down
    drop_table(:users)
  end
end
```

## Attributes
### `db` [R] <a id="attribute-i-db"></a> <a id="db-instance_method"></a>
Returns the value of attribute db.

## Public Instance Methods
### `down()` <a id="method-i-down"></a> <a id="down-instance_method"></a>
Override in subclass (optional for irreversible migrations)
- **`@raise`** [NotImplementedError]

### `initialize(db)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
- **`@return`** [Migration] a new instance of Migration

### `up()` <a id="method-i-up"></a> <a id="up-instance_method"></a>
Override in subclass
- **`@raise`** [NotImplementedError]
