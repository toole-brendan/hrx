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

-- 10. Add foreign key constraints for referential integrity
-- Ensure property_model_id references are correct
DO $$
BEGIN
    -- Only add constraint if property_models table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'property_models') THEN
        -- Check if the constraint doesn't already exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                      WHERE constraint_name = 'fk_properties_property_model' 
                      AND table_name = 'properties') THEN
            ALTER TABLE properties 
            ADD CONSTRAINT fk_properties_property_model 
            FOREIGN KEY (property_model_id) REFERENCES property_models(id);
        END IF;
    END IF;
END $$;

-- 11. Create or replace updated_at trigger function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 12. Apply updated_at triggers to new tables
CREATE TRIGGER IF NOT EXISTS update_attachments_updated_at 
BEFORE UPDATE ON attachments 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 13. Create function to automatically deactivate old QR codes
CREATE OR REPLACE FUNCTION deactivate_old_qr_codes()
RETURNS TRIGGER AS $$
BEGIN
    -- Deactivate all other active QR codes for this property
    UPDATE qr_codes 
    SET is_active = FALSE, 
        deactivated_at = CURRENT_TIMESTAMP
    WHERE property_id = NEW.property_id 
        AND id != NEW.id 
        AND is_active = TRUE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14. Create trigger to deactivate old QR codes
DROP TRIGGER IF EXISTS trigger_deactivate_old_qr_codes ON qr_codes;
CREATE TRIGGER trigger_deactivate_old_qr_codes
    AFTER INSERT ON qr_codes
    FOR EACH ROW
    WHEN (NEW.is_active = TRUE)
    EXECUTE FUNCTION deactivate_old_qr_codes();

-- 15. Add comments for documentation
COMMENT ON TABLE qr_codes IS 'QR codes generated for property transfer workflow';
COMMENT ON TABLE attachments IS 'Photo and document attachments for properties';
COMMENT ON TABLE transfer_items IS 'Individual items in bulk transfer requests';
COMMENT ON TABLE offline_sync_queue IS 'Queue for syncing offline iOS app changes';
COMMENT ON TABLE immudb_references IS 'References to immutable audit entries';

COMMENT ON COLUMN properties.condition IS 'Physical condition of the property';
COMMENT ON COLUMN properties.condition_notes IS 'Additional notes about property condition';
COMMENT ON COLUMN properties.photo_url IS 'URL to property photo in MinIO storage';
COMMENT ON COLUMN properties.sync_status IS 'Offline sync status for mobile app';
COMMENT ON COLUMN properties.client_id IS 'Client identifier for offline sync';
COMMENT ON COLUMN properties.version IS 'Version number for conflict resolution';

COMMENT ON COLUMN users.dodid IS 'Department of Defense ID number';
COMMENT ON COLUMN users.phone IS 'Contact phone number';

-- 16. Create a view for active properties with related data
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
    pm.model_name,
    pm.manufacturer,
    pt.name as property_type_name,
    p.created_at,
    p.updated_at
FROM properties p
LEFT JOIN users u ON p.assigned_to_user_id = u.id
LEFT JOIN property_models pm ON p.property_model_id = pm.id
LEFT JOIN property_types pt ON pm.property_type_id = pt.id
WHERE p.current_status != 'retired' 
AND p.current_status != 'disposed';

COMMENT ON VIEW active_properties_view IS 'Consolidated view of active properties with user and model information';

-- 17. Insert sample property models if property_models table exists and is empty
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'property_models') THEN
        -- Check if table is empty
        IF NOT EXISTS (SELECT 1 FROM property_models LIMIT 1) AND 
           EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'property_types') THEN
            
            -- Insert sample property types first
            INSERT INTO property_types (name, description) VALUES 
            ('Weapons', 'Military weapons and firearms'),
            ('Communications', 'Communication equipment and radios'),
            ('Vehicles', 'Military vehicles and transportation'),
            ('Medical', 'Medical equipment and supplies'),
            ('Electronics', 'Electronic equipment and computers')
            ON CONFLICT (name) DO NOTHING;
            
            -- Insert sample property models
            INSERT INTO property_models (property_type_id, model_name, manufacturer, nsn, description) 
            SELECT 
                pt.id,
                models.model_name,
                models.manufacturer,
                models.nsn,
                models.description
            FROM property_types pt
            CROSS JOIN (VALUES
                ('M4 Carbine', 'Colt Defense LLC', '1005-01-123-4567', '5.56mm carbine rifle'),
                ('M16A4 Rifle', 'FN Manufacturing', '1005-01-234-5678', '5.56mm assault rifle'),
                ('AN/PRC-152 Radio', 'Harris Corporation', '5820-01-345-6789', 'Handheld tactical radio'),
                ('HMMWV M1114', 'AM General', '2320-01-456-7890', 'Up-armored utility vehicle'),
                ('Toughbook CF-31', 'Panasonic', '7021-01-567-8901', 'Rugged laptop computer')
            ) AS models(model_name, manufacturer, nsn, description)
            WHERE (pt.name = 'Weapons' AND models.model_name LIKE '%M4%' OR models.model_name LIKE '%M16%')
               OR (pt.name = 'Communications' AND models.model_name LIKE '%Radio%')
               OR (pt.name = 'Vehicles' AND models.model_name LIKE '%HMMWV%')
               OR (pt.name = 'Electronics' AND models.model_name LIKE '%Toughbook%')
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;
END $$;

-- 18. Migration completion log
INSERT INTO catalog_updates (update_source, update_date, notes) VALUES 
('SCHEMA_MIGRATION_005', CURRENT_TIMESTAMP, 'Schema reconciliation and feature enhancement migration completed')
ON CONFLICT DO NOTHING; 