#!/bin/bash

# Fix HandReceipt Database Schema on AWS Lightsail
# This script will apply the schema reconciliation migration

echo "HandReceipt Database Schema Fix Script"
echo "====================================="

# Configuration
LIGHTSAIL_IP="44.193.254.155"
SSH_USER="ubuntu"
DB_NAME="handreceipt"
DB_USER="handreceipt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Connecting to Lightsail instance...${NC}"
echo "Please ensure you have your SSH key configured for this instance."
echo ""

# Create the migration file locally first
cat > 005_schema_reconciliation.sql << 'EOF'
-- Migration 005: Schema Reconciliation and Feature Enhancement
-- Addresses critical schema inconsistencies and adds missing functionality

-- First, fix the QR codes table to reference properties instead of inventory_items
-- Drop and recreate if the column type/reference is wrong
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
ADD COLUMN IF NOT EXISTS photo_url TEXT, -- MinIO object URL
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
    file_url TEXT NOT NULL, -- MinIO URL
    file_size BIGINT,
    mime_type VARCHAR(100),
    uploaded_by_user_id BIGINT NOT NULL REFERENCES users(id),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Update users table with missing military fields
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
ADD COLUMN IF NOT EXISTS dodid VARCHAR(10) UNIQUE;

-- Note: rank and unit already exist in the Go model, but ensure they exist
ALTER TABLE users 
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
    operation_type VARCHAR(20) NOT NULL, -- 'create', 'update', 'delete'
    entity_type VARCHAR(50) NOT NULL, -- 'property', 'transfer', etc.
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

-- 8. Create necessary indexes for performance
CREATE INDEX IF NOT EXISTS idx_properties_condition ON properties(condition);
CREATE INDEX IF NOT EXISTS idx_properties_nsn ON properties(nsn);
CREATE INDEX IF NOT EXISTS idx_properties_lin ON properties(lin);
CREATE INDEX IF NOT EXISTS idx_properties_sync_status ON properties(sync_status);
CREATE INDEX IF NOT EXISTS idx_properties_location ON properties(location);

CREATE INDEX IF NOT EXISTS idx_qr_codes_property_active ON qr_codes(property_id, is_active);
CREATE INDEX IF NOT EXISTS idx_qr_codes_hash ON qr_codes(qr_code_hash);
CREATE INDEX IF NOT EXISTS idx_qr_codes_generated_by ON qr_codes(generated_by_user_id);

CREATE INDEX IF NOT EXISTS idx_attachments_property ON attachments(property_id);
CREATE INDEX IF NOT EXISTS idx_attachments_uploaded_by ON attachments(uploaded_by_user_id);

CREATE INDEX IF NOT EXISTS idx_transfer_items_transfer ON transfer_items(transfer_id);
CREATE INDEX IF NOT EXISTS idx_transfer_items_property ON transfer_items(property_id);

