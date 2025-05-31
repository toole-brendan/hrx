-- Migration 006: Transfer System Refactoring - Phase 1
-- Transition from QR code-based transfers to serial number + friends network system
-- This migration implements the friends network and updates transfer workflow

-- 1. Create User Connections Table (Friends Network)
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

-- 2. Create indexes for user connections performance
CREATE INDEX IF NOT EXISTS idx_user_connections_user_id 
    ON user_connections(user_id, connection_status);
CREATE INDEX IF NOT EXISTS idx_user_connections_connected_user 
    ON user_connections(connected_user_id, connection_status);
CREATE INDEX IF NOT EXISTS idx_user_connections_status 
    ON user_connections(connection_status);

-- 3. Update Transfers Table for new workflow
-- Add transfer type to distinguish between requests and offers
ALTER TABLE transfers 
ADD COLUMN IF NOT EXISTS transfer_type VARCHAR(20) DEFAULT 'offer' 
    CHECK (transfer_type IN ('request', 'offer'));

-- Add initiator_id to track who started the transfer
ALTER TABLE transfers 
ADD COLUMN IF NOT EXISTS initiator_id BIGINT REFERENCES users(id);

-- Update existing transfers to set initiator as from_user for historical data
UPDATE transfers 
SET initiator_id = from_user_id 
WHERE initiator_id IS NULL;

-- Add requested_serial_number for serial number-based requests
ALTER TABLE transfers 
ADD COLUMN IF NOT EXISTS requested_serial_number TEXT;

-- Add index for serial number lookups
CREATE INDEX IF NOT EXISTS idx_transfers_requested_serial 
    ON transfers(requested_serial_number) 
    WHERE requested_serial_number IS NOT NULL;

-- Add index for transfer type and initiator
CREATE INDEX IF NOT EXISTS idx_transfers_type_initiator 
    ON transfers(transfer_type, initiator_id);

-- 4. Deprecate QR Code System (Soft Delete Approach)
-- Add deprecation timestamp to QR codes table
ALTER TABLE qr_codes 
ADD COLUMN IF NOT EXISTS deprecated_at TIMESTAMP WITH TIME ZONE;

-- Mark all existing QR codes as deprecated
UPDATE qr_codes 
SET deprecated_at = CURRENT_TIMESTAMP,
    is_active = FALSE
WHERE deprecated_at IS NULL;

-- 5. Create updated_at trigger for user_connections
CREATE TRIGGER IF NOT EXISTS update_user_connections_updated_at 
BEFORE UPDATE ON user_connections 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 6. Migrate existing transfer relationships to connections (auto-friend past transfer partners)
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
SELECT DISTINCT 
    t1.from_user_id as user_id,
    t1.to_user_id as connected_user_id,
    'accepted' as connection_status,
    MIN(t1.created_at) as created_at
FROM transfers t1
WHERE t1.status IN ('accepted', 'completed')
  AND NOT EXISTS (
      SELECT 1 FROM user_connections uc 
      WHERE uc.user_id = t1.from_user_id 
        AND uc.connected_user_id = t1.to_user_id
  )
GROUP BY t1.from_user_id, t1.to_user_id

UNION

SELECT DISTINCT 
    t2.to_user_id as user_id,
    t2.from_user_id as connected_user_id,
    'accepted' as connection_status,
    MIN(t2.created_at) as created_at
FROM transfers t2
WHERE t2.status IN ('accepted', 'completed')
  AND NOT EXISTS (
      SELECT 1 FROM user_connections uc 
      WHERE uc.user_id = t2.to_user_id 
        AND uc.connected_user_id = t2.from_user_id
  )
GROUP BY t2.to_user_id, t2.from_user_id

ON CONFLICT (user_id, connected_user_id) DO NOTHING;

-- 7. Create helper functions for the new transfer system

