#!/usr/bin/env bash
# HTM Local Database Setup Script
#
# This script performs a complete, automated installation of PostgreSQL 17
# with all required extensions for the HTM (Hierarchical Temporal Memory) library:
#   - PostgreSQL 17 (from Homebrew)
#   - pgvector - vector similarity search for embeddings
#   - pg_trgm - trigram matching for fuzzy text search
#
# This is the only script you need to run to get a fully functional
# local database environment for HTM development.
#
# Requirements:
#   - macOS with Homebrew installed
#
# Usage:
#   bash scripts/install_local_database.sh

set -e  # Exit on error

echo "=========================================="
echo "HTM Local Database Setup"
echo "=========================================="
echo

# Check for existing PostgreSQL
if brew list postgresql@17 &>/dev/null || brew list postgresql@16 &>/dev/null; then
    echo "⚠️  Found existing PostgreSQL installation"
    echo
    echo "This script will:"
    echo "  1. Stop current PostgreSQL services"
    echo "  2. Backup your database"
    echo "  3. Uninstall current PostgreSQL"
    echo "  4. Install PostgreSQL 17"
    echo "  5. Install all required extensions (pgvector, pg_trgm)"
    echo "  6. Restore your data"
    echo "  7. Start PostgreSQL with all extensions enabled"
    echo
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: Stop ALL PostgreSQL processes
echo
echo "Step 1: Stopping PostgreSQL services..."
brew services stop postgresql@17 2>/dev/null || true
brew services stop postgresql@16 2>/dev/null || true

# Force kill any remaining postgres processes
pkill -9 postgres 2>/dev/null || true
sleep 2

# Check if any processes remain
if pgrep -q postgres; then
    echo "⚠️  Warning: Some PostgreSQL processes are still running"
    pkill -KILL postgres 2>/dev/null || true
    sleep 2
fi

echo "✓ Services stopped"

# Step 2: Backup database
BACKUP_DIR="$HOME/postgresql_backup_$(date +%Y%m%d_%H%M%S)"
echo
echo "Step 2: Backing up database to $BACKUP_DIR..."

if [ -d "/opt/homebrew/var/postgresql@17" ]; then
    mkdir -p "$BACKUP_DIR"

    # Try to export database if possible
    CURRENT_USER=$(whoami)
    if command -v pg_dump &>/dev/null && psql -U $CURRENT_USER -lqt 2>/dev/null | grep -qw htm_development; then
        echo "Exporting htm_development database..."
        pg_dump -U $CURRENT_USER htm_development > "$BACKUP_DIR/htm_development.sql" 2>/dev/null || echo "Could not export database (server may be stopped)"
    fi

    # Copy data directory
    if [ -d "/opt/homebrew/var/postgresql@17" ]; then
        cp -r /opt/homebrew/var/postgresql@17 "$BACKUP_DIR/data" 2>/dev/null || true
        echo "✓ Data directory backed up"
    fi
else
    echo "No existing database found, skipping backup"
fi

# Step 3: Uninstall current PostgreSQL
echo
echo "Step 3: Uninstalling current PostgreSQL..."
brew uninstall --force postgresql@17 2>/dev/null || true
brew uninstall --force postgresql@16 2>/dev/null || true

# Clean up old data directory to start fresh
if [ -d "/opt/homebrew/var/postgresql@17" ]; then
    echo "Removing old data directory..."
    rm -rf /opt/homebrew/var/postgresql@17
fi

echo "✓ Uninstalled"

# Step 4: Install PostgreSQL
echo
echo "Step 4: Installing PostgreSQL 17..."

# Install standard PostgreSQL 17
echo "Installing postgresql@17..."
brew install postgresql@17

echo "✓ PostgreSQL installed"

# Step 5: Initialize and configure PostgreSQL
echo
echo "Step 5: Initializing PostgreSQL..."

# Set paths
PG_BIN=/opt/homebrew/opt/postgresql@17/bin
PG_DATA=/opt/homebrew/var/postgresql@17

# Ensure data directory is completely clean before initialization
if [ -d "$PG_DATA" ]; then
    echo "Removing existing data directory to start fresh..."
    rm -rf "$PG_DATA"
fi

# Initialize database cluster (initdb will create the directory)
echo "Initializing database cluster..."
$PG_BIN/initdb -D "$PG_DATA" --username=$(whoami) --auth=trust

# Configure postgresql.conf for better performance (macOS compatible)
echo "Configuring PostgreSQL..."
cat >> "$PG_DATA/postgresql.conf" <<EOF

# HTM Optimizations (macOS compatible)
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
# Note: effective_io_concurrency not supported on macOS
# Note: shared_preload_libraries configured later
EOF

# Start PostgreSQL
echo "Starting PostgreSQL..."
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
    cat "$PG_DATA/server.log"
    exit 1
fi

# Give PostgreSQL a moment to fully initialize
sleep 2

echo "✓ PostgreSQL started"

# Step 6: Create databases
echo
echo "Step 6: Setting up databases..."

# Get current username
PGUSER=$(whoami)

