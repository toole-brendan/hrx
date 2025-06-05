-- Migration: 015_seed_test_user_mock_data.sql
-- Description: Populate comprehensive mock data for test user (toole.brendan@gmail.com) with new transfer offers system

-- Clear existing data first (optional - use with caution in production)
-- Delete in proper order to respect foreign key constraints

-- Get user IDs first
DO $$
DECLARE
    user_ids INTEGER[];
BEGIN
    SELECT ARRAY(SELECT id FROM users WHERE email IN ('toole.brendan@gmail.com', 'john.doe@example.mil', 'sarah.thompson@example.mil', 'james.wilson@example.mil', 'alice.smith@example.mil')) INTO user_ids;
    
    -- Delete transfer offer recipients first
    DELETE FROM transfer_offer_recipients WHERE transfer_offer_id IN (
        SELECT id FROM transfer_offers WHERE offering_user_id = ANY(user_ids)
    );
    
    -- Delete transfer offers
    DELETE FROM transfer_offers WHERE offering_user_id = ANY(user_ids);
    
    -- Delete activities
    DELETE FROM activities WHERE user_id = ANY(user_ids);
    
    -- Delete documents (sender and recipient)
    DELETE FROM documents WHERE sender_user_id = ANY(user_ids) OR recipient_user_id = ANY(user_ids);
    
    -- Delete transfers
    DELETE FROM transfers WHERE from_user_id = ANY(user_ids) OR to_user_id = ANY(user_ids);
    
    -- Delete properties
    DELETE FROM properties WHERE assigned_to_user_id = ANY(user_ids);
    
    -- Delete user connections (both directions)
    DELETE FROM user_connections WHERE user_id = ANY(user_ids) OR connected_user_id = ANY(user_ids);
    
    -- Finally delete users
    DELETE FROM users WHERE id = ANY(user_ids);
END $$;

