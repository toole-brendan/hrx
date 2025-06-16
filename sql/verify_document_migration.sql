-- Verify document migration was successful

-- Check indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'documents' 
AND indexname LIKE 'idx_documents%';

-- Check constraints
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'documents'::regclass 
AND contype = 'c';

-- Count documents by status
SELECT status, COUNT(*) as count 
FROM documents 
GROUP BY status;

-- Check for any NULL statuses that were updated
SELECT COUNT(*) as null_status_count 
FROM documents 
WHERE status IS NULL;

-- Sample of documents to verify structure
SELECT id, type, subtype, status, sender_user_id, recipient_user_id, sent_at 
FROM documents 
LIMIT 5; 