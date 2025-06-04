#!/bin/bash

# HandReceipt Migration Status Check Script
# This script checks if database migrations loaded successfully on Azure

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Azure Configuration
RESOURCE_GROUP="handreceipt-prod-rg"
POSTGRES_SERVER="handreceipt-prod-postgres"
DATABASE_NAME="handreceipt"
POSTGRES_USER="hradmin"

print_status "Checking HandReceipt database migration status..."

# Check if Azure CLI is logged in
if ! az account show >/dev/null 2>&1; then
    print_error "Please log in to Azure CLI first: az login"
    exit 1
fi

# Set subscription
az account set --subscription "98b9185a-60b8-4df4-b8a4-73e6d35b176f"

# Get PostgreSQL connection info
print_status "Getting PostgreSQL server information..."
POSTGRES_FQDN=$(az postgres flexible-server show \
    --name "$POSTGRES_SERVER" \
    --resource-group "$RESOURCE_GROUP" \
    --query "fullyQualifiedDomainName" \
    --output tsv)

if [ -z "$POSTGRES_FQDN" ]; then
    print_error "Could not find PostgreSQL server: $POSTGRES_SERVER"
    exit 1
fi

print_success "PostgreSQL server found: $POSTGRES_FQDN"

# Prompt for password
echo -n "Enter PostgreSQL password for user '$POSTGRES_USER': "
read -s POSTGRES_PASSWORD
echo

# Test connection
print_status "Testing database connection..."
if ! PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
    print_error "Failed to connect to database. Check your credentials and firewall rules."
    exit 1
fi

print_success "Database connection successful!"

# Check if migration tracking table exists
print_status "Checking for migration tracking..."
MIGRATION_TABLE_EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'schema_migrations'
    );" | xargs)

if [ "$MIGRATION_TABLE_EXISTS" = "t" ]; then
    print_success "Migration tracking table exists"
    
    print_status "Applied migrations:"
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
        SELECT version, applied_at 
        FROM schema_migrations 
        ORDER BY version;"
else
    print_warning "No schema_migrations table found. Checking for GORM migrations..."
    
    # Check for GORM migration tracking
    GORM_MIGRATION_EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'migrations'
        );" | xargs)
    
    if [ "$GORM_MIGRATION_EXISTS" = "t" ]; then
        print_success "GORM migration table exists"
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
            SELECT id, applied_at 
            FROM migrations 
            ORDER BY id;"
    fi
fi

# List all tables
print_status "Checking database tables..."
echo "=== DATABASE TABLES ==="
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
    SELECT schemaname, tablename, 
           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables 
    WHERE schemaname = 'public' 
    ORDER BY tablename;"

# Check critical HandReceipt tables
print_status "Checking HandReceipt core tables..."
CORE_TABLES=("users" "properties" "transfers" "audit_logs" "nsn_data")

for table in "${CORE_TABLES[@]}"; do
    TABLE_EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = '$table'
        );" | xargs)
    
    if [ "$TABLE_EXISTS" = "t" ]; then
        # Get row count
        ROW_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "SELECT COUNT(*) FROM $table;" | xargs)
        print_success "✅ $table: $ROW_COUNT rows"
    else
        print_error "❌ $table: TABLE MISSING"
    fi
done

# Check for recent data
print_status "Checking for recent data..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
    SELECT 
        'users' as table_name,
        COUNT(*) as total_rows,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as recent_rows
    FROM users
    UNION ALL
    SELECT 
        'properties' as table_name,
        COUNT(*) as total_rows,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as recent_rows
    FROM properties
    UNION ALL
    SELECT 
        'transfers' as table_name,
        COUNT(*) as total_rows,
        COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as recent_rows
    FROM transfers;" 2>/dev/null || print_warning "Some tables may not have created_at columns"

# Check database version and settings
print_status "Database information:"
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
    SELECT 
        version() as postgres_version,
        current_database() as database_name,
        current_user as current_user,
        inet_server_addr() as server_ip,
        inet_server_port() as server_port;"

# Check for specific HandReceipt columns/constraints
print_status "Checking table schemas for key constraints..."
PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
    SELECT 
        table_name,
        column_name,
        data_type,
        is_nullable,
        column_default
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name IN ('users', 'properties', 'transfers')
    ORDER BY table_name, ordinal_position;" 2>/dev/null || true

print_success "Migration status check complete!"
print_status "Next steps if issues found:"
echo "1. If tables are missing: Re-run migrations"
echo "2. If data is missing: Check migration logs and re-import data"
echo "3. If recent activity is low: Verify application is connecting properly" 