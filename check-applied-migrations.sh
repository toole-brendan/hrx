#!/bin/bash

# Check and apply missing migrations to HandReceipt Azure database

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

print_status "Checking applied migrations in HandReceipt Azure database..."

# Check if Azure CLI is logged in
if ! az account show >/dev/null 2>&1; then
    print_error "Please log in to Azure CLI first: az login"
    exit 1
fi

# Set subscription
az account set --subscription "98b9185a-60b8-4df4-b8a4-73e6d35b176f"

# Get PostgreSQL connection info
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

# Check if migrations tracking table exists
print_status "Checking for schema migrations tracking..."
MIGRATIONS_TABLE_EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'schema_migrations'
    );" | xargs)

if [ "$MIGRATIONS_TABLE_EXISTS" = "f" ]; then
    print_warning "No schema_migrations table found. Creating it..."
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version VARCHAR(255) PRIMARY KEY,
            applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
    "
    print_success "Schema migrations table created."
fi

# List all migration files available
print_status "Available migration files:"
MIGRATION_FILES=($(ls sql/migrations/*.sql | sort))
for file in "${MIGRATION_FILES[@]}"; do
    filename=$(basename "$file")
    print_status "  $filename"
done

echo

# Check which migrations have been applied
print_status "Applied migrations in database:"
APPLIED_MIGRATIONS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
    SELECT version FROM schema_migrations ORDER BY version;
" | xargs || echo "")

if [ -n "$APPLIED_MIGRATIONS" ]; then
    for migration in $APPLIED_MIGRATIONS; do
        print_success "  ✅ $migration"
    done
else
    print_warning "  No migrations recorded in schema_migrations table"
fi

echo

# Apply missing migrations
print_status "Checking for missing migrations..."

apply_migration() {
    local migration_file=$1
    local migration_name=$(basename "$migration_file" .sql)
    
    # Check if already applied
    MIGRATION_APPLIED=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
        SELECT EXISTS (
            SELECT 1 FROM schema_migrations 
            WHERE version = '$migration_name'
        );" | xargs)
    
    if [ "$MIGRATION_APPLIED" = "t" ]; then
        print_success "✅ $migration_name already applied"
        return 0
    fi
    
    print_warning "⚠️  $migration_name NOT applied - applying now..."
    
    # Apply the migration
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -f "$migration_file"; then
        # Record in schema_migrations
        PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -c "
            INSERT INTO schema_migrations (version) VALUES ('$migration_name') ON CONFLICT DO NOTHING;
        "
        print_success "✅ $migration_name applied successfully"
        return 0
    else
        print_error "❌ Failed to apply $migration_name"
        return 1
    fi
}

# Apply migrations in order
MIGRATION_ORDER=(
    "sql/migrations/001_initial_schema.up.sql"
    "sql/migrations/003_nsn_catalog.sql"
    "sql/migrations/004_update_users_table.sql"
    "sql/migrations/005_schema_reconciliation.sql"
    "sql/migrations/006_transfer_system_refactor_phase1.sql"
    "sql/migrations/007_transfer_offers_system.sql"
    "sql/migrations/008_complete_schema_alignment.sql"
    "sql/migrations/009_component_associations.sql"
    "sql/migrations/011_component_events_ledger.sql"
    "sql/migrations/012_add_include_components_to_transfers.sql"
    "sql/migrations/013_add_documents_table.sql"
    "sql/migrations/014_add_signature_and_source_document_fields.sql"
)

FAILED_MIGRATIONS=()

for migration_file in "${MIGRATION_ORDER[@]}"; do
    if [ -f "$migration_file" ]; then
        if ! apply_migration "$migration_file"; then
            FAILED_MIGRATIONS+=("$migration_file")
        fi
    else
        print_warning "Migration file not found: $migration_file"
    fi
done

echo

# Show final status
if [ ${#FAILED_MIGRATIONS[@]} -eq 0 ]; then
    print_success "🎉 All migrations applied successfully!"
    
    # Show final table count
    TABLE_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    " | xargs)
    print_status "Total tables in database: $TABLE_COUNT"
    
    # Check specifically for transfer offer tables
    print_status "Verifying transfer offer tables..."
    TRANSFER_OFFERS_EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'transfer_offers'
        );" | xargs)
    
    TRANSFER_RECIPIENTS_EXISTS=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_FQDN" -U "$POSTGRES_USER" -d "$DATABASE_NAME" -t -c "
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'transfer_offer_recipients'
        );" | xargs)
    
    if [ "$TRANSFER_OFFERS_EXISTS" = "t" ] && [ "$TRANSFER_RECIPIENTS_EXISTS" = "t" ]; then
        print_success "✅ Transfer offer tables are now available"
    else
        print_error "❌ Transfer offer tables still missing"
    fi
    
else
    print_error "❌ Some migrations failed:"
    for failed in "${FAILED_MIGRATIONS[@]}"; do
        print_error "  - $failed"
    done
fi

print_status "Migration check complete!" 