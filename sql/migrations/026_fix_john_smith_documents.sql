-- Migration: 026_fix_john_smith_documents.sql
-- Description: Add missing documents for John Smith demo user

BEGIN;

-- Insert 6 unread hand receipt documents from Michael Johnson to John Smith
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, attachments, status, sent_at, created_at, updated_at)
SELECT 
    'transfer_form',
    'DA2062',
    'Hand Receipt - ' || p.name,
    (SELECT id FROM users WHERE email = 'michael.johnson@example.mil'),
    (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
    p.id,
    jsonb_build_object(
        'items', jsonb_build_array(
            jsonb_build_object(
                'name', p.name,
                'serial', p.serial_number,
                'nsn', COALESCE(p.nsn, 'N/A'),
                'quantity', 1
            )
        ),
        'formType', 'DA Form 2062',
        'unit', 'Bravo Company, 2-506 INF',
        'issuedBy', 'SFC Michael Johnson',
        'issuedTo', 'SSG John Smith',
        'date', (NOW() - INTERVAL '2 days')::date::text
    ),
    '[]'::jsonb,
    'unread',
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '2 days',
    NOW()
FROM properties p
WHERE p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')
  AND p.serial_number IN ('MC-1001', 'NVG-2025', 'RAD-4590', 'HV-7731', 'TK-8420', 'PX-1145');

-- Verify documents were created
SELECT 'Created ' || COUNT(*) || ' documents for John Smith' as result
FROM documents 
WHERE recipient_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')
  AND status = 'unread';

COMMIT;