-- Migration: 016_fix_transfer_offers_trigger_loop.sql
-- Description: Fix infinite loop in check_expired_offers trigger from migration 007

-- First, drop the problematic trigger that causes infinite loops
DROP TRIGGER IF EXISTS trigger_check_expired_offers ON transfer_offers;

-- Drop the old function
DROP FUNCTION IF EXISTS check_expired_offers();

-- Option 1: Create a function that can be called periodically (e.g., via cron job or application logic)
-- This avoids the trigger loop entirely
CREATE OR REPLACE FUNCTION expire_outdated_offers()
RETURNS INTEGER AS $$
DECLARE
    rows_updated INTEGER;
BEGIN
    UPDATE transfer_offers 
    SET offer_status = 'expired'
    WHERE offer_status = 'active' 
    AND expires_at IS NOT NULL 
    AND expires_at <= CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RETURN rows_updated;
END;
$$ LANGUAGE plpgsql;

-- Option 2: Use a BEFORE INSERT trigger that sets status correctly on insert
-- This prevents the need for an UPDATE after insert
CREATE OR REPLACE FUNCTION check_expired_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Only check on INSERT, and modify NEW record before it's inserted
    IF NEW.expires_at IS NOT NULL AND NEW.expires_at <= CURRENT_TIMESTAMP THEN
        NEW.offer_status = 'expired';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_expired_on_insert
BEFORE INSERT ON transfer_offers
FOR EACH ROW
EXECUTE FUNCTION check_expired_on_insert();

-- Option 3: Create a view that automatically shows expired status
-- This doesn't modify data but shows the correct status when queried
CREATE OR REPLACE VIEW transfer_offers_with_status AS
SELECT 
    id,
    property_id,
    offering_user_id,
    CASE 
        WHEN offer_status = 'active' 
             AND expires_at IS NOT NULL 
             AND expires_at <= CURRENT_TIMESTAMP 
        THEN 'expired'
        ELSE offer_status
    END as offer_status,
    notes,
    expires_at,
    created_at,
    accepted_by_user_id,
    accepted_at
FROM transfer_offers;

-- Update the user_active_offers_view to filter out expired offers
CREATE OR REPLACE VIEW user_active_offers_view AS
SELECT 
    to_table.id as offer_id,
    to_table.property_id,
    p.name as property_name,
    p.serial_number,
    to_table.offering_user_id,
    u.name as offering_user_name,
    u.rank as offering_user_rank,
    to_table.notes,
    to_table.expires_at,
    tor.recipient_user_id,
    tor.viewed_at
FROM transfer_offers to_table
JOIN transfer_offer_recipients tor ON to_table.id = tor.transfer_offer_id
JOIN properties p ON to_table.property_id = p.id
JOIN users u ON to_table.offering_user_id = u.id
WHERE to_table.offer_status = 'active'
  AND (to_table.expires_at IS NULL OR to_table.expires_at > CURRENT_TIMESTAMP);

-- Add helpful comments
COMMENT ON FUNCTION expire_outdated_offers() IS 'Manually expire outdated offers - call periodically to avoid trigger loops';
COMMENT ON VIEW transfer_offers_with_status IS 'Shows transfer offers with automatic expiry status calculation';
COMMENT ON TRIGGER trigger_check_expired_on_insert ON transfer_offers IS 'Sets expired status on insert if offer is already expired';

-- Immediately expire any currently expired offers (one-time cleanup)
SELECT expire_outdated_offers(); 