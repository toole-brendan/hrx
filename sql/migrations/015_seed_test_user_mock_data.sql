-- Migration: 015_seed_test_user_mock_data.sql
-- Description: Populate comprehensive mock data for test user (toole.brendan@gmail.com) across all features

-- 1. Ensure the test user exists and create peer accounts for connections/transfers
-- Note: Production schema uses 'name' field instead of separate first_name/last_name
INSERT INTO users (username, email, password, "name", rank, unit, phone, dodid, created_at, updated_at)
VALUES 
    ('toole.brendan', 'toole.brendan@gmail.com', 
     '$2a$10$EQH.9cO8a4.2vWJwF7EqHeQOhm1a6YwzqA7fC8lOa78H3v6Y1mQtO',  -- bcrypt hash for "Yankees1!"
     'Brendan Toole', '1LT', '2-506, 3BCT', '910-555-0123', '1234567890', NOW(), NOW()),
    ('john.doe', 'john.doe@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',  -- bcrypt hash for "password123"
     'John Doe', 'SFC', '2-506, 3BCT', '910-555-0124', '1234567891', NOW(), NOW()),
    ('sarah.thompson', 'sarah.thompson@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',
     'Sarah Thompson', '1LT', '2-506, 3BCT', '910-555-0125', '1234567892', NOW(), NOW()),
    ('james.wilson', 'james.wilson@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',
     'James Wilson', 'SSG', '2-506, 3BCT', '910-555-0126', '1234567893', NOW(), NOW()),
    ('alice.smith', 'alice.smith@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',
     'Alice Smith', 'CPT', '2-506, 3BCT', '910-555-0127', '1234567894', NOW(), NOW())
ON CONFLICT (username) DO NOTHING;

-- 2. Establish user connections (network)
-- Accepted connections: Test user <-> John, Sarah, James
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
VALUES 
    ((SELECT id FROM users WHERE username = 'toole.brendan'),
     (SELECT id FROM users WHERE username = 'john.doe'),
     'accepted', NOW(), NOW()),
    ((SELECT id FROM users WHERE username = 'toole.brendan'),
     (SELECT id FROM users WHERE username = 'sarah.thompson'),
     'accepted', NOW(), NOW()),
    ((SELECT id FROM users WHERE username = 'toole.brendan'),
     (SELECT id FROM users WHERE username = 'james.wilson'),
     'accepted', NOW(), NOW())
ON CONFLICT DO NOTHING;

-- Pending connection: Alice Smith -> Brendan (Alice sent request that Brendan has not accepted yet)
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
VALUES (
    (SELECT id FROM users WHERE username = 'alice.smith'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'pending', NOW(), NOW()
) ON CONFLICT DO NOTHING;

-- 3. Insert properties (inventory items)
-- M4 Carbines for the test user: one active, one undergoing maintenance
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, photo_url, created_at, updated_at)
VALUES 
    ('M4 Carbine', 'M4-2025-000001',
     'M4 Carbine, 5.56mm rifle (NSN 1005-01-231-0973)', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     '1005-01-231-0973', 'Arms Room - Rack 3A', 3200.00, 1,
     NULL, NOW(), NOW()),
    ('M4 Carbine', 'M4-2025-000002',
     'M4 Carbine, 5.56mm rifle - undergoing repairs', 
     'maintenance', 'needs_repair',
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     '1005-01-231-0973', 'Maintenance Bay 2', 3200.00, 1,
     NULL, NOW(), NOW())
ON CONFLICT (serial_number) DO NOTHING;

-- Night Vision Goggles assigned to the test user (received from Sarah)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, photo_url, is_attachable, attachment_points, created_at, updated_at)
VALUES (
    'AN/PVS-14 Night Vision', 'NVG-2025-000001',
    'AN/PVS-14 Night Vision Monocular (NSN 5855-01-534-5931)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    '5855-01-534-5931', 'Individual Kit', 4500.00, 1,
    'https://via.placeholder.com/400x300.png?text=Night+Vision',
    false, NULL,
    NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- PRC-152A Radios for the test user (one will be loaned out)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, created_at, updated_at)
