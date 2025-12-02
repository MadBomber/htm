# Class: HTM::Database
**Inherits:** Object
    

Database setup and configuration for HTM Handles schema creation and database
initialization


# Class Methods
## default_config() [](#method-c-default_config)
Get default database configuration
**@return** [Hash, nil] Connection configuration hash

## drop(db_url nil) [](#method-c-drop)
Drop all HTM tables
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## dump_schema(db_url nil) [](#method-c-dump_schema)
Dump current database schema to db/schema.sql

Uses pg_dump to create a clean SQL schema file without data
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## generate_docs(db_url nil) [](#method-c-generate_docs)
Generate database documentation using tbls

Uses .tbls.yml configuration file for output directory and settings. Creates
comprehensive database documentation including:
*   Entity-relationship diagrams
*   Table schemas with comments
*   Index information
*   Relationship diagrams
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## info(db_url nil) [](#method-c-info)
Show database info
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## load_schema(db_url nil) [](#method-c-load_schema)
Load schema from db/schema.sql

Uses psql to load the schema file
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## migrate(db_url nil) [](#method-c-migrate)
Run pending database migrations
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## migration_status(db_url nil) [](#method-c-migration_status)
Show migration status
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## parse_connection_params() [](#method-c-parse_connection_params)
Build config from individual environment variables
**@return** [Hash, nil] Connection configuration hash

## parse_connection_url(url ) [](#method-c-parse_connection_url)
Parse database connection URL
**@param** [String] Connection URL (e.g., postgresql://user:pass@host:port/dbname)

**@raise** [ArgumentError] If URL format is invalid

**@return** [Hash, nil] Connection configuration hash

## seed(db_url nil) [](#method-c-seed)
Seed database with sample data

Loads and executes db/seeds.rb file following Rails conventions. All seeding
logic is contained in db/seeds.rb and reads data from markdown files in
db/seed_data/ directory.
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@return** [void] 

## setup(db_url nil, run_migrations: true, dump_schema: false) [](#method-c-setup)
Set up the HTM database schema
**@param** [String] Database connection URL (uses ENV['HTM_DBURL'] if not provided)

**@param** [Boolean] Whether to run migrations (default: true)

**@param** [Boolean] Whether to dump schema to db/schema.sql after setup (default: false)

**@return** [void] 


