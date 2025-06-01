#!/bin/bash

# HandReceipt Database Migration Script
# This script applies all migrations in the correct order

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-handreceipt}"
DB_USER="${DB_USER:-postgres}"

echo -e "${GREEN}HandReceipt Database Migration Script${NC}"
echo "======================================="
echo ""

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql is not installed${NC}"
    exit 1
fi

# Prompt for database password
echo -n "Enter database password for user $DB_USER: "
read -s DB_PASS
echo ""

# Export for psql to use
export PGPASSWORD=$DB_PASS

# Test database connection
echo -e "${YELLOW}Testing database connection...${NC}"
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}Error: Cannot connect to database${NC}"
    echo "Please check your connection settings:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    exit 1
fi
echo -e "${GREEN}✓ Database connection successful${NC}"
echo ""

# Create backup
BACKUP_FILE="handreceipt_backup_$(date +%Y%m%d_%H%M%S).sql"
echo -e "${YELLOW}Creating backup: $BACKUP_FILE${NC}"
pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > $BACKUP_FILE
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Backup created successfully${NC}"
else
    echo -e "${RED}Error creating backup${NC}"
    exit 1
fi
echo ""

# Function to run a migration
run_migration() {
    local migration_file=$1
    local description=$2
    
    echo -e "${YELLOW}Applying: $description${NC}"
    echo "  File: $migration_file"
    
    if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$migration_file" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Success${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Failed${NC}"
        return 1
    fi
}

# Check current schema state
echo -e "${YELLOW}Checking current schema state...${NC}"
TABLES=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'")
echo "  Current tables in database: $TABLES"
echo ""

# Apply migrations in order
echo -e "${YELLOW}Starting migration process...${NC}"
echo ""

# Migration 001
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'users'" | grep -q 1; then
    run_migration "sql/migrations/001_initial_schema.up.sql" "Initial schema"
else
    echo -e "${GREEN}✓ Initial schema already exists${NC}"
fi

# Skip Migration 002 (QR codes)
echo -e "${YELLOW}Skipping: QR codes table (feature removed)${NC}"
echo "  File: sql/migrations/002_add_qr_codes_table.sql"
echo -e "${GREEN}  ✓ Skipped${NC}"

# Migration 003
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'nsn_items'" | grep -q 1; then
    run_migration "sql/migrations/003_nsn_catalog.sql" "NSN catalog tables"
else
    echo -e "${GREEN}✓ NSN catalog already exists${NC}"
fi

# Migration 004
run_migration "sql/migrations/004_update_users_table.sql" "User table updates"

# Migration 005 - with warning
echo -e "${YELLOW}Warning: Migration 005 may have conflicts${NC}"
echo -n "Apply migration 005_schema_reconciliation.sql? (y/N): "
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    run_migration "sql/migrations/005_schema_reconciliation.sql" "Schema reconciliation"
else
    echo -e "${YELLOW}  ⚠ Skipped by user${NC}"
fi

# Migration 006
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'user_connections'" | grep -q 1; then
    run_migration "sql/migrations/006_transfer_system_refactor_phase1.sql" "Transfer system refactor"
else
    echo -e "${GREEN}✓ Transfer system refactor already applied${NC}"
fi

# Migration 007
if ! psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'transfer_offers'" | grep -q 1; then
    run_migration "sql/migrations/007_transfer_offers_system.sql" "Transfer offers system"
else
    echo -e "${GREEN}✓ Transfer offers system already exists${NC}"
fi

# Migration 008
run_migration "sql/migrations/008_complete_schema_alignment.sql" "Complete schema alignment"

echo ""
echo -e "${YELLOW}Loading seed data...${NC}"

# Load NSN records
run_migration "sql/seed_nsn_records.sql" "NSN records seed data"

# Ask about development data
echo ""
echo -n "Load development seed data? (y/N): "
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    run_migration "sql/dev_seed_connections.sql" "Development user connections"
    run_migration "sql/dev_seed_da2062.sql" "Development DA2062 imports"
fi

# Run verification
echo ""
echo -e "${YELLOW}Running schema verification...${NC}"
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f sql/verify_schema.sql > schema_verification.log 2>&1
echo -e "${GREEN}✓ Verification complete (see schema_verification.log)${NC}"

# Summary
echo ""
echo -e "${GREEN}Migration process complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Review schema_verification.log for any issues"
echo "2. Update your backend Go code to match the new schema"
echo "3. Remove QR code related endpoints and models"
echo "4. Test the application thoroughly"
echo ""
echo "Backup saved to: $BACKUP_FILE"

# Cleanup
unset PGPASSWORD 