-- Function to find property owner by serial number
CREATE OR REPLACE FUNCTION get_property_owner_by_serial(serial_num TEXT)
RETURNS TABLE(
    property_id BIGINT,
    owner_id BIGINT,
    owner_name TEXT,
    owner_rank TEXT,
    owner_unit TEXT,
    property_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as property_id,
        p.assigned_to_user_id as owner_id,
        u.name as owner_name,
        u.rank as owner_rank,
        u.unit as owner_unit,
        p.name as property_name
    FROM properties p
    LEFT JOIN users u ON p.assigned_to_user_id = u.id
    WHERE p.serial_number = serial_num
      AND p.current_status = 'active'
      AND p.assigned_to_user_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to check if users are connected (friends)
CREATE OR REPLACE FUNCTION are_users_connected(user1_id BIGINT, user2_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM user_connections 
        WHERE user_id = user1_id 
          AND connected_user_id = user2_id 
          AND connection_status = 'accepted'
    ) OR EXISTS (
        SELECT 1 FROM user_connections 
        WHERE user_id = user2_id 
          AND connected_user_id = user1_id 
          AND connection_status = 'accepted'
    );
END;
$$ LANGUAGE plpgsql;

-- 8. Create views for the new transfer system

-- View for user's connections (friends network)
CREATE OR REPLACE VIEW user_friends_view AS
SELECT 
    uc.user_id,
    uc.connected_user_id,
    u.name as friend_name,
    u.rank as friend_rank,
    u.unit as friend_unit,
    u.phone as friend_phone,
    uc.connection_status,
    uc.created_at as connection_date
FROM user_connections uc
JOIN users u ON uc.connected_user_id = u.id
WHERE uc.connection_status = 'accepted';

-- View for pending connection requests
CREATE OR REPLACE VIEW pending_connection_requests_view AS
SELECT 
    uc.id as request_id,
    uc.user_id as requester_id,
    u1.name as requester_name,
    u1.rank as requester_rank,
    u1.unit as requester_unit,
    uc.connected_user_id as recipient_id,
    u2.name as recipient_name,
    uc.created_at as request_date
FROM user_connections uc
JOIN users u1 ON uc.user_id = u1.id
JOIN users u2 ON uc.connected_user_id = u2.id
WHERE uc.connection_status = 'pending';

-- 9. Add comments for documentation
COMMENT ON TABLE user_connections IS 'User friendship/connection network for transfers - like Venmo connections';
COMMENT ON COLUMN user_connections.connection_status IS 'Status: pending, accepted, or blocked';

COMMENT ON COLUMN transfers.transfer_type IS 'Type: request (requester wants item) or offer (owner giving item)';
COMMENT ON COLUMN transfers.initiator_id IS 'User who initiated the transfer (requester or offerer)';
COMMENT ON COLUMN transfers.requested_serial_number IS 'Serial number for property being requested';

COMMENT ON COLUMN qr_codes.deprecated_at IS 'Timestamp when QR code system was deprecated';

COMMENT ON FUNCTION get_property_owner_by_serial(TEXT) IS 'Find current owner of property by serial number';
COMMENT ON FUNCTION are_users_connected(BIGINT, BIGINT) IS 'Check if two users are connected in friends network';

-- 10. Create sample data for testing (optional - only in development)
DO $$
BEGIN
    -- Only insert sample connections if we're in a development environment
    -- and there are existing users
    IF EXISTS (SELECT 1 FROM users LIMIT 5) THEN
        -- Create some sample connections between existing users for testing
        WITH user_pairs AS (
            SELECT 
                u1.id as user1_id,
                u2.id as user2_id
            FROM users u1
            CROSS JOIN users u2
            WHERE u1.id < u2.id
            LIMIT 10
        )
        INSERT INTO user_connections (user_id, connected_user_id, connection_status)
        SELECT user1_id, user2_id, 'accepted'
        FROM user_pairs
        ON CONFLICT (user_id, connected_user_id) DO NOTHING;
    END IF;
END $$;

-- 11. Migration completion log
INSERT INTO catalog_updates (update_source, update_date, notes) VALUES 
('TRANSFER_REFACTOR_PHASE1', CURRENT_TIMESTAMP, 
 'Phase 1: Added user connections (friends network), updated transfers table, deprecated QR codes')
ON CONFLICT DO NOTHING; 