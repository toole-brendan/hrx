-- Development seed data for HandReceipt
-- This file contains test users and sample data for development

-- Create test user: michael.rodriguez
-- Password: password123 (bcrypt hash)
INSERT INTO users (username, email, password_hash, first_name, last_name, rank, unit, role, status) 
VALUES (
    'michael.rodriguez', 
    'michael.rodriguez@handreceipt.mil',
    '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', -- bcrypt hash of 'password123'
    'Michael', 
    'Rodriguez', 
    'CPT',
    'A Company, 1-502 INF',
    'user', 
    'active'
) ON CONFLICT (username) DO NOTHING;

-- Create another test user
INSERT INTO users (username, email, password_hash, first_name, last_name, rank, unit, role, status) 
VALUES (
    'john.doe', 
    'john.doe@handreceipt.mil',
    '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', -- bcrypt hash of 'password123'
    'John', 
    'Doe', 
    'SFC',
    'A Company, 1-502 INF',
    'user', 
    'active'
) ON CONFLICT (username) DO NOTHING;

-- Add sample equipment for testing
INSERT INTO equipment (
    nsn, 
    lin, 
    nomenclature, 
    serial_number, 
    status, 
    condition, 
    hand_receipt_holder_id
) 
SELECT 
    '1005-01-123-4567',
    'A12345',
    'RIFLE,5.56 MILLIMETER,M4',
    'M4-' || LPAD(generate_series::text, 6, '0'),
    'assigned',
    'serviceable',
    u.id
FROM generate_series(1, 5), users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Add some sensitive items
INSERT INTO equipment (
    nsn, 
    lin, 
    nomenclature, 
    serial_number, 
    status, 
    condition, 
    hand_receipt_holder_id,
    is_sensitive
) 
SELECT 
    '5855-01-345-6789',
    'C34567',
    'NIGHT VISION GOGGLES,AN/PVS-14',
    'NVG-' || LPAD(generate_series::text, 6, '0'),
    'assigned',
    'serviceable',
    u.id,
    true
FROM generate_series(1, 3), users u
WHERE u.username = 'michael.rodriguez'
ON CONFLICT (serial_number) DO NOTHING;

-- Add sample transfers
INSERT INTO transfers (
    equipment_id,
    from_user_id,
    to_user_id,
    transfer_type,
    status,
    notes,
    created_at
)
SELECT 
    e.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'michael.rodriguez'),
    'assignment',
    'completed',
    'Initial assignment',
    NOW() - INTERVAL '7 days'
FROM equipment e
WHERE e.hand_receipt_holder_id = (SELECT id FROM users WHERE username = 'michael.rodriguez')
LIMIT 3
ON CONFLICT DO NOTHING; 