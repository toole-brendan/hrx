-- Script: refresh_demo_user.sql
-- Description: Refreshes John Smith demo user data to original state
-- This should be run periodically (e.g., every 4 hours) to reset the demo account

BEGIN;

-- Get John Smith's user ID
WITH demo_user_id AS (
    SELECT id FROM users WHERE email = 'john.smith@example.mil'
)

-- 1. Reset user connections to original state
, reset_connections AS (
    -- Remove all connections for demo user
    DELETE FROM user_connections 
    WHERE user_id = (SELECT id FROM demo_user_id) 
       OR connected_user_id = (SELECT id FROM demo_user_id)
)

-- Re-create original connections
, recreate_connections AS (
    INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
    SELECT 
        CASE 
            WHEN u.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil') 
            THEN u.id 
            ELSE (SELECT id FROM demo_user_id)
        END,
        CASE 
            WHEN u.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil') 
            THEN (SELECT id FROM demo_user_id)
            ELSE u.id
        END,
        'accepted',
        NOW() - INTERVAL '14 days',
        NOW()
    FROM users u
    WHERE u.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil')
    
    UNION ALL
    
    -- Recreate pending connection from Jennifer
    SELECT 
        u.id,
        (SELECT id FROM demo_user_id),
        'pending',
        NOW() - INTERVAL '3 days',
        NOW()
    FROM users u
    WHERE u.email = 'jennifer.davis@example.mil'
)

-- 2. Reset documents to unread state
, reset_documents AS (
    UPDATE documents 
    SET status = 'unread', 
        read_at = NULL,
        updated_at = NOW()
    WHERE recipient_user_id = (SELECT id FROM demo_user_id)
      AND type = 'transfer_form'
      AND sender_user_id = (SELECT id FROM users WHERE email = 'michael.johnson@example.mil')
)

-- 3. Reset property statuses to original state
, reset_properties AS (
    UPDATE properties p
    SET 
        current_status = CASE serial_number
            WHEN 'MC-1001' THEN 'active'
            WHEN 'NVG-2025' THEN 'inactive'
            WHEN 'RAD-4590' THEN 'maintenance'
            WHEN 'HV-7731' THEN 'maintenance'
            WHEN 'TK-8420' THEN 'lost'
            WHEN 'PX-1145' THEN 'inactive'
            ELSE current_status
        END,
        condition = CASE serial_number
            WHEN 'MC-1001' THEN 'serviceable'
            WHEN 'NVG-2025' THEN 'unserviceable'
            WHEN 'RAD-4590' THEN 'needs_repair'
            WHEN 'HV-7731' THEN 'needs_repair'
            WHEN 'TK-8420' THEN 'unserviceable'
            WHEN 'PX-1145' THEN 'needs_repair'
            ELSE condition
        END,
        updated_at = NOW()
    WHERE assigned_to_user_id = (SELECT id FROM demo_user_id)
      AND serial_number IN ('MC-1001', 'NVG-2025', 'RAD-4590', 'HV-7731', 'TK-8420', 'PX-1145')
)

-- 4. Remove any transfers created during demo usage (keep only original ones)
, clean_transfers AS (
    DELETE FROM transfers
    WHERE (from_user_id = (SELECT id FROM demo_user_id) 
           OR to_user_id = (SELECT id FROM demo_user_id))
      AND created_at > NOW() - INTERVAL '1 day'
)

-- 5. Reset transfer offers
, reset_transfer_offers AS (
    -- Remove any accepted offers
    UPDATE transfer_offers 
    SET offer_status = 'active',
        accepted_by_user_id = NULL,
        accepted_at = NULL
    WHERE id IN (
        SELECT tof.id 
        FROM transfer_offers tof
        JOIN transfer_offer_recipients tor ON tof.id = tor.transfer_offer_id
        WHERE tor.recipient_user_id = (SELECT id FROM demo_user_id)
    )
)

-- 6. Clear any new activities created during demo
, clean_activities AS (
    DELETE FROM activities
    WHERE user_id = (SELECT id FROM demo_user_id)
      AND "timestamp" > NOW() - INTERVAL '1 day'
)

-- 7. Reset user's last login time (optional)
, reset_login AS (
    UPDATE users 
    SET updated_at = NOW()
    WHERE id = (SELECT id FROM demo_user_id)
)

SELECT 'Demo user data refreshed successfully' as result;

COMMIT;