CREATE INDEX IF NOT EXISTS idx_offline_sync_client ON offline_sync_queue(client_id, sync_status);
CREATE INDEX IF NOT EXISTS idx_offline_sync_entity ON offline_sync_queue(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_immudb_references_entity ON immudb_references(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_users_dodid ON users(dodid);
CREATE INDEX IF NOT EXISTS idx_users_rank ON users(rank);
CREATE INDEX IF NOT EXISTS idx_users_unit ON users(unit);

-- 9. Add check constraints for data validation
ALTER TABLE properties 
ADD CONSTRAINT IF NOT EXISTS chk_condition 
CHECK (condition IN ('serviceable', 'unserviceable', 'needs_repair', 'beyond_repair', 'new'));

ALTER TABLE properties 
ADD CONSTRAINT IF NOT EXISTS chk_sync_status 
CHECK (sync_status IN ('synced', 'pending', 'conflict', 'failed'));

ALTER TABLE transfers 
ADD CONSTRAINT IF NOT EXISTS chk_status 
CHECK (status IN ('pending', 'accepted', 'rejected', 'cancelled', 'completed'));

ALTER TABLE offline_sync_queue 
ADD CONSTRAINT IF NOT EXISTS chk_operation_type 
CHECK (operation_type IN ('create', 'update', 'delete'));

ALTER TABLE offline_sync_queue 
ADD CONSTRAINT IF NOT EXISTS chk_sync_status 
CHECK (sync_status IN ('pending', 'synced', 'failed'));

-- Create necessary functions and triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

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

-- Add comments for documentation
COMMENT ON TABLE qr_codes IS 'QR codes generated for property transfer workflow';
COMMENT ON TABLE attachments IS 'Photo and document attachments for properties';
COMMENT ON TABLE transfer_items IS 'Individual items in bulk transfer requests';
COMMENT ON TABLE offline_sync_queue IS 'Queue for syncing offline iOS app changes';
COMMENT ON TABLE immudb_references IS 'References to immutable audit entries';

-- Create view for active properties
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

-- Migration complete
EOF

echo -e "${GREEN}Migration file created successfully!${NC}"
echo ""

# Instructions for manual application
echo -e "${YELLOW}Step 2: SSH into your Lightsail instance${NC}"
echo "Run the following command:"
echo -e "${GREEN}ssh -i /path/to/your-key.pem ${SSH_USER}@${LIGHTSAIL_IP}${NC}"
echo ""

echo -e "${YELLOW}Step 3: Once connected, check your database connection${NC}"
echo "First, let's check if PostgreSQL is running in Docker:"
echo -e "${GREEN}sudo docker ps | grep postgres${NC}"
echo ""

echo -e "${YELLOW}Step 4: Create a backup of your database${NC}"
echo "Run these commands on the server:"
cat << 'BACKUP_SCRIPT'
# Create backup directory
sudo mkdir -p /home/ubuntu/db_backups

# Create database backup
sudo docker exec $(sudo docker ps -q -f name=postgres) pg_dump -U handreceipt handreceipt > /home/ubuntu/db_backups/handreceipt_backup_$(date +%Y%m%d_%H%M%S).sql

# Verify backup was created
ls -la /home/ubuntu/db_backups/
BACKUP_SCRIPT

echo ""
echo -e "${YELLOW}Step 5: Copy and apply the migration${NC}"
echo "1. Copy the migration file to the server:"
echo -e "${GREEN}scp -i /path/to/your-key.pem 005_schema_reconciliation.sql ${SSH_USER}@${LIGHTSAIL_IP}:/home/ubuntu/${NC}"
echo ""

echo "2. Apply the migration:"
cat << 'APPLY_SCRIPT'
# Connect to PostgreSQL and apply migration
sudo docker exec -i $(sudo docker ps -q -f name=postgres) psql -U handreceipt handreceipt < /home/ubuntu/005_schema_reconciliation.sql

# Or connect interactively first to check current schema:
sudo docker exec -it $(sudo docker ps -q -f name=postgres) psql -U handreceipt handreceipt

# Inside psql, you can check current tables:
\dt
\d properties
\d users
\d transfers

# Then apply the migration:
\i /home/ubuntu/005_schema_reconciliation.sql
APPLY_SCRIPT

echo ""
echo -e "${YELLOW}Step 6: Verify the changes${NC}"
echo "Check that the new columns and tables were created:"
cat << 'VERIFY_SCRIPT'
# Connect to database
sudo docker exec -it $(sudo docker ps -q -f name=postgres) psql -U handreceipt handreceipt

# Run these commands in psql:
-- Check properties table columns
\d properties

-- Check new tables
\dt

-- Verify QR codes table
\d qr_codes

-- Verify attachments table  
\d attachments

-- Check the view
\d active_properties_view

-- Exit psql
\q
VERIFY_SCRIPT

echo ""
echo -e "${YELLOW}Step 7: Restart your application${NC}"
echo "After applying the migration, restart your backend services:"
cat << 'RESTART_SCRIPT'
# Check running containers
sudo docker ps

# Restart the backend API
sudo docker restart handreceipt-api

# Check logs to ensure it started correctly
sudo docker logs --tail 50 -f handreceipt-api
RESTART_SCRIPT

echo ""
echo -e "${GREEN}Migration script ready!${NC}"
echo -e "${YELLOW}Remember to:${NC}"
echo "1. Always backup your database before making schema changes"
echo "2. Test the migration in a staging environment first if possible"
echo "3. Monitor your application logs after applying the migration"
echo "4. Have a rollback plan ready" 