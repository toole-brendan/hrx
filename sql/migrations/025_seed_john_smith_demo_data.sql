-- Migration: 025_seed_john_smith_demo_data.sql
-- Description: Comprehensive mock data for demo user John Smith showcasing all HandReceipt features
-- This creates a fully populated demo account for first-time visitors to explore the application

BEGIN;

-- 1. Insert demo user (John Smith) and supporting users for connections/transfers
WITH demo_user AS (
    INSERT INTO users (email, password_hash, first_name, last_name, rank, unit, phone, dodid, created_at, updated_at)
    VALUES 
        ('john.smith@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',  -- bcrypt hash for "password123"
         'John', 'Smith', 'SSG', 'Bravo Company, 2-506 INF', '910-555-0100', '2234567890', 
         NOW(), NOW())
    ON CONFLICT (email) DO NOTHING
    RETURNING id
),

-- Insert supporting users for connections and transfers
support_users AS (
    INSERT INTO users (email, password_hash, first_name, last_name, rank, unit, phone, dodid, created_at, updated_at)
    VALUES 
        ('michael.johnson@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Michael', 'Johnson', 'SFC', 'Supply Section, 2-506 INF', '910-555-0101', '2234567891',
         NOW(), NOW()),
        ('sarah.williams@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Sarah', 'Williams', 'CPT', 'HQ Company, 2-506 INF', '910-555-0102', '2234567892',
         NOW(), NOW()),
        ('robert.brown@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Robert', 'Brown', 'SGT', 'Bravo Company, 2-506 INF', '910-555-0103', '2234567893',
         NOW(), NOW()),
        ('jennifer.davis@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Jennifer', 'Davis', '1LT', 'Alpha Company, 2-506 INF', '910-555-0104', '2234567894',
         NOW(), NOW()),
        ('david.miller@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'David', 'Miller', 'WO1', 'Maintenance Company, 2-506 INF', '910-555-0105', '2234567895',
         NOW(), NOW())
    ON CONFLICT (email) DO NOTHING
    RETURNING id, email
),

-- 2. Create network connections
-- Accepted connections: John <-> Michael (supply officer) and John <-> Robert (squad member)
connections_accepted AS (
    INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
    SELECT 
        demo.id, support.id, 'accepted', NOW() - INTERVAL '14 days', NOW()
    FROM demo_user demo
    CROSS JOIN support_users support
    WHERE support.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil')
    
    UNION ALL
    
    SELECT 
        support.id, demo.id, 'accepted', NOW() - INTERVAL '14 days', NOW()
    FROM demo_user demo
    CROSS JOIN support_users support
    WHERE support.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil')
    ON CONFLICT DO NOTHING
),

-- Pending connection request: Jennifer Davis -> John Smith
connection_pending AS (
    INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
    SELECT 
        support.id, demo.id, 'pending', NOW() - INTERVAL '3 days', NOW()
    FROM demo_user demo
    CROSS JOIN support_users support
    WHERE support.email = 'jennifer.davis@example.mil'
    ON CONFLICT DO NOTHING
),

-- 3. Insert properties for John Smith with various statuses
demo_properties AS (
    INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, photo_url, created_at, updated_at)
    SELECT 
        prop.name, prop.serial_number, prop.description, prop.current_status, prop.condition,
        demo.id, prop.nsn, prop.location, prop.unit_price, prop.quantity, prop.photo_url,
        NOW() - prop.age_offset, NOW()
    FROM demo_user demo
    CROSS JOIN (VALUES
        -- Operational equipment
        ('M4 Carbine', 'MC-1001', 'M4 Carbine, 5.56mm rifle with ACOG scope', 'active', 'serviceable', 
         '1005-01-231-0973', 'Arms Room - Rack 3A', 3200.00, 1, NULL, INTERVAL '90 days'),
        -- Non-operational
        ('AN/PVS-14 Night Vision Goggles', 'NVG-2025', 'AN/PVS-14 Monocular Night Vision Device - lens cracked', 'inactive', 'unserviceable', 
         '5855-01-534-5931', 'Supply Cage - Bin 7', 4500.00, 1, NULL, INTERVAL '30 days'),
        -- In maintenance
        ('AN/PRC-152 Radio', 'RAD-4590', 'AN/PRC-152A Multiband Radio - awaiting antenna repair', 'maintenance', 'needs_repair', 
         '5820-01-451-8250', 'Maintenance Shop', 6800.00, 1, NULL, INTERVAL '7 days'),
        -- In repair
        ('M1165 HMMWV', 'HV-7731', 'M1165 HMMWV Up-Armored - transmission issues', 'maintenance', 'needs_repair', 
         '2320-01-523-6099', 'Motor Pool Bay 3', 285000.00, 1, NULL, INTERVAL '3 days'),
        -- Lost
        ('Mechanic''s Tool Kit', 'TK-8420', 'General Mechanic''s Tool Kit - reported missing during field exercise', 'lost', 'unserviceable', 
         '5180-01-553-6625', 'Unknown - Last seen: Field', 1250.00, 1, NULL, INTERVAL '14 days'),
        -- Damaged
        ('M9 Pistol', 'PX-1145', 'M9 Beretta 9mm Pistol - barrel damaged', 'inactive', 'needs_repair', 
         '1005-01-118-2640', 'Arms Room - Repair Rack', 650.00, 1, NULL, INTERVAL '5 days')
    ) AS prop(name, serial_number, description, current_status, condition, nsn, location, unit_price, quantity, photo_url, age_offset)
    ON CONFLICT (serial_number) DO NOTHING
    RETURNING id, name, serial_number, assigned_to_user_id
),

