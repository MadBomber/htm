# Class: HTM::ActiveRecordConfig
**Inherits:** Object
    

ActiveRecord database configuration and model loading


# Class Methods
## connected?() [](#method-c-connected?)
Check if connection is established and active
**@return** [Boolean] 

## connection_stats() [](#method-c-connection_stats)
Get connection pool statistics
## disconnect!() [](#method-c-disconnect!)
Close all database connections
## establish_connection!() [](#method-c-establish_connection!)
Establish database connection from config/database.yml
## load_database_config() [](#method-c-load_database_config)
Load and parse database configuration from YAML with ERB
## verify_extensions!() [](#method-c-verify_extensions!)
Verify required extensions are available

