#!/bin/bash

# HandReceipt Database Migration Script - Customized for your setup
# Run this locally to apply migration to your Lightsail instance

echo "HandReceipt Database Schema Migration"
echo "===================================="
echo ""

# Your specific configuration
LIGHTSAIL_IP="44.193.254.155"
SSH_KEY="~/.ssh/handreceipt-new"
SSH_USER="ubuntu"
CONTAINER_NAME="backend_postgres_1"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Creating migration file locally${NC}"

# Create the migration file
cat > 005_schema_reconciliation.sql << 'EOF'
-- Migration 005: Schema Reconciliation and Feature Enhancement
-- Addresses critical schema inconsistencies and adds missing functionality

-- First, fix the QR codes table to reference properties instead of inventory_items
DO $$
BEGIN
    -- Check if qr_codes table exists and has wrong reference
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'qr_codes') THEN
        -- Drop the existing table if it references inventory_items
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'qr_codes' AND column_name = 'inventory_item_id') THEN
            DROP TABLE IF EXISTS qr_codes CASCADE;
        END IF;
    END IF;
END $$;

-- 1. Add missing columns to properties table for enhanced functionality
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

-- 2. Create QR codes table with correct property reference
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

-- 3. Add attachments table for photos and documents
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

-- 4. Update users table with missing military fields
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS dodid VARCHAR(10) UNIQUE,
ADD COLUMN IF NOT EXISTS rank VARCHAR(50),
ADD COLUMN IF NOT EXISTS unit VARCHAR(100);

-- 5. Add transfer_items for bulk transfers
CREATE TABLE IF NOT EXISTS transfer_items (
    id BIGSERIAL PRIMARY KEY,
    transfer_id BIGINT NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
    property_id BIGINT NOT NULL REFERENCES properties(id),
    quantity INTEGER DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. Add offline_sync_queue for iOS offline support
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

-- 7. Add immudb_references for audit trail integration
CREATE TABLE IF NOT EXISTS immudb_references (
    id BIGSERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id BIGINT NOT NULL,
    immudb_key VARCHAR(255) NOT NULL,
    immudb_index BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. Create necessary indexes
CREATE INDEX IF NOT EXISTS idx_properties_condition ON properties(condition);
CREATE INDEX IF NOT EXISTS idx_properties_nsn ON properties(nsn);
CREATE INDEX IF NOT EXISTS idx_properties_lin ON properties(lin);
CREATE INDEX IF NOT EXISTS idx_properties_sync_status ON properties(sync_status);
CREATE INDEX IF NOT EXISTS idx_properties_location ON properties(location);

CREATE INDEX IF NOT EXISTS idx_qr_codes_property_active ON qr_codes(property_id, is_active);
CREATE INDEX IF NOT EXISTS idx_qr_codes_hash ON qr_codes(qr_code_hash);

CREATE INDEX IF NOT EXISTS idx_attachments_property ON attachments(property_id);

CREATE INDEX IF NOT EXISTS idx_transfer_items_transfer ON transfer_items(transfer_id);
CREATE INDEX IF NOT EXISTS idx_transfer_items_property ON transfer_items(property_id);

CREATE INDEX IF NOT EXISTS idx_offline_sync_client ON offline_sync_queue(client_id, sync_status);

CREATE INDEX IF NOT EXISTS idx_users_dodid ON users(dodid);

-- 9. Add check constraints
ALTER TABLE properties 
ADD CONSTRAINT IF NOT EXISTS chk_condition 
CHECK (condition IN ('serviceable', 'unserviceable', 'needs_repair', 'beyond_repair', 'new'));

ALTER TABLE properties 
ADD CONSTRAINT IF NOT EXISTS chk_sync_status 
CHECK (sync_status IN ('synced', 'pending', 'conflict', 'failed'));

ALTER TABLE transfers 
ADD CONSTRAINT IF NOT EXISTS chk_status 
CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'completed'));

-- 10. Create triggers
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

-- 11. Create view for active properties
CREATE OR REPLACE VIEW active_properties_view AS
SELECT 
    p.id,
    p.name,
    p.serial_number,
    p.description,
    p.current_status,
    p.condition,
    p.condition_notes,
    p.nsn,
    p.lin,
    p.location,
    p.photo_url,
    p.assigned_to_user_id,
    u.name as assigned_user_name,
    u.rank as assigned_user_rank,
    u.unit as assigned_user_unit,
    p.created_at,
    p.updated_at
FROM properties p
LEFT JOIN users u ON p.assigned_to_user_id = u.id
WHERE p.current_status != 'retired' 
AND p.current_status != 'disposed';

-- Add comments
COMMENT ON TABLE qr_codes IS 'QR codes generated for property transfer workflow';
COMMENT ON TABLE attachments IS 'Photo and document attachments for properties';
COMMENT ON COLUMN properties.condition IS 'Physical condition of the property';
COMMENT ON COLUMN properties.photo_url IS 'URL to property photo in MinIO storage';
COMMENT ON COLUMN users.dodid IS 'Department of Defense ID number';
EOF

echo -e "${GREEN}✓ Migration file created${NC}"
echo ""

