#!/bin/bash

# HandReceipt Database Migration Script
# Run this directly on your Lightsail instance

set -e  # Exit on error

echo "HandReceipt Database Migration - Schema Reconciliation"
echo "====================================================="
echo ""

# Check if running as ubuntu user or with sudo
if [[ $EUID -eq 0 ]]; then
   echo "Running as root/sudo"
else
   echo "Running as user: $USER"
fi

# Function to check if PostgreSQL container is running
check_postgres() {
    if sudo docker ps | grep -q postgres; then
        echo "✓ PostgreSQL container is running"
        POSTGRES_CONTAINER=$(sudo docker ps -q -f name=postgres)
        echo "  Container ID: $POSTGRES_CONTAINER"
        return 0
    else
        echo "✗ PostgreSQL container is not running!"
        echo "  Checking all containers..."
        sudo docker ps -a | grep postgres || echo "No PostgreSQL container found"
        return 1
    fi
}

# Function to backup database
backup_database() {
    echo ""
    echo "Creating database backup..."
    
    BACKUP_DIR="/home/ubuntu/db_backups"
    sudo mkdir -p $BACKUP_DIR
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/handreceipt_backup_$TIMESTAMP.sql"
    
    if sudo docker exec $POSTGRES_CONTAINER pg_dump -U handreceipt handreceipt > $BACKUP_FILE 2>/dev/null; then
        echo "✓ Backup created successfully: $BACKUP_FILE"
        echo "  Size: $(ls -lh $BACKUP_FILE | awk '{print $5}')"
        return 0
    else
        echo "✗ Backup failed!"
        return 1
    fi
}

# Function to check current schema
check_current_schema() {
    echo ""
    echo "Checking current database schema..."
    
    # Check if properties table exists
    if sudo docker exec $POSTGRES_CONTAINER psql -U handreceipt -d handreceipt -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'properties');" | grep -q 't'; then
        echo "✓ Properties table exists"
        
        # Check for the new columns we're adding
        echo "  Checking for new columns..."
        for column in condition nsn lin photo_url sync_status; do
            if sudo docker exec $POSTGRES_CONTAINER psql -U handreceipt -d handreceipt -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'properties' AND column_name = '$column');" | grep -q 't'; then
                echo "    - $column: already exists"
            else
                echo "    - $column: will be added"
            fi
        done
    else
        echo "✗ Properties table does not exist!"
        return 1
    fi
    
    # Check for qr_codes table with wrong reference
    if sudo docker exec $POSTGRES_CONTAINER psql -U handreceipt -d handreceipt -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'qr_codes' AND column_name = 'inventory_item_id');" | grep -q 't'; then
        echo "⚠  QR codes table has incorrect reference to inventory_item_id - will be fixed"
    fi
}

# Function to apply migration
apply_migration() {
    echo ""
    echo "Applying migration..."
    
    # Create migration file
    cat > /tmp/005_schema_reconciliation.sql << 'EOF'
-- Migration 005: Schema Reconciliation and Feature Enhancement

-- First, fix the QR codes table to reference properties instead of inventory_items
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'qr_codes') THEN
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'qr_codes' AND column_name = 'inventory_item_id') THEN
            DROP TABLE IF EXISTS qr_codes CASCADE;
        END IF;
    END IF;
END $$;