# Create default database for user
echo "Creating database for user $PGUSER..."
$PG_BIN/createdb -U $PGUSER $PGUSER 2>/dev/null && echo "✓ Created $PGUSER database" || {
    # Check if it already exists
    if $PG_BIN/psql -U $PGUSER -lqt | cut -d \| -f 1 | grep -qw $PGUSER; then
        echo "✓ User database already exists"
    else
        echo "✗ Failed to create user database and it doesn't exist"
        echo "Checking PostgreSQL connection..."
        $PG_BIN/psql -U $PGUSER postgres -c "SELECT version();" 2>&1 || true
        exit 1
    fi
}

# Create htm_development database
echo "Creating htm_development database..."
$PG_BIN/createdb -U $PGUSER htm_development 2>/dev/null && echo "✓ Created htm_development database" || {
    # Check if it already exists
    if $PG_BIN/psql -U $PGUSER -lqt | cut -d \| -f 1 | grep -qw htm_development; then
        echo "✓ htm_development already exists"
    else
        echo "✗ Failed to create htm_development database and it doesn't exist"
        echo "Checking connection..."
        $PG_BIN/psql -U $PGUSER -l 2>&1 | head -20
        exit 1
    fi
}

# Restore from backup if it exists
if [ -f "$BACKUP_DIR/htm_development.sql" ]; then
    echo "Restoring from backup..."
    $PG_BIN/psql -U $PGUSER htm_development < "$BACKUP_DIR/htm_development.sql" || echo "Could not restore backup (this is OK for fresh install)"
fi

echo "✓ Databases created"

# Step 7: Install extension dependencies
echo
echo "Step 7: Installing extension dependencies..."

# Install pgvector
if ! brew list pgvector &>/dev/null; then
    echo "Installing pgvector..."
    brew install pgvector
else
    echo "✓ pgvector already installed"
fi

echo "✓ Extension dependencies installed"

# Step 8: Create symlinks for extension files
echo
echo "Step 8: Creating extension file symlinks..."

# PostgreSQL from petere tap looks for extensions in its Cellar directory
# but Homebrew installs them in the shared location
PG_CELLAR_EXT=/opt/homebrew/Cellar/postgresql@17/17.6/share/extension
PG_CELLAR_LIB=/opt/homebrew/Cellar/postgresql@17/17.6/lib
PG_SHARED_EXT=/opt/homebrew/share/postgresql@17/extension
PG_SHARED_LIB=/opt/homebrew/lib/postgresql@17

# Create extension directory in Cellar if it doesn't exist
mkdir -p "$PG_CELLAR_EXT"
mkdir -p "$PG_CELLAR_LIB"

# Symlink pgvector files
if [ -f "$PG_SHARED_EXT/vector.control" ]; then
    echo "Symlinking pgvector extension files..."
    cd "$PG_CELLAR_EXT"
    ln -sf "$PG_SHARED_EXT"/vector* .
    cd "$PG_CELLAR_LIB"
    ln -sf "$PG_SHARED_LIB"/vector.dylib .
    echo "✓ pgvector symlinks created"
fi

echo "✓ Extension symlinks created"

# Step 9: Enable core extensions in database
echo
echo "Step 9: Enabling core extensions..."

# Enable extensions in database
echo "Enabling extensions in htm_development..."
$PG_BIN/psql -U $(whoami) htm_development -c "CREATE EXTENSION IF NOT EXISTS vector;" || {
    echo "✗ Failed to enable pgvector extension"
    echo "Check that symlinks were created correctly"
    exit 1
}
$PG_BIN/psql -U $(whoami) htm_development -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

echo "✓ Core extensions enabled"

# Step 10: Verify installation
echo
echo "Step 10: Verifying installation..."
echo

# Check all extensions
echo "Installed extensions:"
$PG_BIN/psql -U $(whoami) htm_development -c "\dx"

echo
echo "=========================================="
echo "✓ Setup Complete!"
echo "=========================================="
echo
echo "PostgreSQL is running with required extensions:"
echo "  ✓ pgvector (for embeddings)"
echo "  ✓ pg_trgm (for fuzzy search)"
echo
echo "Embeddings are generated client-side using Ollama."
echo "Make sure Ollama is installed and running:"
echo "  curl https://ollama.ai/install.sh | sh"
echo "  ollama pull nomic-embed-text"
echo
echo "Database: htm_development"
echo "Location: $PG_DATA"
echo "Log: $PG_DATA/server.log"
echo "Backup: $BACKUP_DIR"
echo
echo "PostgreSQL commands:"
echo "  Start:  $PG_BIN/pg_ctl -D $PG_DATA -l $PG_DATA/server.log start"
echo "  Stop:   $PG_BIN/pg_ctl -D $PG_DATA stop"
echo "  Status: $PG_BIN/pg_ctl -D $PG_DATA status"
echo
echo "Next steps:"
echo "  1. cd /Users/dewayne/sandbox/git_repos/madbomber/htm"
echo "  2. bundle exec rake htm:db:setup"
echo "  3. bundle exec rake htm:db:seed"
echo