-- Insert property for Sarah (for pending transfer)
sarah_property AS (
    INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, created_at, updated_at)
    SELECT 
        'Satellite Phone', 'SAT-900X', 'Iridium 9575 Extreme Satellite Phone', 'active', 'serviceable',
        support.id, '5805-01-564-6627', 'HQ Comms Section', 1495.00, 1, NOW() - INTERVAL '60 days', NOW()
    FROM support_users support
    WHERE support.email = 'sarah.williams@example.mil'
    ON CONFLICT (serial_number) DO NOTHING
    RETURNING id
),

-- 4. Create transfer records

-- Completed transfer: Michael (supply) -> John (M9 Pistol was transferred to John)
completed_transfer AS (
    INSERT INTO transfers (property_id, from_user_id, to_user_id, status, transfer_type, initiator_id, request_date, resolved_date, notes, created_at, updated_at)
    SELECT 
        prop.id,
        support.id,
        prop.assigned_to_user_id,
        'accepted',
        'offer',
        support.id,
        NOW() - INTERVAL '10 days',
        NOW() - INTERVAL '8 days',
        'Initial issue of sidearm to SSG Smith',
        NOW() - INTERVAL '8 days',
        NOW()
    FROM demo_properties prop
    CROSS JOIN support_users support
    WHERE prop.serial_number = 'PX-1145' 
      AND support.email = 'michael.johnson@example.mil'
    ON CONFLICT DO NOTHING
),

-- Rejected transfer: John tried to transfer broken NVGs to Robert, but Robert rejected
rejected_transfer AS (
    INSERT INTO transfers (property_id, from_user_id, to_user_id, status, transfer_type, initiator_id, request_date, resolved_date, notes, created_at, updated_at)
    SELECT 
        prop.id,
        prop.assigned_to_user_id,
        support.id,
        'rejected',
        'offer',
        prop.assigned_to_user_id,
        NOW() - INTERVAL '5 days',
        NOW() - INTERVAL '4 days',
        'Equipment non-operational, unable to accept transfer',
        NOW() - INTERVAL '4 days',
        NOW()
    FROM demo_properties prop
    CROSS JOIN support_users support
    WHERE prop.serial_number = 'NVG-2025' 
      AND support.email = 'robert.brown@example.mil'
    ON CONFLICT DO NOTHING
),

-- 5. Create active transfer offers using the new transfer_offers system

-- Pending incoming transfer: Sarah offering Satellite Phone to John
pending_offer AS (
    INSERT INTO transfer_offers (property_id, offering_user_id, offer_status, notes, expires_at, created_at)
    SELECT 
        sarah_prop.id::bigint,
        support.id::bigint,
        'active',
        'Satellite phone available for upcoming deployment. Priority to NCOs.',
        NOW() + INTERVAL '4 days',
        NOW() - INTERVAL '1 day'
    FROM sarah_property sarah_prop
    CROSS JOIN support_users support
    WHERE support.email = 'sarah.williams@example.mil'
    ON CONFLICT DO NOTHING
    RETURNING id
),

-- Add John as recipient of Sarah's offer
pending_offer_recipient AS (
    INSERT INTO transfer_offer_recipients (transfer_offer_id, recipient_user_id)
    SELECT 
        offer.id,
        demo.id::bigint
    FROM pending_offer offer
    CROSS JOIN demo_user demo
    ON CONFLICT DO NOTHING
),

