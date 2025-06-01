-- Migration 008: Complete Schema Alignment and Feature Updates
-- This migration corrects discrepancies and adds missing features

-- 1. REMOVE DEPRECATED TABLES AND COLUMNS
-- Drop equipment table if it exists (replaced by properties)
DROP TABLE IF EXISTS equipment CASCADE;
DROP TABLE IF EXISTS hand_receipts CASCADE;
DROP TABLE IF EXISTS transfer_witnesses CASCADE;
DROP TABLE IF EXISTS maintenance_records CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS refresh_tokens CASCADE;

-- Drop old NSN tables to standardize on nsn_records
DROP TABLE IF EXISTS nsn_data CASCADE;
DROP TABLE IF EXISTS nsn_items CASCADE;
DROP TABLE IF EXISTS nsn_parts CASCADE;
DROP TABLE IF EXISTS lin_items CASCADE;
DROP TABLE IF EXISTS cage_codes CASCADE;
DROP TABLE IF EXISTS nsn_synonyms CASCADE;

-- 2. CREATE NSN_RECORDS TABLE (referenced in seed data)
CREATE TABLE IF NOT EXISTS nsn_records (
    id BIGSERIAL PRIMARY KEY,
    nsn VARCHAR(20) UNIQUE,
    lin VARCHAR(10),
    item_name TEXT NOT NULL,
    description TEXT,
    category VARCHAR(50),
    unit_of_issue VARCHAR(10),
    unit_price DECIMAL(12, 2),
    hazmat_code VARCHAR(10),
    demil_code VARCHAR(10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for nsn_records
CREATE INDEX IF NOT EXISTS idx_nsn_records_nsn ON nsn_records(nsn);
CREATE INDEX IF NOT EXISTS idx_nsn_records_lin ON nsn_records(lin);
CREATE INDEX IF NOT EXISTS idx_nsn_records_item_name_gin 
    ON nsn_records USING gin(to_tsvector('english', item_name));

-- 3. ADD MISSING ACTIVITIES TABLE (already exists in your schema)
-- Just add indexes if not present
CREATE INDEX IF NOT EXISTS idx_activities_user_id ON activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_property_id ON activities(related_property_id);
CREATE INDEX IF NOT EXISTS idx_activities_transfer_id ON activities(related_transfer_id);
CREATE INDEX IF NOT EXISTS idx_activities_timestamp ON activities(timestamp);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(type);

-- 4. REMOVE QR_CODES TABLE COMPLETELY (since you removed QR functionality)
DROP TABLE IF EXISTS qr_codes CASCADE;

-- 5. ADD MISSING CATALOG_UPDATES TABLE
CREATE TABLE IF NOT EXISTS catalog_updates (
    id BIGSERIAL PRIMARY KEY,
    update_source VARCHAR(50) NOT NULL, -- 'PUBLOG', 'MANUAL', 'DA2062_OCR', etc
    update_date TIMESTAMP WITH TIME ZONE NOT NULL,
    items_added INTEGER DEFAULT 0,
    items_updated INTEGER DEFAULT 0,
    items_removed INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. ADD DA2062 OCR PROCESSING TABLES
CREATE TABLE IF NOT EXISTS da2062_imports (
    id BIGSERIAL PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_url TEXT, -- MinIO URL
    imported_by_user_id BIGINT REFERENCES users(id) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' 
        CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    total_items INTEGER DEFAULT 0,
    processed_items INTEGER DEFAULT 0,
    failed_items INTEGER DEFAULT 0,
    error_log JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS da2062_import_items (
    id BIGSERIAL PRIMARY KEY,
    import_id BIGINT REFERENCES da2062_imports(id) ON DELETE CASCADE,
    line_number INTEGER NOT NULL,
    raw_data JSONB NOT NULL,
    property_id BIGINT REFERENCES properties(id),
    status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'processed', 'failed', 'duplicate')),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. ADD USER CONNECTIONS AND TRANSFER OFFERS (from migration 006 & 007)
-- These are missing from your current schema but needed for Venmo-style transfers

CREATE TABLE IF NOT EXISTS user_connections (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) NOT NULL,
    connected_user_id BIGINT REFERENCES users(id) NOT NULL,
    connection_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (connection_status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_connection UNIQUE(user_id, connected_user_id),
    CONSTRAINT no_self_connection CHECK (user_id != connected_user_id)
);

CREATE TABLE IF NOT EXISTS transfer_offers (
    id BIGSERIAL PRIMARY KEY,
    property_id BIGINT NOT NULL REFERENCES properties(id),
    offering_user_id BIGINT NOT NULL REFERENCES users(id),
    offer_status VARCHAR(20) DEFAULT 'active' 
        CHECK (offer_status IN ('active', 'accepted', 'expired', 'cancelled')),
    notes TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    accepted_by_user_id BIGINT REFERENCES users(id),
    accepted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS transfer_offer_recipients (
    id BIGSERIAL PRIMARY KEY,
    transfer_offer_id BIGINT NOT NULL REFERENCES transfer_offers(id) ON DELETE CASCADE,
    recipient_user_id BIGINT NOT NULL REFERENCES users(id),
    notified_at TIMESTAMP WITH TIME ZONE,
    viewed_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(transfer_offer_id, recipient_user_id)
);

-- 8. ENSURE TRANSFERS TABLE HAS ALL NECESSARY COLUMNS
ALTER TABLE transfers 
ADD COLUMN IF NOT EXISTS transfer_type VARCHAR(20) DEFAULT 'offer' 
    CHECK (transfer_type IN ('request', 'offer'));

ALTER TABLE transfers 
ADD COLUMN IF NOT EXISTS initiator_id BIGINT REFERENCES users(id);

ALTER TABLE transfers 
ADD COLUMN IF NOT EXISTS requested_serial_number TEXT;

-- 9. REMOVE PROPERTY_MODEL_ID FROM PROPERTIES
-- Since property_models table doesn't exist and isn't needed
ALTER TABLE properties DROP COLUMN IF EXISTS property_model_id;

-- 10. CREATE MISSING PROPERTY_TYPES AND PROPERTY_MODELS TABLES
-- These are referenced in views but don't exist - either create them or update views
DROP TABLE IF EXISTS property_models CASCADE;
DROP TABLE IF EXISTS property_types CASCADE;

-- 11. UPDATE ACTIVE_PROPERTIES_VIEW to remove missing references
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

-- 12. CREATE HELPER VIEWS FOR NEW FEATURES

-- View for DA2062 import status
CREATE OR REPLACE VIEW da2062_import_status_view AS
SELECT 
    d.id,
    d.file_name,
    d.status,
    d.total_items,
    d.processed_items,
    d.failed_items,
    u.name as imported_by,
    d.created_at,
    d.completed_at,
    CASE 
        WHEN d.total_items > 0 
        THEN ROUND((d.processed_items::numeric / d.total_items) * 100, 2)
        ELSE 0 
    END as completion_percentage
FROM da2062_imports d
JOIN users u ON d.imported_by_user_id = u.id;

-- View for user connections (friends network)
CREATE OR REPLACE VIEW user_friends_view AS
SELECT 
    uc.user_id,
    uc.connected_user_id as friend_id,
    u.name as friend_name,
    u.rank as friend_rank,
    u.unit as friend_unit,
    u.phone as friend_phone,
    uc.connection_status,
    uc.created_at as connection_date
FROM user_connections uc
JOIN users u ON uc.connected_user_id = u.id
WHERE uc.connection_status = 'accepted';

-- View for pending transfer requests by serial number
CREATE OR REPLACE VIEW pending_serial_requests_view AS
SELECT 
    t.id as transfer_id,
    t.requested_serial_number,
    t.initiator_id as requester_id,
    u1.name as requester_name,
    p.id as property_id,
    p.name as property_name,
    p.assigned_to_user_id as current_owner_id,
    u2.name as current_owner_name,
    t.status,
    t.notes,
    t.created_at
FROM transfers t
JOIN users u1 ON t.initiator_id = u1.id
LEFT JOIN properties p ON p.serial_number = t.requested_serial_number
LEFT JOIN users u2 ON p.assigned_to_user_id = u2.id
WHERE t.transfer_type = 'request' 
  AND t.status = 'pending'
  AND t.requested_serial_number IS NOT NULL;

-- 13. ADD ALL MISSING INDEXES
CREATE INDEX IF NOT EXISTS idx_user_connections_user_id 
    ON user_connections(user_id, connection_status);
CREATE INDEX IF NOT EXISTS idx_user_connections_connected_user 
    ON user_connections(connected_user_id, connection_status);

CREATE INDEX IF NOT EXISTS idx_transfer_offers_property 
    ON transfer_offers(property_id);
CREATE INDEX IF NOT EXISTS idx_transfer_offers_offering_user 
    ON transfer_offers(offering_user_id);
CREATE INDEX IF NOT EXISTS idx_transfer_offers_status 
    ON transfer_offers(offer_status);

CREATE INDEX IF NOT EXISTS idx_transfers_requested_serial 
    ON transfers(requested_serial_number) 
    WHERE requested_serial_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_transfers_type_initiator 
    ON transfers(transfer_type, initiator_id);

CREATE INDEX IF NOT EXISTS idx_da2062_imports_user 
    ON da2062_imports(imported_by_user_id);
CREATE INDEX IF NOT EXISTS idx_da2062_imports_status 
    ON da2062_imports(status);

CREATE INDEX IF NOT EXISTS idx_da2062_import_items_import 
    ON da2062_import_items(import_id);
CREATE INDEX IF NOT EXISTS idx_da2062_import_items_property 
    ON da2062_import_items(property_id);

-- 14. ADD TRIGGERS FOR UPDATED_AT
CREATE TRIGGER IF NOT EXISTS update_user_connections_updated_at 
BEFORE UPDATE ON user_connections 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 15. ADD COMMENTS FOR NEW TABLES
COMMENT ON TABLE da2062_imports IS 'Track DA Form 2062 OCR imports';
COMMENT ON TABLE da2062_import_items IS 'Individual items from DA2062 imports';
COMMENT ON TABLE user_connections IS 'User friendship network for Venmo-style transfers';
COMMENT ON TABLE transfer_offers IS 'Property offers to multiple recipients';
COMMENT ON TABLE transfer_offer_recipients IS 'Recipients for transfer offers';

-- 16. MIGRATE EXISTING DATA
-- Auto-create connections from past successful transfers
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
SELECT DISTINCT 
    t.from_user_id,
    t.to_user_id,
    'accepted',
    MIN(t.created_at)
FROM transfers t
WHERE t.status IN ('accepted', 'completed')
GROUP BY t.from_user_id, t.to_user_id
ON CONFLICT (user_id, connected_user_id) DO NOTHING;

-- Create reverse connections
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
SELECT DISTINCT 
    t.to_user_id,
    t.from_user_id,
    'accepted',
    MIN(t.created_at)
FROM transfers t
WHERE t.status IN ('accepted', 'completed')
GROUP BY t.to_user_id, t.from_user_id
ON CONFLICT (user_id, connected_user_id) DO NOTHING;

-- 17. UPDATE CATALOG FOR MIGRATION COMPLETION
INSERT INTO catalog_updates (update_source, update_date, notes) VALUES 
('SCHEMA_MIGRATION_008', CURRENT_TIMESTAMP, 
 'Complete schema alignment: removed QR codes, added DA2062 OCR, standardized property terminology, added user connections'); 