-- 1. Create test users with updated password hash (no username field)
INSERT INTO users (email, password, "name", rank, unit, phone, dodid, created_at, updated_at)
VALUES 
    ('toole.brendan@gmail.com', 
     '$2a$10$D78v.wjjIXZNvKA5r/COb.jpm10XGmg5.gO0m0hKqAMuztodFqYW2',  -- bcrypt hash for "Yankees1!"
     'Brendan Toole', '1LT', '2-506, 3BCT', '910-555-0123', '1234567890', NOW(), NOW()),
    ('john.doe@example.mil',
     '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',  -- bcrypt hash for "password123"
     'John Doe', 'SFC', '2-506, 3BCT', '910-555-0124', '1234567891', NOW(), NOW()),
    ('sarah.thompson@example.mil',
     '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',  -- bcrypt hash for "password123"
     'Sarah Thompson', '1LT', '2-506, 3BCT', '910-555-0125', '1234567892', NOW(), NOW()),
    ('james.wilson@example.mil',
     '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',  -- bcrypt hash for "password123"
     'James Wilson', 'SSG', '2-506, 3BCT', '910-555-0126', '1234567893', NOW(), NOW()),
    ('alice.smith@example.mil',
     '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',  -- bcrypt hash for "password123"
     'Alice Smith', 'CPT', '2-506, 3BCT', '910-555-0127', '1234567894', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;

-- 2. Establish user connections (network)
-- Accepted connections: Test user <-> John, Sarah, James
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
VALUES 
    ((SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     (SELECT id FROM users WHERE email = 'john.doe@example.mil'),
     'accepted', NOW(), NOW()),
    ((SELECT id FROM users WHERE email = 'john.doe@example.mil'),
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     'accepted', NOW(), NOW()),
    ((SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil'),
     'accepted', NOW(), NOW()),
    ((SELECT id FROM users WHERE email = 'sarah.thompson@example.mil'),
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     'accepted', NOW(), NOW()),
    ((SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     (SELECT id FROM users WHERE email = 'james.wilson@example.mil'),
     'accepted', NOW(), NOW()),
    ((SELECT id FROM users WHERE email = 'james.wilson@example.mil'),
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     'accepted', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Pending connection: Alice Smith -> Brendan (Alice sent request that Brendan has not accepted yet)
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
VALUES (
    (SELECT id FROM users WHERE email = 'alice.smith@example.mil'),
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    'pending', NOW(), NOW()
) ON CONFLICT DO NOTHING;

-- 3. Insert properties (inventory items)
-- Brendan's properties
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, photo_url, created_at, updated_at)
VALUES 
    ('M4 Carbine', 'M4-2025-000001',
     'M4 Carbine, 5.56mm rifle (NSN 1005-01-231-0973)', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '1005-01-231-0973', 'Arms Room - Rack 3A', 3200.00, 1,
     NULL, NOW(), NOW()),
    ('M4 Carbine', 'M4-2025-000002',
     'M4 Carbine, 5.56mm rifle - undergoing repairs', 
     'maintenance', 'needs_repair',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '1005-01-231-0973', 'Maintenance Bay 2', 3200.00, 1,
     NULL, NOW(), NOW()),
    ('AN/PVS-14 Night Vision', 'NVG-2025-000001',
     'AN/PVS-14 Night Vision Monocular (NSN 5855-01-534-5931)', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '5855-01-534-5931', 'Individual Kit', 4500.00, 1,
     'https://via.placeholder.com/400x300.png?text=Night+Vision',
     NOW(), NOW()),
    ('AN/PRC-152A Radio', 'RADIO-2025-000001',
     'AN/PRC-152A Multiband Radio (NSN 5820-01-451-8250)', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '5820-01-451-8250', 'Individual Kit', 6800.00, 1,
     NULL, NOW(), NOW()),
    ('AN/PRC-152A Radio', 'RADIO-2025-000002',
     'AN/PRC-152A Multiband Radio (NSN 5820-01-451-8250) - spare unit', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '5820-01-451-8250', 'Individual Kit', 6800.00, 1,
     NULL, NOW(), NOW()),
    ('IOTV Body Armor', 'IOTV-2025-000001',
     'Improved Outer Tactical Vest (IOTV) - Medium', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '8470-01-580-1200', 'Individual Kit', 850.00, 1,
     NULL, NOW(), NOW()),
    ('ACH Helmet', 'ACH-2025-000001',
     'Advanced Combat Helmet - Large', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '8470-01-534-8800', 'Individual Kit', 320.00, 1,
     NULL, NOW(), NOW()),
    ('Lensatic Compass', 'COMP-2025-000001',
     'Lensatic Compass for land navigation', 
     'lost', 'unserviceable',
     (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
     '6605-01-196-6971', 'Unknown', 45.00, 1,
     NULL, NOW(), NOW())
ON CONFLICT (serial_number) DO NOTHING;

-- John Doe's properties
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, photo_url, created_at, updated_at)
VALUES (
    'M240B Machine Gun', 'M240B-2025-000001',
    'M240B 7.62mm Machine Gun (NSN 1005-01-565-7445)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE email = 'john.doe@example.mil'),
    '1005-01-565-7445', 'Arms Room - Rack 1A', 14500.00, 1,
    NULL, NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- Sarah Thompson's properties
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, photo_url, created_at, updated_at)
VALUES (
    'AN/PSQ-20 ENVG', 'ENVG-2025-000001',
    'AN/PSQ-20 Enhanced Night Vision Goggle (NSN 5855-01-647-6498)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil'),
    '5855-01-647-6498', 'Individual Kit', 8200.00, 1,
    NULL, NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- James Wilson's properties  
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, photo_url, created_at, updated_at)
VALUES (
    'M249 SAW', 'SAW-2025-000001',
    'M249 Squad Automatic Weapon (NSN 1005-01-357-5339)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE email = 'james.wilson@example.mil'),
    '1005-01-357-5339', 'Arms Room - Rack 2B', 7200.00, 1,
    NULL, NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- 4. Insert completed transfer records (historical transfers)
-- Completed transfer: John Doe issued an M4 Carbine to Brendan 30 days ago
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, transfer_type, initiator_id, request_date, resolved_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE email = 'john.doe@example.mil'),
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    'accepted',
    'offer',
    (SELECT id FROM users WHERE email = 'john.doe@example.mil'),
    NOW() - INTERVAL '30 days',
    NOW() - INTERVAL '30 days' + INTERVAL '2 hours',
    'Initial issue of M4 Carbine to 1LT Toole',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'M4-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- Completed transfer: Sarah Thompson transferred AN/PVS-14 NVGs to Brendan 60 days ago
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, transfer_type, initiator_id, request_date, resolved_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil'),
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    'accepted',
    'offer',
    (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil'),
    NOW() - INTERVAL '60 days',
    NOW() - INTERVAL '60 days' + INTERVAL '1 hour',
    'Transfer of night vision goggles to 1LT Toole for deployment',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'NVG-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- 5. Insert ACTIVE transfer offers (using new transfer_offers system)
-- Active offer: John Doe is offering his M240B to Brendan (created 2 days ago)
INSERT INTO transfer_offers (property_id, offering_user_id, offer_status, notes, expires_at, created_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE email = 'john.doe@example.mil'),
    'active',
    'Offering M240B for upcoming training exercise. Available for 7 days.',
    NOW() + INTERVAL '5 days',
    NOW() - INTERVAL '2 days'
FROM properties p
WHERE p.serial_number = 'M240B-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'john.doe@example.mil')
ON CONFLICT DO NOTHING;

-- Add Brendan as recipient of John's M240B offer
INSERT INTO transfer_offer_recipients (transfer_offer_id, recipient_user_id)
SELECT 
    to_table.id,
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
FROM transfer_offers to_table
JOIN properties p ON to_table.property_id = p.id
WHERE p.serial_number = 'M240B-2025-000001'
  AND to_table.offering_user_id = (SELECT id FROM users WHERE email = 'john.doe@example.mil')
ON CONFLICT DO NOTHING;

-- Active offer: Sarah is offering her ENVG to both Brendan and James (created 1 day ago)
INSERT INTO transfer_offers (property_id, offering_user_id, offer_status, notes, expires_at, created_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil'),
    'active',
    'Enhanced NVGs available for mission. First come, first served.',
    NOW() + INTERVAL '3 days',
    NOW() - INTERVAL '1 day'
FROM properties p
WHERE p.serial_number = 'ENVG-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil')
ON CONFLICT DO NOTHING;

-- Add recipients for Sarah's ENVG offer (multiple recipients)
INSERT INTO transfer_offer_recipients (transfer_offer_id, recipient_user_id, viewed_at)
SELECT 
    to_table.id,
    users.id,
    CASE 
        WHEN users.email = 'toole.brendan@gmail.com' THEN NOW() - INTERVAL '6 hours'
        ELSE NULL
    END
FROM transfer_offers to_table
JOIN properties p ON to_table.property_id = p.id
CROSS JOIN (
    SELECT id, email FROM users WHERE email IN ('toole.brendan@gmail.com', 'james.wilson@example.mil')
) users
WHERE p.serial_number = 'ENVG-2025-000001'
  AND to_table.offering_user_id = (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil')
ON CONFLICT DO NOTHING;

-- Brendan is offering his spare radio to James (created 4 hours ago)
INSERT INTO transfer_offers (property_id, offering_user_id, offer_status, notes, created_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    'active',
    'Spare PRC-152A available for loan. Need it back after training.',
    NOW() - INTERVAL '4 hours'
FROM properties p
WHERE p.serial_number = 'RADIO-2025-000002' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- Add James as recipient of Brendan's radio offer
INSERT INTO transfer_offer_recipients (transfer_offer_id, recipient_user_id)
SELECT 
    to_table.id,
    (SELECT id FROM users WHERE email = 'james.wilson@example.mil')
FROM transfer_offers to_table
JOIN properties p ON to_table.property_id = p.id
WHERE p.serial_number = 'RADIO-2025-000002'
  AND to_table.offering_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- 6. Insert some pending traditional transfers (using transfers table)
-- Brendan requested James's M249 SAW (using serial number request)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, transfer_type, initiator_id, requested_serial_number, include_components, request_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE email = 'james.wilson@example.mil'),
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    'pending',
    'request',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    'SAW-2025-000001',
    false,
    NOW() - INTERVAL '6 hours',
    'Requesting M249 for range training next week',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'SAW-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'james.wilson@example.mil')
ON CONFLICT DO NOTHING;

-- 7. Insert documents (digital transfer forms)
-- DA 2062 form for the completed M4 transfer
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, status, sent_at, created_at, updated_at)
SELECT 
    'transfer_form', 'DA2062',
    'Hand Receipt - M4 Carbine (DA 2062)',
    (SELECT id FROM users WHERE email = 'john.doe@example.mil'),
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    jsonb_build_object(
        'item', 'M4 Carbine',
        'serial', 'M4-2025-000001',
        'issuedBy', 'John Doe',
        'issuedTo', 'Brendan Toole',
        'form', 'DA 2062',
        'date', (NOW() - INTERVAL '29 days')::text,
        'unit', '2-506, 3BCT'
    ),
    'read',
    NOW() - INTERVAL '29 days',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'M4-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- DA 2062 form for the NVG transfer
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, status, sent_at, created_at, updated_at)
SELECT 
    'transfer_form', 'DA2062',
    'Hand Receipt - AN/PVS-14 Night Vision (DA 2062)',
    (SELECT id FROM users WHERE email = 'sarah.thompson@example.mil'),
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    jsonb_build_object(
        'item', 'AN/PVS-14 Night Vision',
        'serial', 'NVG-2025-000001',
        'issuedBy', 'Sarah Thompson',
        'issuedTo', 'Brendan Toole',
        'form', 'DA 2062',
        'date', (NOW() - INTERVAL '59 days')::text,
        'unit', '2-506, 3BCT'
    ),
    'read',
    NOW() - INTERVAL '59 days',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'NVG-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- Maintenance form for the M4 that's in maintenance
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, status, sent_at, created_at, updated_at)
SELECT 
    'maintenance_form', 'DA5988E',
    'Equipment Maintenance Request - M4 Carbine',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    (SELECT id FROM users WHERE email = 'john.doe@example.mil'),
    p.id,
    jsonb_build_object(
        'item', 'M4 Carbine',
        'serial', 'M4-2025-000002',
        'requestedBy', 'Brendan Toole',
        'maintenanceRequired', 'Bolt carrier group cleaning and function check',
        'priority', 'Routine',
        'form', 'DA 5988-E',
        'date', (NOW() - INTERVAL '7 days')::text
    ),
    'unread',
    NOW() - INTERVAL '7 days',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'M4-2025-000002'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- 8. Insert activity records to populate the activity feed
INSERT INTO activities (type, description, user_id, related_property_id, related_transfer_id, "timestamp")
SELECT 
    'transfer_completed',
    'Received M4 Carbine from John Doe',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    t.id,
    NOW() - INTERVAL '30 days'
FROM properties p
JOIN transfers t ON t.property_id = p.id
WHERE p.serial_number = 'M4-2025-000001'
  AND t.status = 'accepted'
  AND t.to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_property_id, related_transfer_id, "timestamp")
SELECT 
    'transfer_completed',
    'Received AN/PVS-14 Night Vision from Sarah Thompson',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    t.id,
    NOW() - INTERVAL '60 days'
FROM properties p
JOIN transfers t ON t.property_id = p.id
WHERE p.serial_number = 'NVG-2025-000001'
  AND t.status = 'accepted'
  AND t.to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_property_id, "timestamp")
SELECT 
    'property_maintenance',
    'M4 Carbine sent for maintenance - bolt carrier group service',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    NOW() - INTERVAL '7 days'
FROM properties p
WHERE p.serial_number = 'M4-2025-000002'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_property_id, "timestamp")
SELECT 
    'property_reported_lost',
    'Lensatic Compass reported as lost during field exercise',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    NOW() - INTERVAL '14 days'
