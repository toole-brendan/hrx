-- Migration: Add include_components column to transfers table (PostgreSQL)
-- Created: Transfer Logic Enhancement for Component Association Feature
-- Description: Adds the include_components column to enable transfers of properties with their attached components

-- Add include_components column to transfers table
ALTER TABLE transfers 
ADD COLUMN IF NOT EXISTS include_components BOOLEAN NOT NULL DEFAULT FALSE;

-- Create index for better performance on component-related transfer queries
CREATE INDEX IF NOT EXISTS idx_transfers_include_components 
    ON transfers(include_components, property_id) 
    WHERE include_components = TRUE;

-- Add comment for documentation
COMMENT ON COLUMN transfers.include_components IS 'Indicates whether attached components should be included in the transfer';

-- Optional: Update existing transfers to explicitly set the default value
-- UPDATE transfers SET include_components = FALSE WHERE include_components IS NULL; 