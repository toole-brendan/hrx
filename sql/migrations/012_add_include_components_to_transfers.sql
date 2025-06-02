-- Migration: Add include_components column to transfers table
-- Created: Transfer Logic Enhancement for Component Association Feature
-- Description: Adds the include_components column to enable transfers of properties with their attached components

-- Add include_components column to transfers table
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('HandReceipt.Transfers') 
    AND name = 'include_components'
)
BEGIN
    ALTER TABLE HandReceipt.Transfers 
    ADD include_components BIT NOT NULL DEFAULT 0;
    
    PRINT 'Added include_components column to Transfers table';
END
ELSE
BEGIN
    PRINT 'include_components column already exists in Transfers table';
END

-- Create index for better performance on component-related transfer queries
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Transfers_IncludeComponents' AND object_id = OBJECT_ID('HandReceipt.Transfers'))
BEGIN
    CREATE INDEX IX_Transfers_IncludeComponents ON HandReceipt.Transfers(include_components, property_id) 
    WHERE include_components = 1;
    PRINT 'Index IX_Transfers_IncludeComponents created';
END

PRINT 'Transfer component enhancement migration completed successfully'; 