# Class HTM::Database <a id="class-HTM-Database"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/database.rb |

Database setup and configuration for HTM Handles schema creation and database
initialization using Sequel

## Public Class Methods
### `default_config()` <a id="method-c-default_config"></a> <a id="default_config-class_method"></a>
Get default database configuration

Uses HTM::Config for database settings.
- **`@return`** [Hash, nil] Connection configuration hash with PG-style keys

### `drop(db_url = nil)` <a id="method-c-drop"></a> <a id="drop-class_method"></a>
Drop all HTM tables (respects RAILS_ENV)
- **`@param`** `db_url` [String] Database connection URL (uses default_config if not provided)
- **`@return`** [void]

### `dump_schema(db_url = nil)` <a id="method-c-dump_schema"></a> <a id="dump_schema-class_method"></a>
Dump current database schema to db/schema.sql (respects RAILS_ENV)

Uses pg_dump to create a clean SQL schema file without data
- **`@param`** `db_url` [String] Database connection URL (uses default_config if not provided)
- **`@return`** [void]

### `generate_docs(db_url = nil)` <a id="method-c-generate_docs"></a> <a id="generate_docs-class_method"></a>
Generate database documentation using tbls
- **`@param`** `db_url` [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
- **`@return`** [void]

### `info(db_url = nil)` <a id="method-c-info"></a> <a id="info-class_method"></a>
Show database info (respects RAILS_ENV)
- **`@param`** `db_url` [String] Database connection URL (uses default_config if not provided)
- **`@return`** [void]

### `load_schema(db_url = nil)` <a id="method-c-load_schema"></a> <a id="load_schema-class_method"></a>
Load schema from db/schema.sql (respects RAILS_ENV)

Uses psql to load the schema file
- **`@param`** `db_url` [String] Database connection URL (uses default_config if not provided)
- **`@return`** [void]

### `migrate(db_url = nil)` <a id="method-c-migrate"></a> <a id="migrate-class_method"></a>
Run pending database migrations
- **`@param`** `db_url` [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
- **`@return`** [void]

### `migration_status(db_url = nil)` <a id="method-c-migration_status"></a> <a id="migration_status-class_method"></a>
Show migration status
- **`@param`** `db_url` [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
- **`@return`** [void]

### `parse_connection_params()` <a id="method-c-parse_connection_params"></a> <a id="parse_connection_params-class_method"></a>
Build config from individual environment variables
- **`@return`** [Hash, nil] Connection configuration hash

### `parse_connection_url(url)` <a id="method-c-parse_connection_url"></a> <a id="parse_connection_url-class_method"></a>
Parse database connection URL
- **`@param`** `url` [String] Connection URL (e.g., postgresql://user:pass@host:port/dbname)
- **`@raise`** [ArgumentError] If URL format is invalid
- **`@return`** [Hash, nil] Connection configuration hash

### `seed(db_url = nil)` <a id="method-c-seed"></a> <a id="seed-class_method"></a>
Seed database with sample data

Loads and executes db/seeds.rb file following Rails conventions.
- **`@param`** `db_url` [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
- **`@return`** [void]

### `setup(db_url = nil, run_migrations: true, dump_schema: false)` <a id="method-c-setup"></a> <a id="setup-class_method"></a>
Set up the HTM database schema
- **`@param`** `db_url` [String] Database connection URL (uses ENV['HTM_DATABASE__URL'] if not provided)
- **`@param`** `run_migrations` [Boolean] Whether to run migrations (default: true)
- **`@param`** `dump_schema` [Boolean] Whether to dump schema to db/schema.sql after setup (default: false)
- **`@return`** [void]
