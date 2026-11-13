# Class HTM::SequelConfig <a id="class-HTM-SequelConfig"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/sequel_config.rb |

Sequel database configuration and model loading

Uses HTM::Config for database settings. Configuration can come from:
*   Environment variables (HTM_DATABASE__URL, HTM_DATABASE__HOST, etc.)
*   Programmatic configuration via HTM.configure

Sequel is fiber-safe by design, making it ideal for async/fiber-based
concurrency patterns used in HTM's job processing.

## Attributes
### `db` [R] <a id="attribute-c-db"></a> <a id="db-class_method"></a>
Database connection instance
- **`@return`** [Sequel::Database, nil]

## Public Class Methods
### `build_connection_string(config)` <a id="method-c-build_connection_string"></a> <a id="build_connection_string-class_method"></a>
Build connection string from config hash
- **`@param`** `config` [Hash] Database configuration
- **`@return`** [String] PostgreSQL connection string

### `connected?()` <a id="method-c-connected-3F"></a> <a id="connected?-class_method"></a>
Check if connection is established and active
- **`@return`** [Boolean]

### `connection_stats()` <a id="method-c-connection_stats"></a> <a id="connection_stats-class_method"></a>
Get connection pool statistics
- **`@return`** [Hash] Pool statistics

### `disconnect!()` <a id="method-c-disconnect-21"></a> <a id="disconnect!-class_method"></a>
Close all database connections
- **`@return`** [void]

### `ensure_models_loaded!()` <a id="method-c-ensure_models_loaded-21"></a> <a id="ensure_models_loaded!-class_method"></a>
Ensure models are loaded

Call this after migrations to ensure models are available
- **`@return`** [void]

### `establish_connection!(load_models: true)` <a id="method-c-establish_connection-21"></a> <a id="establish_connection!-class_method"></a>
Establish database connection from HTM::Config
- **`@param`** `load_models` [Boolean] Whether to load models after connection (default: true)
Set to false when running migrations on a fresh database
- **`@return`** [Sequel::Database] The database connection

### `execute(sql)` <a id="method-c-execute"></a> <a id="execute-class_method"></a>
Run raw SQL
- **`@param`** `sql` [String] SQL to execute
- **`@return`** [void]

### `load_database_config()` <a id="method-c-load_database_config"></a> <a id="load_database_config-class_method"></a>
Load database configuration from HTM::Config
- **`@return`** [Hash] Database configuration hash

### `models_loadable?()` <a id="method-c-models_loadable-3F"></a> <a id="models_loadable?-class_method"></a>
Check if models can be loaded (tables exist)
- **`@return`** [Boolean]

### `select_value(sql)` <a id="method-c-select_value"></a> <a id="select_value-class_method"></a>
Select a single value
- **`@param`** `sql` [String] SQL query
- **`@return`** [Object] The value

### `verify_extensions!()` <a id="method-c-verify_extensions-21"></a> <a id="verify_extensions!-class_method"></a>
Verify required extensions are available
- **`@raise`** [RuntimeError] if required extensions are missing
- **`@return`** [true]