-- Add missing columns to properties table
ALTER TABLE properties 
ADD COLUMN IF NOT EXISTS condition VARCHAR(50) DEFAULT 'serviceable',
ADD COLUMN IF NOT EXISTS condition_notes TEXT,
ADD COLUMN IF NOT EXISTS nsn VARCHAR(13),
ADD COLUMN IF NOT EXISTS lin VARCHAR(6),
ADD COLUMN IF NOT EXISTS location VARCHAR(255),
ADD COLUMN IF NOT EXISTS acquisition_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS unit_price DECIMAL(12,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS photo_url TEXT,
ADD COLUMN IF NOT EXISTS sync_status VARCHAR(20) DEFAULT 'synced',
ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS client_id VARCHAR(100),
ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;

-- Create QR codes table with correct reference
CREATE TABLE IF NOT EXISTS qr_codes (
    id BIGSERIAL PRIMARY KEY,
    property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    qr_code_data TEXT NOT NULL,
    qr_code_hash VARCHAR(64) UNIQUE NOT NULL,
    generated_by_user_id BIGINT NOT NULL REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deactivated_at TIMESTAMP WITH TIME ZONE
);

-- Add other new tables
CREATE TABLE IF NOT EXISTS attachments (
    id BIGSERIAL PRIMARY KEY,
    property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(100),
    uploaded_by_user_id BIGINT NOT NULL REFERENCES users(id),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS dodid VARCHAR(10) UNIQUE,
ADD COLUMN IF NOT EXISTS rank VARCHAR(50),
ADD COLUMN IF NOT EXISTS unit VARCHAR(100);

CREATE TABLE IF NOT EXISTS transfer_items (
    id BIGSERIAL PRIMARY KEY,
    transfer_id BIGINT NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
    property_id BIGINT NOT NULL REFERENCES properties(id),
    quantity INTEGER DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS offline_sync_queue (
    id BIGSERIAL PRIMARY KEY,
    client_id VARCHAR(100) NOT NULL,
    operation_type VARCHAR(20) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id BIGINT,
    payload JSONB NOT NULL,
    sync_status VARCHAR(20) DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS immudb_references (
    id BIGSERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id BIGINT NOT NULL,
    immudb_key VARCHAR(255) NOT NULL,
    immudb_index BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_properties_condition ON properties(condition);
CREATE INDEX IF NOT EXISTS idx_properties_nsn ON properties(nsn);
CREATE INDEX IF NOT EXISTS idx_properties_lin ON properties(lin);
CREATE INDEX IF NOT EXISTS idx_properties_sync_status ON properties(sync_status);
CREATE INDEX IF NOT EXISTS idx_qr_codes_property_active ON qr_codes(property_id, is_active);
CREATE INDEX IF NOT EXISTS idx_qr_codes_hash ON qr_codes(qr_code_hash);

-- Add constraints
ALTER TABLE properties 
ADD CONSTRAINT IF NOT EXISTS chk_condition 
CHECK (condition IN ('serviceable', 'unserviceable', 'needs_repair', 'beyond_repair', 'new'));

-- Create triggers
CREATE OR REPLACE FUNCTION deactivate_old_qr_codes()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE qr_codes 
    SET is_active = FALSE, 
        deactivated_at = CURRENT_TIMESTAMP
    WHERE property_id = NEW.property_id 
        AND id != NEW.id 
        AND is_active = TRUE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_deactivate_old_qr_codes ON qr_codes;
CREATE TRIGGER trigger_deactivate_old_qr_codes
    AFTER INSERT ON qr_codes
    FOR EACH ROW
    WHEN (NEW.is_active = TRUE)
    EXECUTE FUNCTION deactivate_old_qr_codes();
EOF

    # Apply the migration
    if sudo docker exec -i $POSTGRES_CONTAINER psql -U handreceipt handreceipt < /tmp/005_schema_reconciliation.sql; then
        echo "✓ Migration applied successfully!"
        rm /tmp/005_schema_reconciliation.sql
        return 0
    else
        echo "✗ Migration failed!"
        return 1
    fi
}

# Function to verify migration
verify_migration() {
    echo ""
    echo "Verifying migration..."
    
    # Check new tables
    for table in qr_codes attachments transfer_items offline_sync_queue immudb_references; do
        if sudo docker exec $POSTGRES_CONTAINER psql -U handreceipt -d handreceipt -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '$table');" | grep -q 't'; then
            echo "✓ Table $table created"
        else
            echo "✗ Table $table missing!"
        fi
    done
    
    # Count tables
    TABLE_COUNT=$(sudo docker exec $POSTGRES_CONTAINER psql -U handreceipt -d handreceipt -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")
    echo ""
    echo "Total tables in database: $TABLE_COUNT"
}

# Main execution
echo "Starting migration process..."
echo ""

# Step 1: Check PostgreSQL
if ! check_postgres; then
    echo "ERROR: PostgreSQL container not found or not running"
    exit 1
fi

# Step 2: Check current schema
check_current_schema

# Step 3: Ask for confirmation
echo ""
echo "Ready to apply migration. This will:"
echo "  - Add new columns to properties table"
echo "  - Create new tables for QR codes, attachments, etc."
echo "  - Add indexes and constraints"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [[ $confirm != "yes" ]]; then
    echo "Migration cancelled."
    exit 0
fi

# Step 4: Backup database
if ! backup_database; then
    echo "ERROR: Backup failed. Migration cancelled for safety."
    exit 1
fi

# Step 5: Apply migration
if apply_migration; then
    # Step 6: Verify migration
    verify_migration
    
    echo ""
    echo "✓ Migration completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart your application:"
    echo "   sudo docker restart handreceipt-api"
    echo ""
    echo "2. Check application logs:"
    echo "   sudo docker logs --tail 50 -f handreceipt-api"
    echo ""
    echo "3. Test your application to ensure everything works"
else
    echo ""
    echo "✗ Migration failed!"
    echo ""
    echo "To restore from backup:"
    echo "sudo docker exec -i $POSTGRES_CONTAINER psql -U handreceipt handreceipt < $(ls -t $BACKUP_DIR/handreceipt_backup_*.sql | head -1)"
fi 