FROM properties p
WHERE p.serial_number = 'COMP-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com')
ON CONFLICT DO NOTHING;

-- Activity for new transfer offer
INSERT INTO activities (type, description, user_id, related_property_id, "timestamp")
SELECT 
    'offer_received',
    'John Doe offered you M240B Machine Gun',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    NOW() - INTERVAL '2 days'
FROM properties p
WHERE p.serial_number = 'M240B-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'john.doe@example.mil')
ON CONFLICT DO NOTHING;

-- Activity for transfer request sent
INSERT INTO activities (type, description, user_id, related_property_id, "timestamp")
SELECT 
    'transfer_requested',
    'Requested M249 SAW from James Wilson',
    (SELECT id FROM users WHERE email = 'toole.brendan@gmail.com'),
    p.id,
    NOW() - INTERVAL '6 hours'
FROM properties p
WHERE p.serial_number = 'SAW-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'james.wilson@example.mil')
ON CONFLICT DO NOTHING;

-- 9. Update NSN records for all the items we've created
INSERT INTO nsn_records (nsn, item_name, description, category, created_at, updated_at)
VALUES 
    ('1005-01-231-0973', 'Rifle, 5.56mm, M4A1', 'M4A1 Carbine with collapsible stock', 'Weapons', NOW(), NOW()),
    ('5855-01-534-5931', 'Monocular, Night Vision', 'AN/PVS-14 Night Vision Monocular', 'Optics', NOW(), NOW()),
    ('5820-01-451-8250', 'Radio Set, Tactical', 'AN/PRC-152A Multiband Radio', 'Communications', NOW(), NOW()),
    ('6605-01-196-6971', 'Compass, Magnetic', 'Lensatic Compass', 'Navigation', NOW(), NOW()),
    ('8470-01-580-1200', 'Vest, Body Armor', 'Improved Outer Tactical Vest (IOTV)', 'Body Armor', NOW(), NOW()),
    ('8470-01-534-8800', 'Helmet, Combat', 'Advanced Combat Helmet (ACH)', 'Body Armor', NOW(), NOW()),
    ('1005-01-565-7445', 'Machine Gun, 7.62mm', 'M240B Medium Machine Gun', 'Weapons', NOW(), NOW()),
    ('5855-01-647-6498', 'Goggle, Night Vision', 'AN/PSQ-20 Enhanced Night Vision Goggle', 'Optics', NOW(), NOW()),
    ('1005-01-357-5339', 'Machine Gun, 5.56mm', 'M249 Squad Automatic Weapon', 'Weapons', NOW(), NOW())
ON CONFLICT (nsn) DO NOTHING;

-- Summary of test data created:
-- Users: 5 (Brendan + 4 friends)
-- User connections: 3 accepted, 1 pending
-- Properties: 11 total (8 for Brendan, 1 each for John, Sarah, James)
-- Transfer offers: 3 active offers showing different scenarios
-- Traditional transfers: 2 completed (historical), 1 pending request
-- Documents: 3 DA forms
-- Activities: 7 activities showing recent events
-- NSN records: 9 items with full metadata

-- This provides a comprehensive test environment showing:
-- ✅ Active transfer offers (new system)
-- ✅ Traditional transfer requests 
-- ✅ Completed historical transfers
-- ✅ User connections and networking
-- ✅ Property maintenance and loss scenarios
-- ✅ Document management
-- ✅ Activity tracking and notifications
