-- Migration to rename immudb_references to ledger_references
-- This reflects the change from ImmuDB to Azure SQL Database ledger tables

-- Rename the table
ALTER TABLE immudb_references RENAME TO ledger_references;

-- Rename the columns
ALTER TABLE ledger_references RENAME COLUMN immudb_key TO ledger_transaction_id;
ALTER TABLE ledger_references RENAME COLUMN immudb_index TO ledger_sequence_number;

-- Add comment to document the change
COMMENT ON TABLE ledger_references IS 'References to Azure SQL Database ledger table entries for audit trail';
COMMENT ON COLUMN ledger_references.ledger_transaction_id IS 'Transaction ID from Azure SQL Database ledger tables';
COMMENT ON COLUMN ledger_references.ledger_sequence_number IS 'Sequence number from Azure SQL Database ledger tables';