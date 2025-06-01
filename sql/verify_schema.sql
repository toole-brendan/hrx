-- Schema Verification Script for HandReceipt Database
-- Run this after applying all migrations to verify schema integrity

-- Set display format for better readability
\pset border 2
\pset format wrapped

-- 1. CHECK CORE TABLES EXIST
\echo '=== CHECKING CORE TABLES ==='
SELECT table_name, 
       CASE WHEN table_name IS NOT NULL THEN '✓ EXISTS' ELSE '✗ MISSING' END as status
FROM (
    VALUES 
        ('users'),
        ('properties'),
        ('transfers'),
        ('transfer_items'),
        ('activities'),
        ('attachments'),
        ('user_connections'),
        ('transfer_offers'),
        ('transfer_offer_recipients'),
        ('nsn_records'),
        ('catalog_updates'),
        ('da2062_imports'),
        ('da2062_import_items'),
        ('offline_sync_queue'),
        ('immudb_references')
) AS required_tables(table_name)
LEFT JOIN information_schema.tables ist 
    ON ist.table_name = required_tables.table_name 
    AND ist.table_schema = 'public'
ORDER BY required_tables.table_name;

-- 2. CHECK DEPRECATED TABLES ARE REMOVED
\echo ''
\echo '=== CHECKING DEPRECATED TABLES ARE REMOVED ==='
SELECT table_name, 
       CASE WHEN table_name IS NULL THEN '✓ REMOVED' ELSE '✗ STILL EXISTS' END as status
FROM (
    VALUES 
        ('equipment'),
        ('hand_receipts'),
        ('qr_codes'),
        ('property_types'),
        ('property_models'),
        ('nsn_items'),
        ('nsn_parts'),
        ('lin_items'),
        ('cage_codes'),
        ('nsn_synonyms'),
        ('sessions'),
        ('refresh_tokens')
) AS deprecated_tables(table_name)
LEFT JOIN information_schema.tables ist 
    ON ist.table_name = deprecated_tables.table_name 
    AND ist.table_schema = 'public'
ORDER BY deprecated_tables.table_name;

-- 3. CHECK CRITICAL COLUMNS IN KEY TABLES
\echo ''
\echo '=== CHECKING USERS TABLE COLUMNS ==='
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'users' AND table_schema = 'public'
ORDER BY ordinal_position;

\echo ''
\echo '=== CHECKING PROPERTIES TABLE COLUMNS ==='
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'properties' AND table_schema = 'public'
ORDER BY ordinal_position;

\echo ''
\echo '=== CHECKING TRANSFERS TABLE COLUMNS ==='
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'transfers' AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. CHECK NEW COLUMNS ADDED BY MIGRATIONS
\echo ''
\echo '=== CHECKING NEW COLUMNS IN TRANSFERS TABLE ==='
SELECT 
    CASE WHEN COUNT(*) > 0 THEN '✓ transfer_type column exists' ELSE '✗ transfer_type column missing' END
FROM information_schema.columns
WHERE table_name = 'transfers' AND column_name = 'transfer_type'
UNION ALL
SELECT 
    CASE WHEN COUNT(*) > 0 THEN '✓ initiator_id column exists' ELSE '✗ initiator_id column missing' END
FROM information_schema.columns
WHERE table_name = 'transfers' AND column_name = 'initiator_id'
UNION ALL
SELECT 
    CASE WHEN COUNT(*) > 0 THEN '✓ requested_serial_number column exists' ELSE '✗ requested_serial_number column missing' END
FROM information_schema.columns
WHERE table_name = 'transfers' AND column_name = 'requested_serial_number';

-- 5. CHECK CONSTRAINTS
\echo ''
\echo '=== CHECKING KEY CONSTRAINTS ==='
SELECT 
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type
FROM information_schema.table_constraints tc
WHERE tc.table_schema = 'public'
    AND tc.table_name IN ('users', 'properties', 'transfers', 'user_connections', 'transfer_offers')
    AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE', 'CHECK')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- 6. CHECK INDEXES
\echo ''
\echo '=== CHECKING PERFORMANCE INDEXES ==='
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('users', 'properties', 'transfers', 'activities', 
                      'user_connections', 'transfer_offers', 'nsn_records', 'da2062_imports')
    AND indexname NOT LIKE '%_pkey'
ORDER BY tablename, indexname;

-- 7. CHECK VIEWS
\echo ''
\echo '=== CHECKING VIEWS ==='
SELECT 
    viewname,
    CASE WHEN viewname IS NOT NULL THEN '✓ EXISTS' ELSE '✗ MISSING' END as status
FROM (
    VALUES 
        ('active_properties_view'),
        ('user_friends_view'),
        ('pending_connection_requests_view'),
        ('pending_serial_requests_view'),
        ('da2062_import_status_view'),
        ('user_active_offers_view')
) AS required_views(viewname)
LEFT JOIN pg_views pv 
    ON pv.viewname = required_views.viewname 
    AND pv.schemaname = 'public'
ORDER BY required_views.viewname;

-- 8. CHECK TRIGGERS
\echo ''
\echo '=== CHECKING TRIGGERS ==='
SELECT 
    event_object_table as table_name,
    trigger_name,
    event_manipulation as trigger_event,
    action_timing as trigger_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- 9. CHECK ROW COUNTS
\echo ''
\echo '=== TABLE ROW COUNTS ==='
WITH table_counts AS (
    SELECT 'users' as table_name, COUNT(*) as row_count FROM users
    UNION ALL
    SELECT 'properties', COUNT(*) FROM properties
    UNION ALL
    SELECT 'transfers', COUNT(*) FROM transfers
    UNION ALL
    SELECT 'activities', COUNT(*) FROM activities
    UNION ALL
    SELECT 'user_connections', COUNT(*) FROM user_connections
    UNION ALL
    SELECT 'transfer_offers', COUNT(*) FROM transfer_offers
    UNION ALL
    SELECT 'nsn_records', COUNT(*) FROM nsn_records
    UNION ALL
    SELECT 'da2062_imports', COUNT(*) FROM da2062_imports
)
SELECT table_name, row_count
FROM table_counts
ORDER BY table_name;

-- 10. CHECK FOR ORPHANED DATA
\echo ''
\echo '=== CHECKING FOR ORPHANED DATA ==='

-- Check for transfers with non-existent users
SELECT 'Transfers with invalid from_user_id' as check_name,
       COUNT(*) as count
FROM transfers t
LEFT JOIN users u ON t.from_user_id = u.id
WHERE u.id IS NULL

UNION ALL

SELECT 'Transfers with invalid to_user_id' as check_name,
       COUNT(*) as count
FROM transfers t
LEFT JOIN users u ON t.to_user_id = u.id
WHERE u.id IS NULL

UNION ALL

-- Check for properties with non-existent users
SELECT 'Properties with invalid assigned_to_user_id' as check_name,
       COUNT(*) as count
FROM properties p
LEFT JOIN users u ON p.assigned_to_user_id = u.id
WHERE p.assigned_to_user_id IS NOT NULL AND u.id IS NULL

UNION ALL

-- Check for user_connections with non-existent users
SELECT 'User connections with invalid user_id' as check_name,
       COUNT(*) as count
FROM user_connections uc
LEFT JOIN users u ON uc.user_id = u.id
WHERE u.id IS NULL;

-- 11. FINAL SUMMARY
\echo ''
\echo '=== SCHEMA VERIFICATION COMPLETE ==='
\echo 'Review the output above for any ✗ marks or unexpected results.'
\echo 'All ✓ marks indicate the schema is correctly configured.' 