VALUES 
    ('AN/PRC-152A Radio', 'RADIO-2025-000001',
     'AN/PRC-152A Multiband Radio (NSN 5820-01-451-8250)', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     '5820-01-451-8250', 'Individual Kit', 6800.00, 1,
     NOW(), NOW()),
    ('AN/PRC-152A Radio', 'RADIO-2025-000002',
     'AN/PRC-152A Multiband Radio (NSN 5820-01-451-8250) - spare unit', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     '5820-01-451-8250', 'Individual Kit', 6800.00, 1,
     NOW(), NOW())
ON CONFLICT (serial_number) DO NOTHING;

-- A field item (Lensatic Compass) that was lost by the test user (non-operational example)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, created_at, updated_at)
VALUES (
    'Lensatic Compass', 'COMP-2025-000001',
    'Lensatic Compass for land navigation', 
    'lost', 'unserviceable',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    '6605-01-196-6971', 'Unknown', 45.00, 1,
    NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- IOTV Body Armor assigned to test user
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, created_at, updated_at)
VALUES (
    'IOTV Body Armor', 'IOTV-2025-000001',
    'Improved Outer Tactical Vest (IOTV) - Medium', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    '8470-01-580-1200', 'Individual Kit', 850.00, 1,
    NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- ACH Helmet assigned to test user
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, created_at, updated_at)
VALUES (
    'ACH Helmet', 'ACH-2025-000001',
    'Advanced Combat Helmet - Large', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    '8470-01-534-8800', 'Individual Kit', 320.00, 1,
    NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- Properties assigned to other users (for transfer scenarios):
-- Crew-served weapon (M240B Machine Gun) still assigned to John Doe (he will offer it to Brendan)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, created_at, updated_at)
VALUES (
    'M240B Machine Gun', 'M240B-2025-000001',
    'M240B 7.62mm Machine Gun (NSN 1005-01-565-7445)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'john.doe'),
    '1005-01-565-7445', 'Arms Room - Rack 1A', 14500.00, 1,
    NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- Enhanced Night Vision Goggle (ENVG) assigned to Sarah Thompson (Brendan requested it but it was not transferred)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, created_at, updated_at)
VALUES (
    'AN/PSQ-20 ENVG', 'ENVG-2025-000001',
    'AN/PSQ-20 Enhanced Night Vision Goggle (NSN 5855-01-647-6498)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    '5855-01-647-6498', 'Individual Kit', 8200.00, 1,
    NOW(), NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- 4. Insert transfer records (hand receipts / property transfers)
-- Completed transfer: John Doe issued an M4 Carbine to Brendan 30 days ago
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'completed',
    NOW() - INTERVAL '30 days',
    NOW() - INTERVAL '30 days' + INTERVAL '2 hours',
    'Initial issue of M4 Carbine to 1LT Toole',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'M4-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Completed transfer: Sarah Thompson transferred AN/PVS-14 NVGs to Brendan 60 days ago
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'completed',
    NOW() - INTERVAL '60 days',
    NOW() - INTERVAL '60 days' + INTERVAL '1 hour',
    'Transfer of night vision goggles to 1LT Toole for deployment',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'NVG-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Completed transfer: John Doe issued IOTV to Brendan 45 days ago  
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'completed',
    NOW() - INTERVAL '45 days',
    NOW() - INTERVAL '45 days' + INTERVAL '30 minutes',
    'Initial issue of body armor to 1LT Toole',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'IOTV-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Pending incoming transfer: John Doe has offered Brendan a M240B (awaiting Brendan's approval)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'pending',
    NOW() - INTERVAL '2 days',
    'Offer: M240B Machine Gun for temporary attachment to unit',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'M240B-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'john.doe')
ON CONFLICT DO NOTHING;

-- Pending outgoing transfer: Brendan is lending a spare radio to James Wilson (awaiting James's acceptance)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    (SELECT id FROM users WHERE username = 'james.wilson'),
    'pending',
    NOW() - INTERVAL '1 day',
    'Loan of AN/PRC-152A Radio (spare) for training exercise',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'RADIO-2025-000002' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Rejected transfer: Brendan requested Sarah's ENVG 5 days ago, but Sarah rejected it 4 days ago
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes, created_at, updated_at)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'rejected',
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days',
    'Request for ENVG denied: item already assigned to another unit',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'ENVG-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'sarah.thompson')
ON CONFLICT DO NOTHING;