-- 6. Create documents (hand receipts) - 6 unread documents from Michael (supply officer)
documents AS (
    INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, attachments, status, sent_at, created_at, updated_at)
    SELECT 
        'transfer_form',
        'DA2062',
        'Hand Receipt - ' || dp.name,
        support.id,
        dp.assigned_to_user_id,
        dp.id,
        jsonb_build_object(
            'items', jsonb_build_array(
                jsonb_build_object(
                    'name', dp.name,
                    'serial', dp.serial_number,
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
    FROM demo_properties dp
    JOIN properties p ON dp.id = p.id
    CROSS JOIN support_users support
    WHERE support.email = 'michael.johnson@example.mil'
      AND dp.serial_number IN ('MC-1001', 'NVG-2025', 'RAD-4590', 'HV-7731', 'TK-8420', 'PX-1145')
    ON CONFLICT DO NOTHING
),

-- 7. Create activity records for recent events
activities AS (
    INSERT INTO activities (type, description, user_id, related_property_id, "timestamp")
    SELECT 
        'property_reported_lost',
        'Mechanic''s Tool Kit reported missing during field training exercise',
        demo.id,
        prop.id,
        NOW() - INTERVAL '14 days'
    FROM demo_user demo
    CROSS JOIN demo_properties prop
    WHERE prop.serial_number = 'TK-8420'
    
    UNION ALL
    
    SELECT 
        'property_maintenance',
        'M1165 HMMWV sent to motor pool for transmission repair',
        demo.id,
        prop.id,
        NOW() - INTERVAL '3 days'
    FROM demo_user demo
    CROSS JOIN demo_properties prop
    WHERE prop.serial_number = 'HV-7731'
    
    UNION ALL
    
    SELECT 
        'offer_received',
        'Sarah Williams offered you Satellite Phone',
        demo.id,
        sarah_prop.id,
        NOW() - INTERVAL '1 day'
    FROM demo_user demo
    CROSS JOIN sarah_property sarah_prop
    
    ON CONFLICT DO NOTHING
),

-- 8. Ensure NSN records exist for all equipment
nsn_records AS (
    INSERT INTO nsn_records (nsn, item_name, description, category, created_at, updated_at)
    VALUES 
        ('1005-01-231-0973', 'Rifle, 5.56mm, M4A1', 'M4A1 Carbine with collapsible stock', 'Weapons', NOW(), NOW()),
        ('5855-01-534-5931', 'Monocular, Night Vision', 'AN/PVS-14 Night Vision Monocular', 'Optics', NOW(), NOW()),
        ('5820-01-451-8250', 'Radio Set, Tactical', 'AN/PRC-152A Multiband Radio', 'Communications', NOW(), NOW()),
        ('2320-01-523-6099', 'Truck, Utility', 'M1165 HMMWV Up-Armored', 'Vehicles', NOW(), NOW()),
        ('5180-01-553-6625', 'Tool Kit, General Mechanic', 'General Mechanic''s Tool Kit', 'Tools', NOW(), NOW()),
        ('1005-01-118-2640', 'Pistol, 9mm', 'M9 Beretta 9mm Pistol', 'Weapons', NOW(), NOW()),
        ('5805-01-564-6627', 'Telephone, Satellite', 'Iridium Satellite Phone', 'Communications', NOW(), NOW())
    ON CONFLICT (nsn) DO NOTHING
)

SELECT 'John Smith demo user and comprehensive seed data created successfully' as result;

COMMIT;

-- Summary of demo data created for John Smith:
-- ✅ Main demo user: john.smith@example.mil (SSG John Smith)
-- ✅ 5 supporting users for interactions
-- ✅ Network: 2 accepted connections + 1 pending request
-- ✅ Properties: 6 items showcasing all statuses (operational, non-operational, maintenance, lost, damaged)
-- ✅ Transfers: 1 completed, 1 rejected, 1 pending offer
-- ✅ Documents: 6 unread hand receipts in inbox (triggers alert threshold)
-- ✅ Activities: Recent events in activity feed
-- ✅ NSN records: Full equipment metadata

-- This creates a rich demo environment where visitors can:
-- • See a fully populated dashboard with alerts and statistics
-- • Browse a diverse property book with various equipment statuses
-- • View pending transfers and connection requests requiring action
-- • Access an inbox full of unread documents
-- • Explore the network page with existing connections and pending requests