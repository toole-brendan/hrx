-- Migration: Fix Documents Table for Unread Count and Sender Copies
-- Created: 2025-06-16
-- Purpose: Ensure documents table supports proper unread counting and sender copy functionality

-- Create index for efficient unread count queries
CREATE INDEX IF NOT EXISTS idx_documents_unread_count 
ON documents(recipient_user_id, status) 
WHERE status = 'unread';

-- Create index for user documents queries (both sent and received)
CREATE INDEX IF NOT EXISTS idx_documents_user_lookup 
ON documents(sender_user_id, recipient_user_id, sent_at DESC);

-- Create index for document type filtering
CREATE INDEX IF NOT EXISTS idx_documents_type_filter 
ON documents(type, subtype, status);

-- Ensure status column has proper constraints
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'documents_status_check'
    ) THEN
        ALTER TABLE documents 
        ADD CONSTRAINT documents_status_check 
        CHECK (status IN ('unread', 'read', 'archived'));
    END IF;
END $$;

-- Ensure document type has proper constraints  
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'documents_type_check'
    ) THEN
        ALTER TABLE documents 
        ADD CONSTRAINT documents_type_check 
        CHECK (type IN ('maintenance_form', 'transfer_form'));
    END IF;
END $$;

-- Update any documents missing proper status
UPDATE documents 
SET status = 'unread' 
WHERE status IS NULL OR status = '';

-- Update any documents missing sent_at timestamp
UPDATE documents 
SET sent_at = created_at 
WHERE sent_at IS NULL;

-- Clean up any orphaned documents (safety check)
-- Remove documents where both sender and recipient users don't exist
DELETE FROM documents 
WHERE sender_user_id NOT IN (SELECT id FROM users)
   OR recipient_user_id NOT IN (SELECT id FROM users);

-- Add helpful comment for future reference
COMMENT ON INDEX idx_documents_unread_count IS 'Optimizes unread document count queries';
COMMENT ON INDEX idx_documents_user_lookup IS 'Optimizes user document listing queries';
COMMENT ON INDEX idx_documents_type_filter IS 'Optimizes document filtering by type and status'; 