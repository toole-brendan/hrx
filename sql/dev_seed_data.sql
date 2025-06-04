-- Development seed data for HandReceipt
-- This file contains test users and sample data for development

-- Insert test users with military ranks and units
-- Note: Passwords are hashed using bcrypt with cost 10
-- Plain text passwords: "password123" for all users

INSERT INTO users (email, password_hash, first_name, last_name, rank, unit, role, status)
VALUES 
(
    'michael.rodriguez@handreceipt.com',
    '$2b$10$xfTImAQbmP6d7S8JGSLDXeu0yDqLRQbYdJ4Jt.1J0C8vMnGJzPXOS',
    'Michael',
    'Rodriguez',
    'CPT',
    'Bravo Company, 2-87 Infantry Battalion',
    'user',
    'active'
),
(
    'john.doe@handreceipt.com',
    '$2b$10$xfTImAQbmP6d7S8JGSLDXeu0yDqLRQbYdJ4Jt.1J0C8vMnGJzPXOS',
    'John',
    'Doe',
    'SGT',
    'Alpha Company, 1-75 Ranger Regiment',
    'user',
    'active'
) ON CONFLICT (email) DO NOTHING;

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
WHERE u.email = 'michael.rodriguez@handreceipt.com'
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
WHERE u.email = 'michael.rodriguez@handreceipt.com'
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
    (SELECT id FROM users WHERE email = 'john.doe@handreceipt.com'),
    (SELECT id FROM users WHERE email = 'michael.rodriguez@handreceipt.com'),
    'assignment',
    'completed',
    'Initial assignment',
    NOW() - INTERVAL '7 days'
FROM equipment e
WHERE e.hand_receipt_holder_id = (SELECT id FROM users WHERE email = 'michael.rodriguez@handreceipt.com')
LIMIT 3
ON CONFLICT DO NOTHING; 