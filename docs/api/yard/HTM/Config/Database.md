# Module HTM::Config::Database <a id="module-HTM-Config-Database"></a>

|  |  |
| --- | --- |
| **Defined in** | lib/htm/config/database.rb |

## Public Instance Methods
### `actual_database_name()` <a id="method-i-actual_database_name"></a> <a id="actual_database_name-instance_method"></a>
Extract the actual database name from URL or config
- **`@return`** [String, nil] the database name

### `database_config()` <a id="method-i-database_config"></a> <a id="database_config-instance_method"></a>
Not documented.

### `database_configured?()` <a id="method-i-database_configured-3F"></a> <a id="database_configured?-instance_method"></a>
- **`@return`** [Boolean]

### `database_host()` <a id="method-i-database_host"></a> <a id="database_host-instance_method"></a>
- **`@return`** [String, nil] the database host

### `database_name()` <a id="method-i-database_name"></a> <a id="database_name-instance_method"></a>
- **`@return`** [String, nil] the database name

### `database_password()` <a id="method-i-database_password"></a> <a id="database_password-instance_method"></a>
- **`@return`** [String, nil] the database password

### `database_port()` <a id="method-i-database_port"></a> <a id="database_port-instance_method"></a>
- **`@return`** [Integer, nil] the database port

### `database_url()` <a id="method-i-database_url"></a> <a id="database_url-instance_method"></a>
Database convenience methods

### `database_user()` <a id="method-i-database_user"></a> <a id="database_user-instance_method"></a>
- **`@return`** [String, nil] the database user

### `expected_database_name()` <a id="method-i-expected_database_name"></a> <a id="expected_database_name-instance_method"></a>
Returns the expected database name based on service.name and environment
- **`@return`** [String] expected database name in format "{service_name}_{environment}"

**`@example`**
```ruby
config.service.name = "htm"
HTM_ENV = "test"
config.expected_database_name  # => "htm_test"
```

### `parse_database_url()` <a id="method-i-parse_database_url"></a> <a id="parse_database_url-instance_method"></a>
Parse database URL into component hash
- **`@return`** [Hash, nil] parsed components or nil if no URL

### `valid_database_name?()` <a id="method-i-valid_database_name-3F"></a> <a id="valid_database_name?-instance_method"></a>
Check if the database name matches the expected convention
- **`@return`** [Boolean] true if database name matches expected

### `validate_database!()` <a id="method-i-validate_database-21"></a> <a id="validate_database!-instance_method"></a>
Validate that database is configured for the current environment
- **`@raise`** [HTM::ConfigurationError] if database is not configured
- **`@return`** [true] if database is configured

### `validate_database_name!()` <a id="method-i-validate_database_name-21"></a> <a id="validate_database_name!-instance_method"></a>
Validate that the database name follows the naming convention

Database names must be: {service_name}_{environment}
- **`@raise`** [HTM::ConfigurationError] if database name doesn't match expected
- **`@return`** [true] if database name is valid

**@example Valid configurations**
```ruby
HTM_ENV=test, service.name=htm, database=htm_test        # OK
HTM_ENV=production, service.name=payroll, database=payroll_production  # OK
```

**@example Invalid configurations (will raise)**
```ruby
HTM_ENV=test, service.name=htm, database=htm_production  # Wrong environment
HTM_ENV=test, service.name=htm, database=payroll_test    # Wrong service
HTM_ENV=test, service.name=htm, database=mydb            # Wrong format
```