# Step 2: Copy the migration file to Lightsail
echo -e "${YELLOW}Step 2: Copying migration file to Lightsail instance${NC}"
if scp -i ${SSH_KEY} 005_schema_reconciliation.sql ${SSH_USER}@${LIGHTSAIL_IP}:/home/ubuntu/; then
    echo -e "${GREEN}✓ File copied successfully${NC}"
else
    echo -e "${RED}✗ Failed to copy file${NC}"
    exit 1
fi

# Step 3: SSH and execute migration
echo ""
echo -e "${YELLOW}Step 3: Connecting to Lightsail and applying migration${NC}"
echo ""

ssh -i ${SSH_KEY} ${SSH_USER}@${LIGHTSAIL_IP} << 'REMOTE_SCRIPT'
echo "Connected to Lightsail instance"
echo ""

# Check if postgres container is running
echo "Checking PostgreSQL container..."
if sudo docker ps | grep -q backend_postgres_1; then
    echo "✓ PostgreSQL container is running"
else
    echo "✗ PostgreSQL container not found!"
    echo "Available containers:"
    sudo docker ps
    exit 1
fi

# Create backup
echo ""
echo "Creating database backup..."
BACKUP_DIR="/home/ubuntu/db_backups"
sudo mkdir -p ${BACKUP_DIR}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/handreceipt_backup_${TIMESTAMP}.sql"

if sudo docker exec backend_postgres_1 pg_dump -U handreceipt -d handreceipt > ${BACKUP_FILE}; then
    echo "✓ Backup created: ${BACKUP_FILE}"
    echo "  Size: $(ls -lh ${BACKUP_FILE} | awk '{print $5}')"
else
    echo "✗ Backup failed!"
    exit 1
fi

# Check current schema
echo ""
echo "Checking current schema..."
echo "Properties table columns:"
sudo docker exec -it backend_postgres_1 psql -U handreceipt -d handreceipt -c "\d properties" | grep -E "condition|nsn|lin|photo_url|sync_status" || echo "New columns not found (will be added)"

# Check for incorrect qr_codes table
if sudo docker exec backend_postgres_1 psql -U handreceipt -d handreceipt -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'qr_codes' AND column_name = 'inventory_item_id');" | grep -q 't'; then
    echo "⚠  Found qr_codes table with inventory_item_id (will be fixed)"
fi

# Apply migration
echo ""
echo "Applying migration..."
if sudo docker exec -i backend_postgres_1 psql -U handreceipt -d handreceipt < /home/ubuntu/005_schema_reconciliation.sql; then
    echo "✓ Migration applied successfully!"
else
    echo "✗ Migration failed!"
    echo "Check errors above. To restore from backup:"
    echo "sudo docker exec -i backend_postgres_1 psql -U handreceipt -d handreceipt < ${BACKUP_FILE}"
    exit 1
fi

# Verify migration
echo ""
echo "Verifying migration results..."

# Check new columns in properties table
echo "1. Checking properties table new columns:"
sudo docker exec -it backend_postgres_1 psql -U handreceipt -d handreceipt -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'properties' AND column_name IN ('condition', 'nsn', 'lin', 'photo_url', 'sync_status', 'quantity', 'unit_price') ORDER BY column_name;"

# Check new tables
echo ""
echo "2. Checking new tables:"
for table in qr_codes attachments transfer_items offline_sync_queue immudb_references; do
    if sudo docker exec backend_postgres_1 psql -U handreceipt -d handreceipt -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '$table');" | grep -q 't'; then
        echo "✓ Table $table exists"
    else
        echo "✗ Table $table missing"
    fi
done

# Check michael.rodriguez still has his properties
echo ""
echo "3. Verifying existing data (michael.rodriguez):"
sudo docker exec -it backend_postgres_1 psql -U handreceipt -d handreceipt -c "SELECT username, name, rank FROM users WHERE username = 'michael.rodriguez';"
sudo docker exec -it backend_postgres_1 psql -U handreceipt -d handreceipt -c "SELECT COUNT(*) as property_count FROM properties WHERE assigned_to_user_id = (SELECT id FROM users WHERE username = 'michael.rodriguez');"

# Count total tables
echo ""
echo "4. Database summary:"
TABLE_COUNT=$(sudo docker exec backend_postgres_1 psql -U handreceipt -d handreceipt -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")
echo "Total tables: $TABLE_COUNT"

echo ""
echo "✓ Migration verification complete!"
REMOTE_SCRIPT

# Step 4: Clean up local file
echo ""
echo -e "${YELLOW}Step 4: Cleaning up${NC}"
rm -f 005_schema_reconciliation.sql
echo -e "${GREEN}✓ Local migration file removed${NC}"

# Step 5: Next steps
echo ""
echo -e "${GREEN}Migration completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. SSH into your instance:"
echo -e "   ${GREEN}ssh -i ${SSH_KEY} ${SSH_USER}@${LIGHTSAIL_IP}${NC}"
echo ""
echo "2. Restart the backend API:"
echo -e "   ${GREEN}sudo docker restart handreceipt-api${NC}"
echo ""
echo "3. Check the logs:"
echo -e "   ${GREEN}sudo docker logs --tail 50 -f handreceipt-api${NC}"
echo ""
echo "4. Test your application to ensure everything works correctly" 