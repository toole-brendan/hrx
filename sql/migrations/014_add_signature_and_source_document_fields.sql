-- Migration: Add signature URL field to users and source document URL to properties
-- Date: 2024-01-10
-- Description: Support for digital signatures and tracking original DA2062 scanned documents

-- Add signature URL field to users table for storing digital signature images
ALTER TABLE users ADD COLUMN IF NOT EXISTS signature_url VARCHAR(500);

-- Add source document URL field to properties table for audit trail of scanned forms
ALTER TABLE properties ADD COLUMN IF NOT EXISTS source_document_url VARCHAR(500);

-- Create composite index on NSN and serial number for enforcing uniqueness
-- This prevents duplicate items with the same NSN and serial number combination
-- Note: Using partial index to only enforce when NSN is not null
CREATE UNIQUE INDEX IF NOT EXISTS idx_properties_nsn_serial 
    ON properties(nsn, serial_number) 
    WHERE nsn IS NOT NULL;

-- Add index on source_ref for faster DA2062 form queries
-- This speeds up queries that group properties by their source form
CREATE INDEX IF NOT EXISTS idx_properties_source_ref 
    ON properties(source_ref) 
    WHERE source_ref IS NOT NULL;

-- Add index on signature_url for faster signature lookups
CREATE INDEX IF NOT EXISTS idx_users_signature_url 
    ON users(signature_url) 
    WHERE signature_url IS NOT NULL;

-- Comments for documentation
COMMENT ON COLUMN users.signature_url IS 'URL to the user''s stored digital signature image in blob storage';
COMMENT ON COLUMN properties.source_document_url IS 'URL to the original scanned DA2062 form or source document in blob storage'; 