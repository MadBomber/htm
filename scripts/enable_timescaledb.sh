#!/usr/bin/env bash
# Enable TimescaleDB extension by configuring shared_preload_libraries
#
# This script:
# 1. Backs up postgresql.conf
# 2. Adds shared_preload_libraries configuration
# 3. Restarts PostgreSQL
# 4. Verifies TimescaleDB is loaded
# 5. Enables the extension in htm_development database

set -e

echo "==========================================="
echo "Enable TimescaleDB for PostgreSQL 17"
echo "==========================================="
echo

# Set paths
PG_BIN=/opt/homebrew/opt/postgresql@17/bin
PG_DATA=/opt/homebrew/var/postgresql@17
PG_CONF=$PG_DATA/postgresql.conf

# Check if PostgreSQL is installed
if [ ! -d "$PG_DATA" ]; then
    echo "✗ PostgreSQL data directory not found: $PG_DATA"
    echo "Please run scripts/install_local_database.sh first"
    exit 1
fi

# Backup postgresql.conf
echo "Step 1: Backing up postgresql.conf..."
cp "$PG_CONF" "$PG_CONF.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Backup created"
echo

# Check if shared_preload_libraries is already configured
echo "Step 2: Configuring shared_preload_libraries..."
if grep -q "^shared_preload_libraries.*timescaledb" "$PG_CONF"; then
    echo "✓ TimescaleDB already configured in shared_preload_libraries"
else
    # Find the line with shared_preload_libraries (commented or not)
    if grep -q "^#shared_preload_libraries = ''" "$PG_CONF"; then
        # Replace the commented line
        sed -i '' "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'timescaledb'/" "$PG_CONF"
        echo "✓ Added TimescaleDB to shared_preload_libraries"
    elif grep -q "^shared_preload_libraries = ''" "$PG_CONF"; then
        # Replace empty setting
        sed -i '' "s/^shared_preload_libraries = ''/shared_preload_libraries = 'timescaledb'/" "$PG_CONF"
        echo "✓ Added TimescaleDB to shared_preload_libraries"
    elif grep -q "^shared_preload_libraries = '" "$PG_CONF"; then
        # Append to existing value
        sed -i '' "s/^shared_preload_libraries = '/&timescaledb, /" "$PG_CONF"
        echo "✓ Added TimescaleDB to existing shared_preload_libraries"
    else
        # Add new line after the commented one
        sed -i '' "/^#shared_preload_libraries/a\\
shared_preload_libraries = 'timescaledb'
" "$PG_CONF"
        echo "✓ Added shared_preload_libraries configuration"
    fi
fi
echo

# Restart PostgreSQL
echo "Step 3: Restarting PostgreSQL..."
echo "This may take a moment..."

# Stop PostgreSQL
$PG_BIN/pg_ctl -D "$PG_DATA" stop -m fast 2>/dev/null || true
sleep 2

# Start PostgreSQL
$PG_BIN/pg_ctl -D "$PG_DATA" -l "$PG_DATA/server.log" start

# Wait for server to be ready
echo "Waiting for PostgreSQL to start..."
for i in {1..30}; do
    if $PG_BIN/pg_isready -q; then
        break
    fi
    sleep 1
done

if ! $PG_BIN/pg_isready -q; then
    echo "✗ PostgreSQL failed to start"
    echo "Check log: $PG_DATA/server.log"
    echo
    echo "Last 20 lines of log:"
    tail -20 "$PG_DATA/server.log"
    echo
    echo "To restore your backup:"
    echo "  cp $PG_CONF.backup.* $PG_CONF"
    echo "  $PG_BIN/pg_ctl -D $PG_DATA -l $PG_DATA/server.log start"
    exit 1
fi

echo "✓ PostgreSQL restarted"
echo

# Verify TimescaleDB is loaded
echo "Step 4: Verifying TimescaleDB is loaded..."
PGUSER=$(whoami)
if $PG_BIN/psql -U $PGUSER postgres -tAc "SELECT 1 FROM pg_available_extensions WHERE name='timescaledb'" | grep -q 1; then
    echo "✓ TimescaleDB extension is available"
else
    echo "✗ TimescaleDB extension not found"
    echo "Check that symlinks are correct:"
    echo "  ls -la /opt/homebrew/Cellar/postgresql@17/17.6/lib/timescaledb*.dylib"
    exit 1
fi
echo

# Enable extension in htm_development
echo "Step 5: Enabling TimescaleDB in htm_development database..."
if $PG_BIN/psql -U $PGUSER htm_development -tAc "SELECT 1 FROM pg_extension WHERE extname='timescaledb'" | grep -q 1; then
    echo "✓ TimescaleDB already enabled in htm_development"
else
    $PG_BIN/psql -U $PGUSER htm_development -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"
    echo "✓ TimescaleDB enabled in htm_development"
fi
echo

# Show extension version
echo "Step 6: Verification..."
echo
echo "Loaded extensions in htm_development:"
$PG_BIN/psql -U $PGUSER htm_development -c "\dx"

echo
echo "==========================================="
echo "✓ TimescaleDB Enabled Successfully!"
echo "==========================================="
echo
echo "TimescaleDB is now active and will:"
echo "  ✓ Automatically partition time-series tables (hypertables)"
echo "  ✓ Enable compression policies for older data"
echo "  ✓ Improve query performance on large datasets"
echo
echo "To recreate HTM tables as hypertables:"
echo "  bundle exec rake htm:db:drop"
echo "  bundle exec rake htm:db:setup"
echo
echo "Backup saved: $PG_CONF.backup.*"
echo
