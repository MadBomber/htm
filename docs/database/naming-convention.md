# Database Naming Convention

HTM enforces a strict database naming convention to prevent accidental data corruption or loss from operating on the wrong database.

## The Convention

Database names **must** follow this exact format:

```
{service_name}_{environment}
```

Where:
- `service_name` is the value of `config.service.name` (default: `htm`)
- `environment` is the value of `HTM_ENV` (or `RAILS_ENV` / `RACK_ENV` fallback)

## Valid Examples

| Service Name | Environment | Expected Database Name |
|--------------|-------------|------------------------|
| `htm` | `development` | `htm_development` |
| `htm` | `test` | `htm_test` |
| `htm` | `production` | `htm_production` |
| `payroll` | `development` | `payroll_development` |
| `payroll` | `production` | `payroll_production` |

## Why This Matters

Without strict enforcement, dangerous misconfigurations can go undetected:

### Scenario 1: Environment Mismatch

```bash
# Developer thinks they're in test, but connected to production
HTM_ENV=test
HTM_DATABASE__URL="postgresql://user@host/htm_production"

rake htm:db:drop  # DISASTER: Drops production database!
```

With the naming convention enforced, this command fails immediately:

```
Error: Database name does not follow naming convention!

  Database names must be: {service_name}_{environment}

  Service name: htm
  Environment:  test
  Expected:     htm_test
  Actual:       htm_production
```

### Scenario 2: Service Mismatch

```bash
# HTM configured to use another application's database
HTM_ENV=production
# service.name = "htm" (default)
HTM_DATABASE__URL="postgresql://user@host/payroll_production"

rake htm:db:setup  # DISASTER: Corrupts payroll application's data!
```

With enforcement, this fails:

```
Error: Database name does not follow naming convention!

  Service name: htm
  Environment:  production
  Expected:     htm_production
  Actual:       payroll_production
```

## How Enforcement Works

### Validation Points

The naming convention is validated at these points:

1. **All rake tasks** that depend on `htm:db:validate` (setup, migrate, drop, etc.)
2. **Programmatic access** via `HTM.config.validate_database_name!`

### No Bypass Option

There is no way to skip this validation. If your database name doesn't match the convention, you must either:

1. Rename your database to match the convention
2. Change `HTM_ENV` to match the database suffix
3. Change `config.service.name` to match the database prefix

## Configuration

### Setting the Service Name

The service name defaults to `htm`. To use a different name:

**Via environment variable:**
```bash
export HTM_SERVICE__NAME="myapp"
```

**Via configuration file (`config/htm.yml`):**
```yaml
service:
  name: myapp
```

**Via Ruby configuration:**
```ruby
HTM.configure do |config|
  config.service.name = "myapp"
end
```

### Setting the Environment

Environment is determined by (in priority order):

1. `HTM_ENV`
2. `RAILS_ENV`
3. `RACK_ENV`
4. Default: `development`

**Valid environments:**
- `development`
- `test`
- `production`

These correspond to the top-level keys in `config/defaults.yml`.

## Validation Methods

### Check if Database Name is Valid

```ruby
config = HTM.config

# Boolean check
if config.valid_database_name?
  puts "Database name is correct"
else
  puts "Expected: #{config.expected_database_name}"
  puts "Actual: #{config.actual_database_name}"
end
```

### Raise Error on Invalid Name

```ruby
config = HTM.config

# Raises HTM::ConfigurationError if invalid
config.validate_database_name!
```

### Get Expected and Actual Names

```ruby
config = HTM.config

config.expected_database_name  # => "htm_test"
config.actual_database_name    # => Extracted from URL or config
```

## Rake Task Validation

All database-related rake tasks run validation automatically:

```bash
# These all validate the naming convention first:
rake htm:db:setup
rake htm:db:migrate
rake htm:db:drop
rake htm:db:reset
rake htm:db:create
```

To validate manually without performing any operation:

```bash
rake htm:db:validate
```

## Migration Guide

If you have existing databases that don't follow the convention:

### Option 1: Rename the Database

```bash
# PostgreSQL
psql -c "ALTER DATABASE old_name RENAME TO htm_development;"
```

### Option 2: Export and Import

```bash
# Export from old database
pg_dump old_database > backup.sql

# Create new database with correct name
createdb htm_development

# Import to new database
psql htm_development < backup.sql
```

### Option 3: Change Your Service Name

If your database is named `myapp_production`, set your service name to match:

```bash
export HTM_SERVICE__NAME="myapp"
```

## Error Messages

When validation fails, you'll see a clear error message:

```
Error: Database name 'wrong_db' does not match expected 'htm_test'.
Database names must follow the convention: {service_name}_{environment}
  Service name: htm
  Environment:  test
  Expected:     htm_test
  Actual:       wrong_db

Either:
  - Set HTM_DATABASE__URL to point to 'htm_test'
  - Set HTM_DATABASE__NAME=htm_test
  - Change HTM_ENV to match the database suffix
```

## Summary

The strict database naming convention:

- **Prevents** accidental operations on wrong environments
- **Prevents** cross-application database corruption
- **Requires** exact match of `{service_name}_{environment}`
- **Has no bypass** - you must fix the configuration
- **Validates automatically** on all database operations
