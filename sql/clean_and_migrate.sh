#!/bin/bash

# HandReceipt Database Clean and Migration Script
# This script will safely clean existing test data and apply all migrations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Database connection parameters
# These can be overridden by environment variables
DB_HOST=${HANDRECEIPT_DATABASE_HOST:-"localhost"}
DB_PORT=${HANDRECEIPT_DATABASE_PORT:-5432}
DB_USER=${HANDRECEIPT_DATABASE_USER:-"hradmin"}
DB_NAME=${HANDRECEIPT_DATABASE_NAME:-"handreceipt"}
DB_PASSWORD=${HANDRECEIPT_DATABASE_PASSWORD}

# Check if password is provided
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: Database password not provided${NC}"
    echo "Please set HANDRECEIPT_DATABASE_PASSWORD environment variable"
    echo "For Azure: export HANDRECEIPT_DATABASE_PASSWORD='your-azure-postgres-password'"
    exit 1
fi

echo -e "${YELLOW}HandReceipt Database Clean & Migration${NC}"
echo "========================================="
echo "Host: $DB_HOST"
echo "Port: $DB_PORT" 
echo "User: $DB_USER"
echo "Database: $DB_NAME"
echo ""

# Set PGPASSWORD for psql
export PGPASSWORD="$DB_PASSWORD"

# Function to run SQL commands
run_sql() {
    local sql_command="$1"
    local description="$2"
    
    echo -e "${YELLOW}$description${NC}"
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$sql_command" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Success${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed${NC}"
        return 1
    fi
}

# Function to run migration files
run_migration_file() {
    local migration_file="$1"
    local description="$2"
    
    echo -e "${YELLOW}Applying: $description${NC}"
    echo "  File: $migration_file"
    
    if [ ! -f "$migration_file" ]; then
        echo -e "${RED}  ✗ File not found: $migration_file${NC}"
        return 1
    fi
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$migration_file" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Success${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed${NC}"
        return 1
    fi
}

# Test database connection
echo -e "${YELLOW}Testing database connection...${NC}"
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to database${NC}"
    echo "Please check your connection parameters and ensure the database is running"
    exit 1
fi
echo -e "${GREEN}✓ Database connection successful${NC}"
echo ""

# Show current state
echo -e "${YELLOW}Current database state:${NC}"
TABLES=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" | tr -d ' ')
USER_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'users'" | tr -d ' ')

echo "  Total tables: $TABLES"
if [ "$USER_COUNT" -eq "1" ]; then
    USERS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM users" | tr -d ' ')
    echo "  Users in database: $USERS"
fi
echo ""

# Warning about data deletion
echo -e "${RED}⚠️  WARNING: This will delete ALL existing data!${NC}"
echo "This script will:"
echo "  1. Drop all tables (including test users)"
echo "  2. Apply all migrations in correct order"  
echo "  3. Create a fresh database with new schema"
echo ""
echo -n "Are you sure you want to continue? (type 'yes' to confirm): "
read -r CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting database cleanup and migration...${NC}"
echo ""

# Drop all tables to start fresh
echo -e "${YELLOW}Dropping all existing tables...${NC}"
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
    DO \$\$ DECLARE
        r RECORD;
    BEGIN
        FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
            EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
        END LOOP;
    END \$\$;
" > /dev/null 2>&1

echo -e "${GREEN}✓ All tables dropped${NC}"
echo ""

# Now apply migrations in order
echo -e "${YELLOW}Applying migrations...${NC}"
echo ""

# Migration 001 - Initial Schema
if [ -f "sql/migrations/001_initial_schema.up.sql" ]; then
    run_migration_file "sql/migrations/001_initial_schema.up.sql" "Initial schema"
else
    echo -e "${YELLOW}⚠️  001_initial_schema.up.sql not found, skipping${NC}"
fi

# Migration 003 - NSN Catalog (skip 002 as it's deprecated)
if [ -f "sql/migrations/003_nsn_catalog.sql" ]; then
    run_migration_file "sql/migrations/003_nsn_catalog.sql" "NSN catalog tables"
else
    echo -e "${YELLOW}⚠️  003_nsn_catalog.sql not found, skipping${NC}"
fi

# Apply other migrations (004-017)
for i in {4..17}; do
    MIGRATION_FILE=$(find sql/migrations -name "${i}_*.sql" | head -1)
    if [ -n "$MIGRATION_FILE" ] && [ -f "$MIGRATION_FILE" ]; then
        DESCRIPTION=$(basename "$MIGRATION_FILE" .sql | sed 's/^[0-9]*_//' | tr '_' ' ')
        run_migration_file "$MIGRATION_FILE" "Migration $i: $DESCRIPTION"
    fi
done

# Migration 018 - Update User Name Fields (our new migration)
if [ -f "sql/migrations/018_update_user_name_fields.sql" ]; then
    run_migration_file "sql/migrations/018_update_user_name_fields.sql" "Update user name fields (FirstName/LastName)"
else
    echo -e "${RED}❌ 018_update_user_name_fields.sql not found!${NC}"
    echo "This migration is required for the new name field structure."
    exit 1
fi

echo ""
echo -e "${YELLOW}Verifying final database state...${NC}"

# Check final state
FINAL_TABLES=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" | tr -d ' ')
echo "  Total tables created: $FINAL_TABLES"

# Check users table structure
echo "  Checking users table structure..."
USER_COLUMNS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name IN ('first_name', 'last_name', 'password_hash')" | wc -l | tr -d ' ')
if [ "$USER_COLUMNS" -eq "3" ]; then
    echo -e "${GREEN}  ✓ Users table has correct structure (first_name, last_name, password_hash)${NC}"
else
    echo -e "${RED}  ✗ Users table structure may be incorrect${NC}"
fi

echo ""
echo -e "${GREEN}✅ Database cleanup and migration completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run your Azure deployment script"
echo "  2. The backend will connect to this clean database"
echo "  3. GORM AutoMigrate will add any additional tables needed"
echo ""
echo "The database is now ready with the new FirstName/LastName structure." 