-- 5. Insert documents (digital transfer forms)
-- DA 2062 form for the M4 issue
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, status, sent_at, created_at, updated_at)
SELECT 
    'transfer_form', 'DA2062',
    'Hand Receipt - M4 Carbine (DA 2062)',
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
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
    'unread',
    NOW() - INTERVAL '29 days',
    NOW(), NOW()
FROM properties p
WHERE p.serial_number = 'M4-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- DA 2062 form for the NVG transfer
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, status, sent_at, created_at, updated_at)
SELECT 
    'transfer_form', 'DA2062',
    'Hand Receipt - AN/PVS-14 Night Vision (DA 2062)',
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
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
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Maintenance form for the M4 that's in maintenance
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, status, sent_at, created_at, updated_at)
SELECT 
    'maintenance_form', 'DA5988E',
    'Equipment Maintenance Request - M4 Carbine',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    (SELECT id FROM users WHERE username = 'john.doe'),
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
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- 6. Insert activity records to populate the activity feed
INSERT INTO activities (type, description, user_id, related_property_id, related_transfer_id, "timestamp")
SELECT 
    'transfer_completed',
    'Received M4 Carbine from John Doe',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    p.id,
    t.id,
    NOW() - INTERVAL '30 days'
FROM properties p
JOIN transfers t ON t.property_id = p.id
WHERE p.serial_number = 'M4-2025-000001'
  AND t.status = 'completed'
  AND t.to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_property_id, related_transfer_id, "timestamp")
SELECT 
    'transfer_completed',
    'Received AN/PVS-14 Night Vision from Sarah Thompson',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    p.id,
    t.id,
    NOW() - INTERVAL '60 days'
FROM properties p
JOIN transfers t ON t.property_id = p.id
WHERE p.serial_number = 'NVG-2025-000001'
  AND t.status = 'completed'
  AND t.to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_property_id, "timestamp")
SELECT 
    'property_maintenance',
    'M4 Carbine sent for maintenance - bolt carrier group service',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    p.id,
    NOW() - INTERVAL '7 days'
FROM properties p
WHERE p.serial_number = 'M4-2025-000002'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_property_id, "timestamp")
SELECT 
    'property_reported_lost',
    'Lensatic Compass reported as lost during field exercise',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    p.id,
    NOW() - INTERVAL '14 days'
FROM properties p
WHERE p.serial_number = 'COMP-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_transfer_id, "timestamp")
SELECT 
    'transfer_rejected',
    'Request for AN/PSQ-20 ENVG was rejected by Sarah Thompson',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    t.id,
    NOW() - INTERVAL '4 days'
FROM transfers t
JOIN properties p ON t.property_id = p.id
WHERE p.serial_number = 'ENVG-2025-000001'
  AND t.status = 'rejected'
  AND t.to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- 7. Add some NSN records for the items we've created
INSERT INTO nsn_records (nsn, item_name, description, category, unit_of_issue, unit_price, created_at, updated_at)
VALUES 
    ('1005-01-231-0973', 'Rifle, 5.56mm, M4A1', 'M4A1 Carbine with collapsible stock', 'Weapons', 'EA', 3200.00, NOW(), NOW()),
    ('5855-01-534-5931', 'Monocular, Night Vision', 'AN/PVS-14 Night Vision Monocular', 'Optics', 'EA', 4500.00, NOW(), NOW()),
    ('5820-01-451-8250', 'Radio Set, Tactical', 'AN/PRC-152A Multiband Radio', 'Communications', 'EA', 6800.00, NOW(), NOW()),
    ('6605-01-196-6971', 'Compass, Magnetic', 'Lensatic Compass', 'Navigation', 'EA', 45.00, NOW(), NOW()),
    ('8470-01-580-1200', 'Vest, Body Armor', 'Improved Outer Tactical Vest (IOTV)', 'Body Armor', 'EA', 850.00, NOW(), NOW()),
    ('8470-01-534-8800', 'Helmet, Combat', 'Advanced Combat Helmet (ACH)', 'Body Armor', 'EA', 320.00, NOW(), NOW()),
    ('1005-01-565-7445', 'Machine Gun, 7.62mm', 'M240B Medium Machine Gun', 'Weapons', 'EA', 14500.00, NOW(), NOW()),
    ('5855-01-647-6498', 'Goggle, Night Vision', 'AN/PSQ-20 Enhanced Night Vision Goggle', 'Optics', 'EA', 8200.00, NOW(), NOW())
ON CONFLICT (nsn) DO NOTHING;
