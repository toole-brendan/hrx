-- Corrected Seed Data for HandReceipt Production Database
-- This file matches the actual database schema on your Lightsail instance

-- Create test users (without email, unit, role fields)
-- Main mock user: michael.rodriguez (5 taps on logo)
INSERT INTO users (username, password, name, rank) 
VALUES (
    'michael.rodriguez',
    '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', -- bcrypt hash of 'password123'
    'Michael Rodriguez',
    'CPT'
) ON CONFLICT (username) DO NOTHING;

-- Additional test users for transfers
INSERT INTO users (username, password, name, rank) 
VALUES 
    ('john.doe', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'John Doe', 'SFC'),
    ('sarah.thompson', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'Sarah Thompson', '1LT'),
    ('james.wilson', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'James Wilson', 'SSG')
ON CONFLICT (username) DO NOTHING;

-- Add NSN records (simplified structure)
INSERT INTO nsn_records (nsn, lin, item_name, description, category) 
VALUES 
    -- Weapons
    ('1005-01-231-0973', 'R95996', 'RIFLE,5.56 MILLIMETER', 'M4 Carbine, 5.56mm NATO, select fire rifle', 'weapons'),
    ('1005-01-447-3405', 'P95215', 'PISTOL,CALIBER .45', 'M1911A1 .45 caliber pistol', 'weapons'),
    ('1005-01-565-7445', 'M20988', 'MACHINE GUN,7.62MM', 'M240B Machine Gun, 7.62mm NATO', 'weapons'),
    
    -- Optics & Night Vision
    ('5855-01-534-5931', 'M99811', 'MONOCULAR,NIGHT VISION', 'AN/PVS-14 Night Vision Monocular', 'optics'),
    ('1240-01-412-5010', 'S97120', 'SIGHT,REFLEX', 'M68 CCO Close Combat Optic', 'optics'),
    ('5855-01-647-6498', 'G43212', 'GOGGLES,NIGHT VISION', 'AN/PSQ-20 Enhanced Night Vision Goggle', 'optics'),
    
    -- Communications Equipment
    ('5820-01-451-8250', 'R12312', 'RADIO SET', 'AN/PRC-152A Multiband Radio', 'communications'),
    
    -- Body Armor & Protection
    ('8470-01-520-7373', 'B12345', 'BODY ARMOR SET', 'Improved Outer Tactical Vest (IOTV) with plates', 'protection'),
    ('8415-01-537-2755', 'H45678', 'HELMET,COMBAT', 'Advanced Combat Helmet (ACH)', 'protection'),
    
    -- Field Equipment
    ('8465-01-524-7310', 'P78901', 'PACK,COMBAT', 'MOLLE II Rucksack, Large', 'field_gear'),
    ('7210-00-782-6865', 'S23456', 'SLEEPING BAG', 'Modular Sleep System (MSS)', 'field_gear'),
    
    -- Medical Equipment
    ('6545-01-539-8165', 'M45678', 'FIRST AID KIT', 'Individual First Aid Kit (IFAK)', 'medical')
ON CONFLICT (nsn) DO NOTHING;

-- Create properties (inventory items) for michael.rodriguez
-- Weapons
INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'M4 Carbine',
    'M4-2024-' || LPAD(generate_series::text, 6, '0'),
    'M4 Carbine, 5.56mm NATO, select fire rifle. NSN: 1005-01-231-0973',
    'active',
    u.id
FROM generate_series(1, 2), users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'M1911A1 Pistol',
    'M1911-2024-001',
    'M1911A1 .45 caliber pistol. NSN: 1005-01-447-3405',
    'active',
    u.id
FROM users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Optics & Night Vision
INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'AN/PVS-14 Night Vision',
    'NVG-2024-' || LPAD(generate_series::text, 6, '0'),
    'AN/PVS-14 Night Vision Monocular. NSN: 5855-01-534-5931',
    'active',
    u.id
FROM generate_series(1, 2), users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'M68 CCO',
    'CCO-2024-001',
    'M68 Close Combat Optic (Red Dot Sight). NSN: 1240-01-412-5010',
    'active',
    u.id
FROM users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Communications Equipment
INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'AN/PRC-152A Radio',
    'RADIO-2024-' || LPAD(generate_series::text, 6, '0'),
    'AN/PRC-152A Multiband Radio. NSN: 5820-01-451-8250',
    'active',
    u.id
FROM generate_series(1, 2), users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Body Armor & Protection
INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'IOTV Body Armor',
    'IOTV-2024-001',
    'Improved Outer Tactical Vest (IOTV) with ESAPI plates, Size: Medium. NSN: 8470-01-520-7373',
    'active',
    u.id
