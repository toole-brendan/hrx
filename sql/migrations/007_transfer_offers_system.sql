-- sql/migrations/007_transfer_offers_system.sql
-- Adds multi-recipient offer functionality to complement serial number requests

-- Create transfer offers table for one-to-many property offers
CREATE TABLE IF NOT EXISTS transfer_offers (
    id BIGSERIAL PRIMARY KEY,
    property_id BIGINT NOT NULL REFERENCES properties(id),
    offering_user_id BIGINT NOT NULL REFERENCES users(id),
    offer_status VARCHAR(20) DEFAULT 'active' 
        CHECK (offer_status IN ('active', 'accepted', 'expired', 'cancelled')),
    notes TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    accepted_by_user_id BIGINT REFERENCES users(id),
    accepted_at TIMESTAMP WITH TIME ZONE
);

-- Recipients table for multi-user offers
CREATE TABLE IF NOT EXISTS transfer_offer_recipients (
    id BIGSERIAL PRIMARY KEY,
    transfer_offer_id BIGINT NOT NULL REFERENCES transfer_offers(id) ON DELETE CASCADE,
    recipient_user_id BIGINT NOT NULL REFERENCES users(id),
    notified_at TIMESTAMP WITH TIME ZONE,
    viewed_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(transfer_offer_id, recipient_user_id)
);

-- Indexes for performance
CREATE INDEX idx_transfer_offers_property ON transfer_offers(property_id);
CREATE INDEX idx_transfer_offers_offering_user ON transfer_offers(offering_user_id);
CREATE INDEX idx_transfer_offers_status ON transfer_offers(offer_status);
CREATE INDEX idx_offer_recipients_user ON transfer_offer_recipients(recipient_user_id);

-- View for active offers to a user
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

-- Trigger to auto-expire offers
CREATE OR REPLACE FUNCTION check_expired_offers()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE transfer_offers 
    SET offer_status = 'expired'
    WHERE offer_status = 'active' 
      AND expires_at IS NOT NULL 
      AND expires_at <= CURRENT_TIMESTAMP;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_expired_offers
AFTER INSERT OR UPDATE ON transfer_offers
FOR EACH STATEMENT
EXECUTE FUNCTION check_expired_offers();

-- Add comments
COMMENT ON TABLE transfer_offers IS 'Property offers from owner to multiple potential recipients';
COMMENT ON TABLE transfer_offer_recipients IS 'Recipients for each transfer offer'; 