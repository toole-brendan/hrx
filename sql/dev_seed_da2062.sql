-- Development seed data for DA2062 OCR imports
-- This creates sample import records for testing the OCR functionality

-- Sample completed DA2062 import
INSERT INTO da2062_imports (
    file_name, 
    file_url,
    imported_by_user_id, 
    status, 
    total_items, 
    processed_items,
    failed_items,
    created_at,
    completed_at
)
SELECT 
    'DA2062_Alpha_Company_2024.pdf',
    '/minio/da2062/DA2062_Alpha_Company_2024.pdf',
    u.id,
    'completed',
    25,
    25,
    0,
    CURRENT_TIMESTAMP - INTERVAL '2 days',
    CURRENT_TIMESTAMP - INTERVAL '2 days' + INTERVAL '5 minutes'
FROM users u
WHERE u.username = 'michael.rodriguez'
LIMIT 1;

-- Add sample import items for the completed import
INSERT INTO da2062_import_items (import_id, line_number, raw_data, property_id, status, created_at)
SELECT 
    di.id,
    line_num,
    jsonb_build_object(
        'stock_number', nsn_records.nsn,
        'item_description', nsn_records.item_name,
        'ui', nsn_records.unit_of_issue,
        'quantity', 1,
        'serial_number', 'OCR-' || LPAD(line_num::text, 6, '0'),
        'condition_code', 'A'
    ),
    NULL, -- Property would be created during processing
    'processed',
    di.created_at + (INTERVAL '1 second' * line_num)
FROM da2062_imports di
CROSS JOIN LATERAL (
    SELECT ROW_NUMBER() OVER () as line_num, *
    FROM nsn_records
    WHERE category IN ('weapons', 'optics', 'communications')
    LIMIT 10
) nsn_records
WHERE di.file_name = 'DA2062_Alpha_Company_2024.pdf';

-- Sample in-progress DA2062 import
INSERT INTO da2062_imports (
    file_name,
    file_url, 
    imported_by_user_id, 
    status, 
    total_items, 
    processed_items,
    failed_items,
    created_at
)
SELECT 
    'DA2062_Bravo_Company_Equipment.pdf',
    '/minio/da2062/DA2062_Bravo_Company_Equipment.pdf',
    u.id,
    'processing',
    50,
    30,
    2,
    CURRENT_TIMESTAMP - INTERVAL '30 minutes'
FROM users u
WHERE u.username = 'john.doe'
LIMIT 1;

-- Add some processed and failed items for the in-progress import
INSERT INTO da2062_import_items (import_id, line_number, raw_data, property_id, status, error_message, created_at)
SELECT 
    di.id,
    line_num,
    CASE 
        WHEN line_num <= 30 THEN
            jsonb_build_object(
                'stock_number', '1005-01-231-0973',
                'item_description', 'RIFLE,5.56 MILLIMETER',
                'ui', 'EA',
                'quantity', 1,
                'serial_number', 'BRV-' || LPAD(line_num::text, 6, '0'),
                'condition_code', 'A'
            )
        WHEN line_num <= 32 THEN
            jsonb_build_object(
                'stock_number', 'INVALID-NSN',
                'item_description', 'UNREADABLE TEXT',
                'ui', '??',
                'quantity', 1,
                'serial_number', 'ERROR-' || line_num::text,
                'condition_code', '?'
            )
        ELSE
            jsonb_build_object(
                'stock_number', '5855-01-534-5931',
                'item_description', 'MONOCULAR,NIGHT VISION',
                'ui', 'EA',
                'quantity', 1,
                'serial_number', 'PENDING-' || line_num::text,
                'condition_code', 'B'
            )
    END,
    CASE WHEN line_num <= 30 THEN NULL ELSE NULL END, -- No properties created yet
    CASE 
        WHEN line_num <= 30 THEN 'processed'
        WHEN line_num <= 32 THEN 'failed'
        ELSE 'pending'
    END,
    CASE 
        WHEN line_num = 31 THEN 'Invalid NSN format'
        WHEN line_num = 32 THEN 'OCR could not read serial number clearly'
        ELSE NULL
    END,
    di.created_at + (INTERVAL '10 second' * line_num)
FROM da2062_imports di
CROSS JOIN generate_series(1, 40) as line_num
WHERE di.file_name = 'DA2062_Bravo_Company_Equipment.pdf';

-- Sample failed DA2062 import
INSERT INTO da2062_imports (
    file_name,
    file_url,
    imported_by_user_id, 
    status, 
    total_items, 
    processed_items,
    failed_items,
    error_log,
    created_at,
    completed_at
)
SELECT 
    'corrupted_scan.pdf',
    '/minio/da2062/corrupted_scan.pdf',
    u.id,
    'failed',
    0,
    0,
    0,
    jsonb_build_object(
        'error', 'PDF parsing failed',
        'message', 'Unable to extract text from PDF. File may be corrupted or image-only.',
        'timestamp', CURRENT_TIMESTAMP - INTERVAL '1 hour'
    ),
    CURRENT_TIMESTAMP - INTERVAL '1 hour',
    CURRENT_TIMESTAMP - INTERVAL '1 hour' + INTERVAL '30 seconds'
FROM users u
WHERE u.username = 'sarah.thompson'
LIMIT 1;

-- Create some sample transfer offers to go with imports
INSERT INTO transfer_offers (
    property_id,
    offering_user_id,
    offer_status,
    notes,
    expires_at,
    created_at
)
SELECT 
    p.id,
    p.assigned_to_user_id,
    'active',
    'Equipment from recent DA2062 import - available for transfer',
    CURRENT_TIMESTAMP + INTERVAL '7 days',
    CURRENT_TIMESTAMP - INTERVAL '1 hour'
FROM properties p
WHERE p.serial_number LIKE 'OCR-%'
  AND p.assigned_to_user_id IS NOT NULL
LIMIT 5;

-- Add recipients for the transfer offers
INSERT INTO transfer_offer_recipients (transfer_offer_id, recipient_user_id, notified_at)
SELECT 
    tof.id,
    uc.connected_user_id,
    CURRENT_TIMESTAMP - INTERVAL '30 minutes'
FROM transfer_offers tof
JOIN user_connections uc ON tof.offering_user_id = uc.user_id
WHERE uc.connection_status = 'accepted'
  AND tof.notes LIKE '%DA2062 import%'
GROUP BY tof.id, uc.connected_user_id
LIMIT 10;

-- Summary of DA2062 imports
SELECT 
    'Total Imports' as metric,
    COUNT(*) as count
FROM da2062_imports
UNION ALL
SELECT 
    'Completed Imports' as metric,
    COUNT(*) as count
FROM da2062_imports
WHERE status = 'completed'
UNION ALL
SELECT 
    'Items Processed' as metric,
    SUM(processed_items) as count
FROM da2062_imports
UNION ALL
SELECT 
    'Items Failed' as metric,
    SUM(failed_items) as count
FROM da2062_imports; 