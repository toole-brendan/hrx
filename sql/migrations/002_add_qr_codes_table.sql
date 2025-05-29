-- sql/migrations/002_add_qr_codes_table.sql
-- Migration to add QR codes table for HandReceipt system

-- Create QR codes table if it doesn't exist
CREATE TABLE IF NOT EXISTS qr_codes (
    id SERIAL PRIMARY KEY,
    inventory_item_id INTEGER NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
    qr_code_data TEXT NOT NULL,
    qr_code_hash VARCHAR(64) UNIQUE NOT NULL,
    generated_by_user_id INTEGER NOT NULL REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deactivated_at TIMESTAMP
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_qr_codes_item_active 
    ON qr_codes(inventory_item_id, is_active);

CREATE INDEX IF NOT EXISTS idx_qr_codes_hash 
    ON qr_codes(qr_code_hash);

CREATE INDEX IF NOT EXISTS idx_qr_codes_generated_by 
    ON qr_codes(generated_by_user_id);

-- Add comments for documentation
COMMENT ON TABLE qr_codes IS 'Stores QR codes generated for inventory items';
COMMENT ON COLUMN qr_codes.inventory_item_id IS 'Foreign key to the inventory item this QR code represents';
COMMENT ON COLUMN qr_codes.qr_code_data IS 'JSON data encoded in the QR code';
COMMENT ON COLUMN qr_codes.qr_code_hash IS 'SHA-256 hash of the QR code data for verification';
COMMENT ON COLUMN qr_codes.generated_by_user_id IS 'User who generated this QR code';
COMMENT ON COLUMN qr_codes.is_active IS 'Whether this QR code is currently active';
COMMENT ON COLUMN qr_codes.deactivated_at IS 'Timestamp when this QR code was deactivated';

-- Function to automatically deactivate old QR codes when a new one is generated
CREATE OR REPLACE FUNCTION deactivate_old_qr_codes()
RETURNS TRIGGER AS $$
BEGIN
    -- Deactivate all other active QR codes for this inventory item
    UPDATE qr_codes 
    SET is_active = FALSE, 
        deactivated_at = CURRENT_TIMESTAMP
    WHERE inventory_item_id = NEW.inventory_item_id 
        AND id != NEW.id 
        AND is_active = TRUE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to deactivate old QR codes
DROP TRIGGER IF EXISTS trigger_deactivate_old_qr_codes ON qr_codes;
CREATE TRIGGER trigger_deactivate_old_qr_codes
    AFTER INSERT ON qr_codes
    FOR EACH ROW
    WHEN (NEW.is_active = TRUE)
    EXECUTE FUNCTION deactivate_old_qr_codes();

-- Sample data for testing (remove in production)
-- INSERT INTO qr_codes (inventory_item_id, qr_code_data, qr_code_hash, generated_by_user_id)
-- SELECT 
--     1,
--     '{"type":"handreceipt_property","itemId":"1","serialNumber":"M4-12345","itemName":"M4 Carbine","category":"weapons","currentHolderId":"1","timestamp":"2024-01-01T00:00:00Z"}',
--     'sample_hash_' || generate_series,
--     1
-- FROM generate_series(1, 3);

-- Rollback script (save as 002_add_qr_codes_table_rollback.sql)
-- DROP TRIGGER IF EXISTS trigger_deactivate_old_qr_codes ON qr_codes;
-- DROP FUNCTION IF EXISTS deactivate_old_qr_codes();
-- DROP TABLE IF EXISTS qr_codes CASCADE; 