FROM users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'ACH Helmet',
    'ACH-2024-001',
    'Advanced Combat Helmet, Size: Large. NSN: 8415-01-537-2755',
    'active',
    u.id
FROM users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Field Equipment
INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'MOLLE II Rucksack',
    'RUCK-2024-001',
    'MOLLE II Large Rucksack with frame. NSN: 8465-01-524-7310',
    'active',
    u.id
FROM users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'Modular Sleep System',
    'MSS-2024-001',
    'Modular Sleep System (MSS) complete set. NSN: 7210-00-782-6865',
    'active',
    u.id
FROM users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Medical Equipment
INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'IFAK',
    'IFAK-2024-' || LPAD(generate_series::text, 6, '0'),
    'Individual First Aid Kit (IFAK) Gen II. NSN: 6545-01-539-8165',
    'active',
    u.id
FROM generate_series(1, 2), users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Create some items for other users (for transfer scenarios)
INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'M240B Machine Gun',
    'M240B-2024-001',
    'M240B Machine Gun, 7.62mm NATO. NSN: 1005-01-565-7445',
    'active',
    u.id
FROM users u
WHERE u.username = 'john.doe'
ON CONFLICT (serial_number) DO NOTHING;

INSERT INTO properties (name, serial_number, description, current_status, assigned_to_user_id)
SELECT 
    'AN/PSQ-20 ENVG',
    'ENVG-2024-001',
    'AN/PSQ-20 Enhanced Night Vision Goggle. NSN: 5855-01-647-6498',
    'active',
    u.id
FROM users u
WHERE u.username = 'sarah.thompson'
ON CONFLICT (serial_number) DO NOTHING;

-- Create completed transfers (history)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'michael.rodriguez'),
    'completed',
    NOW() - INTERVAL '30 days',
    NOW() - INTERVAL '30 days' + INTERVAL '2 hours',
    'Initial issue of M4 Carbine to CPT Rodriguez'
FROM properties p
WHERE p.serial_number = 'M4-2024-000001' AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'michael.rodriguez')
ON CONFLICT DO NOTHING;

INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    (SELECT id FROM users WHERE username = 'michael.rodriguez'),
    'completed',
    NOW() - INTERVAL '60 days',
    NOW() - INTERVAL '60 days' + INTERVAL '1 hour',
    'Transfer of night vision equipment for platoon deployment'
FROM properties p
WHERE p.serial_number = 'NVG-2024-000001' AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'michael.rodriguez')
ON CONFLICT DO NOTHING;

-- Create pending incoming transfers (michael.rodriguez will receive)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'michael.rodriguez'),
    'pending',
    NOW() - INTERVAL '2 days',
    'Transfer of M240B for upcoming field exercise'
FROM properties p
WHERE p.serial_number = 'M240B-2024-001'
ON CONFLICT DO NOTHING;

-- Create pending outgoing transfers (michael.rodriguez is sending)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'michael.rodriguez'),
    (SELECT id FROM users WHERE username = 'james.wilson'),
    'pending',
    NOW() - INTERVAL '1 day',
    'Temporary loan of spare radio for training'
FROM properties p
WHERE p.serial_number = 'RADIO-2024-000002'
ON CONFLICT DO NOTHING;

-- Create rejected transfer
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    (SELECT id FROM users WHERE username = 'michael.rodriguez'),
    'rejected',
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days',
    'Item not available - already assigned to another unit'
FROM properties p
WHERE p.serial_number = 'ENVG-2024-001'
ON CONFLICT DO NOTHING;

-- Create activity logs
INSERT INTO activities (type, description, user_id, related_property_id, timestamp)
SELECT 
    'item_created',
    'Created property: ' || p.name,
    p.assigned_to_user_id,
    p.id,
    p.created_at
FROM properties p
WHERE p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'michael.rodriguez')
LIMIT 5
ON CONFLICT DO NOTHING;

INSERT INTO activities (type, description, user_id, related_transfer_id, timestamp)
SELECT 
    'transfer_completed',
    'Completed transfer of equipment',
    t.to_user_id,
    t.id,
    t.resolved_date
FROM transfers t
WHERE t.status = 'completed' AND t.to_user_id = (SELECT id FROM users WHERE username = 'michael.rodriguez')
ON CONFLICT DO NOTHING;

-- Summary of created data:
-- michael.rodriguez has:
-- - 2x M4 Carbines
-- - 1x M1911A1 Pistol
-- - 2x AN/PVS-14 Night Vision
-- - 1x M68 CCO
-- - 2x AN/PRC-152A Radios
-- - 1x IOTV Body Armor
-- - 1x ACH Helmet
-- - 1x MOLLE II Rucksack
-- - 1x Modular Sleep System
-- - 2x IFAKs
-- Plus various transfers in different states 