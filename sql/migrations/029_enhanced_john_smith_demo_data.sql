-- Migration: 029_enhanced_john_smith_demo_data.sql
-- Description: Comprehensive enhancement of John Smith demo data to showcase all HandReceipt features
-- This migration adds rich, realistic data for a complete demo experience

BEGIN;

-- 1. EXPAND USER NETWORK - Add more realistic military personnel connections
WITH new_support_users AS (
    INSERT INTO users (email, password_hash, first_name, last_name, rank, unit, phone, dodid, created_at, updated_at)
    VALUES 
        -- Unit Armorer
        ('james.thompson@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'James', 'Thompson', 'SSG', 'Arms Room, 2-506 INF', '910-555-0106', '2234567896',
         NOW() - INTERVAL '180 days', NOW()),
        -- Motor Pool Supervisor  
        ('maria.garcia@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Maria', 'Garcia', 'SFC', 'Motor Pool, 2-506 INF', '910-555-0107', '2234567897',
         NOW() - INTERVAL '365 days', NOW()),
        -- Communications NCO
        ('charles.wilson@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Charles', 'Wilson', 'SGT', 'S-6 Comms, 2-506 INF', '910-555-0108', '2234567898',
         NOW() - INTERVAL '90 days', NOW()),
        -- Platoon Sergeant
        ('patricia.anderson@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Patricia', 'Anderson', 'SFC', 'Bravo Company, 2-506 INF', '910-555-0109', '2234567899',
         NOW() - INTERVAL '400 days', NOW()),
        -- Company XO
        ('kevin.martinez@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Kevin', 'Martinez', '1LT', 'Bravo Company, 2-506 INF', '910-555-0110', '2234567900',
         NOW() - INTERVAL '60 days', NOW()),
        -- Squad Members
        ('thomas.jackson@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Thomas', 'Jackson', 'SPC', 'Bravo Company, 2-506 INF', '910-555-0111', '2234567901',
         NOW() - INTERVAL '30 days', NOW()),
        ('ashley.white@example.mil',
         '$2a$10$OO/VXUqj6dgahfl5haZmbO394yvakX8qd/48n1D5/snhbloAxiwQO',
         'Ashley', 'White', 'PFC', 'Bravo Company, 2-506 INF', '910-555-0112', '2234567902',
         NOW() - INTERVAL '45 days', NOW())
    ON CONFLICT (email) DO NOTHING
    RETURNING id, email
),

-- Get John Smith's ID
demo_user AS (
    SELECT id FROM users WHERE email = 'john.smith@example.mil'
),

-- 2. ENHANCE USER CONNECTIONS - Create a realistic network
expanded_connections AS (
    -- Add accepted connections with key personnel
    INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
    SELECT 
        CASE 
            WHEN u.email IN ('james.thompson@example.mil', 'maria.garcia@example.mil', 'charles.wilson@example.mil', 'patricia.anderson@example.mil') 
            THEN u.id 
            ELSE demo.id
        END,
        CASE 
            WHEN u.email IN ('james.thompson@example.mil', 'maria.garcia@example.mil', 'charles.wilson@example.mil', 'patricia.anderson@example.mil') 
            THEN demo.id
            ELSE u.id
        END,
        'accepted',
        NOW() - INTERVAL '30 days' - (random() * INTERVAL '60 days'),
        NOW()
    FROM demo_user demo
    CROSS JOIN new_support_users u
    WHERE u.email IN ('james.thompson@example.mil', 'maria.garcia@example.mil', 'charles.wilson@example.mil', 'patricia.anderson@example.mil')
    
    UNION ALL
    
    -- Add pending connection requests
    SELECT 
        u.id,
        demo.id,
        'pending',
        NOW() - INTERVAL '2 days',
        NOW()
    FROM demo_user demo
    CROSS JOIN new_support_users u
    WHERE u.email IN ('kevin.martinez@example.mil', 'thomas.jackson@example.mil')
    
    UNION ALL
    
    -- Add a blocked connection (for demonstration)
    SELECT 
        demo.id,
        u.id,
        'blocked',
        NOW() - INTERVAL '45 days',
        NOW()
    FROM demo_user demo
    CROSS JOIN new_support_users u
    WHERE u.email = 'ashley.white@example.mil'
    
    ON CONFLICT DO NOTHING
),

-- 3. ENHANCE PROPERTIES WITH DA2062 FIELDS
property_updates AS (
    UPDATE properties p
    SET 
        -- Unit of Issue
        unit_of_issue = CASE 
            WHEN p.serial_number = 'MC-1001' THEN 'EA'
            WHEN p.serial_number = 'NVG-2025' THEN 'EA'
            WHEN p.serial_number = 'RAD-4590' THEN 'EA'
            WHEN p.serial_number = 'HV-7731' THEN 'EA'
            WHEN p.serial_number = 'TK-8420' THEN 'BX'
            WHEN p.serial_number = 'PX-1145' THEN 'EA'
            ELSE 'EA'
        END,
        -- Condition Code (A=Serviceable, B=Unserviceable Repairable, C=Unserviceable Condemned)
        condition_code = CASE 
            WHEN p.condition = 'serviceable' THEN 'A'
            WHEN p.condition = 'needs_repair' THEN 'B'
            WHEN p.condition = 'unserviceable' THEN 'C'
            ELSE 'A'
        END,
        -- Category
        category = CASE 
            WHEN p.serial_number IN ('MC-1001', 'PX-1145') THEN 'WEAPON'
            WHEN p.serial_number = 'NVG-2025' THEN 'OPTICS'
            WHEN p.serial_number = 'RAD-4590' THEN 'COMMS'
            WHEN p.serial_number = 'HV-7731' THEN 'VEHICLE'
            WHEN p.serial_number = 'TK-8420' THEN 'TOOL'
            ELSE 'OTHER'
        END,
        -- Manufacturer
        manufacturer = CASE 
            WHEN p.serial_number = 'MC-1001' THEN 'Colt Defense LLC'
            WHEN p.serial_number = 'NVG-2025' THEN 'L3Harris Technologies'
            WHEN p.serial_number = 'RAD-4590' THEN 'Harris Corporation'
            WHEN p.serial_number = 'HV-7731' THEN 'AM General'
            WHEN p.serial_number = 'TK-8420' THEN 'Stanley Black & Decker'
            WHEN p.serial_number = 'PX-1145' THEN 'Beretta USA'
            ELSE NULL
        END,
        -- Part Number
        part_number = CASE 
            WHEN p.serial_number = 'MC-1001' THEN 'NSN-1005-01-231-0973'
            WHEN p.serial_number = 'NVG-2025' THEN 'NSN-5855-01-534-5931'
            WHEN p.serial_number = 'RAD-4590' THEN 'NSN-5820-01-451-8250'
            WHEN p.serial_number = 'HV-7731' THEN 'NSN-2320-01-523-6099'
            WHEN p.serial_number = 'TK-8420' THEN 'NSN-5180-01-553-6625'
            WHEN p.serial_number = 'PX-1145' THEN 'NSN-1005-01-118-2640'
            ELSE NULL
        END,
        -- Security Classification
        security_classification = CASE 
            WHEN p.category IN ('WEAPON', 'OPTICS', 'COMMS') THEN 'FOUO'
            ELSE 'U'
        END,
        -- Acquisition Date (varied dates for realism)
        acquisition_date = NOW() - (random() * INTERVAL '730 days'),
        -- Warranty Expiry (some items still under warranty)
        warranty_expiry = CASE 
            WHEN p.serial_number = 'HV-7731' THEN NOW() + INTERVAL '180 days'
            WHEN p.serial_number = 'RAD-4590' THEN NOW() + INTERVAL '90 days'
            ELSE NULL
        END,
        -- Last/Next Inspection
        last_inspection = NOW() - (random() * INTERVAL '30 days'),
        next_inspection = NOW() + INTERVAL '30 days' + (random() * INTERVAL '60 days')
    WHERE p.assigned_to_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')
    RETURNING id
),

-- 4. ADD NEW PROPERTIES FOR OTHER USERS (for transfer scenarios)
other_user_properties AS (
    INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, unit_of_issue, condition_code, category, manufacturer, security_classification, created_at, updated_at)
    VALUES
        -- James (Armorer) has spare weapons
        ('M4 Carbine', 'MC-1002', 'M4 Carbine, 5.56mm rifle - spare from arms room', 'active', 'serviceable', 
         (SELECT id FROM users WHERE email = 'james.thompson@example.mil'), 
         '1005-01-231-0973', 'Arms Room - Rack 5B', 3200.00, 1, 'EA', 'A', 'WEAPON', 'Colt Defense LLC', 'FOUO', NOW() - INTERVAL '60 days', NOW()),
        
        -- Maria (Motor Pool) has vehicle equipment
        ('Vehicle Tool Kit', 'VTK-3301', 'Vehicle maintenance tool kit', 'active', 'serviceable',
         (SELECT id FROM users WHERE email = 'maria.garcia@example.mil'),
         '5180-01-378-9573', 'Motor Pool Storage', 450.00, 1, 'BX', 'A', 'TOOL', 'Craftsman', 'U', NOW() - INTERVAL '90 days', NOW()),
        
        -- Charles (Comms) has radio equipment
        ('Spare Radio Battery', 'BAT-7788', 'Rechargeable battery for AN/PRC-152', 'active', 'serviceable',
         (SELECT id FROM users WHERE email = 'charles.wilson@example.mil'),
         '6140-01-492-2061', 'Comms Shop', 125.00, 6, 'EA', 'A', 'COMMS', 'Bren-Tronics', 'U', NOW() - INTERVAL '30 days', NOW())
    ON CONFLICT (serial_number) DO NOTHING
),

-- 5. CREATE PROPERTY COMPONENTS AND ASSOCIATIONS
component_associations AS (
    -- First, add some component items
    INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, nsn, location, unit_price, quantity, unit_of_issue, condition_code, category, is_component, created_at, updated_at)
    VALUES
        -- ACOG Scope for M4
        ('ACOG Scope', 'ACOG-5521', '4x32 ACOG Rifle Scope', 'active', 'serviceable',
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         '1240-01-412-6608', 'With parent item', 1200.00, 1, 'EA', 'A', 'OPTICS', true, NOW() - INTERVAL '90 days', NOW()),
        
        -- Radio Antenna
        ('VHF Antenna', 'ANT-3345', 'Flexible VHF antenna for AN/PRC-152', 'active', 'serviceable',
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         '5985-01-480-8955', 'With parent item', 75.00, 1, 'EA', 'A', 'COMMS', true, NOW() - INTERVAL '90 days', NOW())
    ON CONFLICT (serial_number) DO NOTHING
    RETURNING id, serial_number
),

-- Create parent-child relationships
property_components_data AS (
    INSERT INTO property_components (parent_property_id, component_property_id, attached_at, attached_by_user_id)
    SELECT 
        p.id as parent_id,
        c.id as component_id,
        NOW() - INTERVAL '30 days',
        (SELECT id FROM users WHERE email = 'john.smith@example.mil')
    FROM properties p
    CROSS JOIN properties c
    WHERE p.serial_number = 'MC-1001' AND c.serial_number = 'ACOG-5521'
    
    UNION ALL
    
    SELECT 
        p.id as parent_id,
        c.id as component_id,
        NOW() - INTERVAL '7 days',
        (SELECT id FROM users WHERE email = 'john.smith@example.mil')
    FROM properties p
    CROSS JOIN properties c
    WHERE p.serial_number = 'RAD-4590' AND c.serial_number = 'ANT-3345'
    
    ON CONFLICT DO NOTHING
),

-- Log component events
component_events_data AS (
    INSERT INTO component_events (component_property_id, parent_property_id, event_type, event_date, user_id, notes)
    SELECT 
        c.id,
        p.id,
        'attached',
        NOW() - INTERVAL '30 days',
        (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
        'ACOG scope mounted on M4 Carbine for qualification'
    FROM properties p
    CROSS JOIN properties c
    WHERE p.serial_number = 'MC-1001' AND c.serial_number = 'ACOG-5521'
    
    UNION ALL
    
    SELECT 
        c.id,
        p.id,
        'attached',
        NOW() - INTERVAL '7 days',
        (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
        'Replaced damaged antenna on radio'
    FROM properties p
    CROSS JOIN properties c
    WHERE p.serial_number = 'RAD-4590' AND c.serial_number = 'ANT-3345'
),

-- 6. CREATE DIVERSE DOCUMENT TYPES
diverse_documents AS (
    INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, attachments, status, sent_at, read_at, created_at, updated_at)
    
    -- DA Form 2404 - Equipment Inspection (from Motor Pool supervisor)
    SELECT 
        'maintenance_form',
        'DA2404',
        'Equipment Inspection - ' || p.name,
        (SELECT id FROM users WHERE email = 'maria.garcia@example.mil'),
        (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
        p.id,
        jsonb_build_object(
            'formType', 'DA Form 2404',
            'inspectionType', 'Quarterly Service',
            'deficiencies', jsonb_build_array(
                jsonb_build_object(
                    'item', 'Transmission fluid',
                    'status', 'Low',
                    'action', 'Top off and monitor'
                ),
                jsonb_build_object(
                    'item', 'Front tires',
                    'status', 'Worn',
                    'action', 'Schedule replacement within 30 days'
                )
            ),
            'nextServiceDue', (NOW() + INTERVAL '90 days')::date::text,
            'inspectedBy', 'SFC Maria Garcia',
            'date', (NOW() - INTERVAL '5 days')::date::text
        ),
        jsonb_build_array(
            jsonb_build_object(
                'url', 'https://storage.example.mil/photos/hmmwv-inspection-001.jpg',
                'type', 'image/jpeg',
                'description', 'Front tire wear pattern'
            )
        ),
        'unread',
        NOW() - INTERVAL '5 days',
        NULL,
        NOW() - INTERVAL '5 days',
        NOW()
    FROM properties p
    WHERE p.serial_number = 'HV-7731'
    
    UNION ALL
    
    -- DA Form 5988-E - Maintenance Request (from Charles for radio)
    SELECT 
        'maintenance_form',
        'DA5988E',
        'Maintenance Request - ' || p.name,
        (SELECT id FROM users WHERE email = 'charles.wilson@example.mil'),
        (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
        p.id,
        jsonb_build_object(
            'formType', 'DA Form 5988-E',
            'fault', 'Radio intermittently loses signal strength',
            'priority', 'Routine',
            'requestedWork', 'Diagnose and repair signal loss issue. Check antenna connections and internal boards.',
            'operatorName', 'SSG John Smith',
            'supervisorName', 'SGT Charles Wilson',
            'date', (NOW() - INTERVAL '3 days')::date::text
        ),
        '[]'::jsonb,
        'read',
        NOW() - INTERVAL '3 days',
        NOW() - INTERVAL '2 days',
        NOW() - INTERVAL '3 days',
        NOW()
    FROM properties p
    WHERE p.serial_number = 'RAD-4590'
    
    UNION ALL
    
    -- Property Transfer Receipt (from Patricia - Platoon Sergeant)
    SELECT 
        'transfer_form',
        'DA3161',
        'Request for Issue or Turn-In',
        (SELECT id FROM users WHERE email = 'patricia.anderson@example.mil'),
        (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
        NULL,
        jsonb_build_object(
            'formType', 'DA Form 3161',
            'requestType', 'Issue',
            'items', jsonb_build_array(
                jsonb_build_object(
                    'description', 'Cleaning Kit, Small Arms',
                    'nsn', '1005-01-425-8095',
                    'quantity', 2,
                    'unit', 'EA'
                )
            ),
            'justification', 'Required for squad weapon maintenance',
            'requestedBy', 'SFC Patricia Anderson',
            'approvedBy', 'CPT Sarah Williams',
            'date', (NOW() - INTERVAL '10 days')::date::text
        ),
        '[]'::jsonb,
        'archived',
        NOW() - INTERVAL '10 days',
        NOW() - INTERVAL '10 days',
        NOW() - INTERVAL '10 days',
        NOW()
    
    ON CONFLICT DO NOTHING
),

-- 7. CREATE TRANSFER OFFERS
transfer_offers_data AS (
    -- James (Armorer) offering spare M4 to multiple people including John
    INSERT INTO transfer_offers (property_id, offering_user_id, offer_status, notes, expires_at, created_at)
    VALUES (
        (SELECT id FROM properties WHERE serial_number = 'MC-1002'),
        (SELECT id FROM users WHERE email = 'james.thompson@example.mil'),
        'active',
        'Spare M4 available from turn-in. Excellent condition, recently serviced. Priority to squad leaders.',
        NOW() + INTERVAL '7 days',
        NOW() - INTERVAL '2 days'
    )
    RETURNING id
),

offer_recipients_1 AS (
    INSERT INTO transfer_offer_recipients (transfer_offer_id, recipient_user_id, notified_at, viewed_at)
    SELECT 
        tof.id,
        u.id,
        NOW() - INTERVAL '2 days',
        CASE 
            WHEN u.email = 'john.smith@example.mil' THEN NOW() - INTERVAL '1 day'
            ELSE NULL
        END
    FROM transfer_offers_data tof
    CROSS JOIN users u
    WHERE u.email IN ('john.smith@example.mil', 'patricia.anderson@example.mil', 'robert.brown@example.mil')
),

-- Maria offering vehicle tool kit
transfer_offers_data_2 AS (
    INSERT INTO transfer_offers (property_id, offering_user_id, offer_status, notes, expires_at, created_at)
    VALUES (
        (SELECT id FROM properties WHERE serial_number = 'VTK-3301'),
        (SELECT id FROM users WHERE email = 'maria.garcia@example.mil'),
        'active',
        'Extra vehicle tool kit available. Includes all standard tools plus diagnostic equipment.',
        NOW() + INTERVAL '3 days',
        NOW() - INTERVAL '1 day'
    )
    RETURNING id
),

offer_recipients_2 AS (
    INSERT INTO transfer_offer_recipients (transfer_offer_id, recipient_user_id, notified_at)
    SELECT 
        tof.id,
        (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
        NOW() - INTERVAL '1 day'
    FROM transfer_offers_data_2 tof
),

-- Expired offer example
expired_offer AS (
    INSERT INTO transfer_offers (property_id, offering_user_id, offer_status, notes, expires_at, created_at)
    VALUES (
        (SELECT id FROM properties WHERE serial_number = 'BAT-7788'),
        (SELECT id FROM users WHERE email = 'charles.wilson@example.mil'),
        'expired',
        'Spare radio batteries available for upcoming FTX.',
        NOW() - INTERVAL '1 day',
        NOW() - INTERVAL '8 days'
    )
    RETURNING id
),

-- 8. ADD COMPREHENSIVE ACTIVITY LOGS
activities_data AS (
    INSERT INTO activities (type, description, user_id, related_property_id, related_transfer_id, metadata, timestamp)
    SELECT * FROM (
        VALUES
        -- Login/logout events
        ('user_login', 'Logged in from mobile device', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         NULL, NULL, 
         '{"ip": "10.0.1.45", "device": "iPhone 14", "app_version": "2.1.0"}'::jsonb,
         NOW() - INTERVAL '6 hours'),
         
        ('user_logout', 'Session timeout', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         NULL, NULL, 
         '{"reason": "inactivity", "session_duration": "45 minutes"}'::jsonb,
         NOW() - INTERVAL '2 hours'),
         
        -- Property updates
        ('property_updated', 'Updated location of M4 Carbine', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         (SELECT id FROM properties WHERE serial_number = 'MC-1001'), 
         NULL,
         '{"old_location": "Arms Room - Rack 3A", "new_location": "Personal Locker - B Company"}'::jsonb,
         NOW() - INTERVAL '12 hours'),
         
        -- Transfer activities
        ('transfer_initiated', 'Requested M4 Carbine from arms room', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         (SELECT id FROM properties WHERE serial_number = 'MC-1002'), 
         NULL,
         '{"offer_id": 1, "method": "offer_acceptance"}'::jsonb,
         NOW() - INTERVAL '1 day'),
         
        -- Document activities
        ('document_read', 'Viewed maintenance form for HMMWV', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         (SELECT id FROM properties WHERE serial_number = 'HV-7731'), 
         NULL,
         '{"document_type": "DA2404", "time_spent": "3 minutes"}'::jsonb,
         NOW() - INTERVAL '4 days'),
         
        -- Connection activities
        ('connection_accepted', 'Connected with SSG James Thompson', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         NULL, NULL,
         '{"connected_user": "james.thompson@example.mil", "role": "Unit Armorer"}'::jsonb,
         NOW() - INTERVAL '30 days'),
         
        ('connection_request', 'Sent connection request to 1LT Kevin Martinez', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         NULL, NULL,
         '{"requested_user": "kevin.martinez@example.mil", "message": "Requesting connection for property coordination"}'::jsonb,
         NOW() - INTERVAL '2 days'),
         
        -- Inventory activities
        ('inventory_check', 'Completed monthly sensitive items inventory', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         NULL, NULL,
         '{"items_checked": 6, "discrepancies": 0, "duration": "25 minutes"}'::jsonb,
         NOW() - INTERVAL '7 days'),
         
        -- Component activities
        ('component_attached', 'Attached ACOG scope to M4 Carbine', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'), 
         (SELECT id FROM properties WHERE serial_number = 'MC-1001'), 
         NULL,
         '{"component": "ACOG-5521", "reason": "Preparation for qualification range"}'::jsonb,
         NOW() - INTERVAL '30 days')
    ) AS t(type, description, user_id, related_property_id, related_transfer_id, metadata, timestamp)
    ON CONFLICT DO NOTHING
),

-- 9. ADD PROPERTY CONDITION HISTORY
condition_history AS (
    INSERT INTO property_condition_history (property_id, previous_condition, new_condition, changed_by, changed_at, reason, notes)
    VALUES
        -- NVG condition degradation
        ((SELECT id FROM properties WHERE serial_number = 'NVG-2025'), 
         'A', 'C', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         NOW() - INTERVAL '30 days',
         'Damage during training',
         'Lens cracked during night land navigation exercise. Item coded as unserviceable pending disposition instructions.'),
         
        -- Radio sent for repair
        ((SELECT id FROM properties WHERE serial_number = 'RAD-4590'), 
         'A', 'B', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         NOW() - INTERVAL '7 days',
         'Maintenance required',
         'Intermittent signal loss reported. Sent to comms shop for diagnosis and repair.')
),

-- 10. ADD ATTACHMENTS FOR PROPERTIES
property_attachments AS (
    INSERT INTO attachments (property_id, file_url, file_type, description, uploaded_by_user_id, created_at)
    VALUES
        -- HMMWV photos
        ((SELECT id FROM properties WHERE serial_number = 'HV-7731'),
         'https://storage.example.mil/attachments/hmmwv-7731-front.jpg',
         'image/jpeg',
         'Front view showing general condition',
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         NOW() - INTERVAL '14 days'),
         
        ((SELECT id FROM properties WHERE serial_number = 'HV-7731'),
         'https://storage.example.mil/attachments/hmmwv-7731-damage.jpg',
         'image/jpeg',
         'Transmission leak documentation',
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         NOW() - INTERVAL '3 days'),
         
        -- M9 Pistol damage documentation
        ((SELECT id FROM properties WHERE serial_number = 'PX-1145'),
         'https://storage.example.mil/attachments/m9-1145-barrel.jpg',
         'image/jpeg',
         'Barrel damage - close up view',
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         NOW() - INTERVAL '5 days'),
         
        -- Tool kit inventory sheet
        ((SELECT id FROM properties WHERE serial_number = 'TK-8420'),
         'https://storage.example.mil/attachments/toolkit-8420-inventory.pdf',
         'application/pdf',
         'Last known inventory before loss',
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         NOW() - INTERVAL '14 days')
),

-- 11. ADD DA2062 SIGNATURES FOR COMPLETED TRANSFERS
da2062_signatures_data AS (
    INSERT INTO da2062_signatures (
        document_id, 
        from_user_id, 
        to_user_id, 
        from_signature_url, 
        to_signature_url, 
        signature_metadata,
        signed_at
    )
    SELECT 
        d.id,
        d.sender_user_id,
        d.recipient_user_id,
        'https://storage.example.mil/signatures/sig-' || d.sender_user_id || '-' || d.id || '.png',
        'https://storage.example.mil/signatures/sig-' || d.recipient_user_id || '-' || d.id || '.png',
        jsonb_build_object(
            'from', jsonb_build_object(
                'angle', -45,
                'x', 10,
                'y', 240,
                'width', 80,
                'height', 20,
                'applied_at', (d.sent_at + INTERVAL '1 hour')::text
            ),
            'to', jsonb_build_object(
                'angle', -45,
                'x', 110,
                'y', 240,
                'width', 80,
                'height', 20,
                'applied_at', (d.sent_at + INTERVAL '2 hours')::text
            )
        ),
        d.sent_at + INTERVAL '2 hours'
    FROM documents d
    WHERE d.type = 'transfer_form' 
      AND d.subtype = 'DA2062'
      AND d.status = 'archived'
      AND d.recipient_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')
    LIMIT 2
),

-- 12. UPDATE DOCUMENT SIGNATURE STATUS
update_document_signatures AS (
    UPDATE documents
    SET signature_status = 'signed',
        signature_data = jsonb_build_object(
            'signed', true,
            'signature_date', NOW() - INTERVAL '10 days',
            'signature_method', 'digital'
        )
    WHERE type = 'transfer_form' 
      AND status = 'archived'
      AND recipient_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')
),

-- 13. ADD OFFLINE SYNC QUEUE ENTRIES (simulating mobile app pending changes)
offline_sync_data AS (
    INSERT INTO offline_sync_queue (device_id, user_id, operation_type, entity_type, entity_id, data, created_at, retry_count)
    VALUES
        ('iPhone-14-UDID-12345', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         'update',
         'property',
         (SELECT id FROM properties WHERE serial_number = 'MC-1001'),
         '{"location": "Field - Training Area 12", "notes": "Deployed for FTX OPERATION THUNDER"}'::jsonb,
         NOW() - INTERVAL '4 hours',
         0),
         
        ('iPhone-14-UDID-12345', 
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         'create',
         'activity',
         NULL,
         '{"type": "inventory_check", "description": "Field inventory completed", "metadata": {"location": "FOB Lightning", "items_present": 6}}'::jsonb,
         NOW() - INTERVAL '2 hours',
         1)
),

-- 14. CREATE HISTORICAL TRANSFERS (showing chain of custody)
historical_transfers AS (
    INSERT INTO transfers (property_id, from_user_id, to_user_id, status, transfer_type, initiator_id, request_date, resolved_date, notes, created_at, updated_at)
    VALUES
        -- M4 Carbine history: Supply -> Michael -> John
        ((SELECT id FROM properties WHERE serial_number = 'MC-1001'),
         NULL,
         (SELECT id FROM users WHERE email = 'michael.johnson@example.mil'),
         'accepted',
         'offer',
         (SELECT id FROM users WHERE email = 'admin@handreceipt.com'),
         NOW() - INTERVAL '180 days',
         NOW() - INTERVAL '180 days',
         'Initial issue from supply',
         NOW() - INTERVAL '180 days',
         NOW()),
         
        -- NVG history: previous user -> John
        ((SELECT id FROM properties WHERE serial_number = 'NVG-2025'),
         (SELECT id FROM users WHERE email = 'david.miller@example.mil'),
         (SELECT id FROM users WHERE email = 'john.smith@example.mil'),
         'accepted',
         'offer',
         (SELECT id FROM users WHERE email = 'david.miller@example.mil'),
         NOW() - INTERVAL '60 days',
         NOW() - INTERVAL '59 days',
         'Transfer due to PCS move',
         NOW() - INTERVAL '59 days',
         NOW())
),

-- 15. ADD CATALOG UPDATE ENTRY
catalog_update AS (
    INSERT INTO catalog_updates (update_source, update_date, items_added, items_updated, items_removed, notes)
    VALUES
        ('PUBLOG', NOW() - INTERVAL '30 days', 125, 3420, 18, 'Quarterly PUBLOG data refresh completed successfully'),
        ('MANUAL', NOW() - INTERVAL '7 days', 3, 0, 0, 'Added local unit-specific items not in PUBLOG')
)

SELECT 
    'Enhanced demo data created successfully' as status,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM user_connections WHERE user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil') OR connected_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')) as john_connections,
    (SELECT COUNT(*) FROM properties WHERE assigned_to_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')) as john_properties,
    (SELECT COUNT(*) FROM documents WHERE recipient_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')) as john_documents,
    (SELECT COUNT(*) FROM activities WHERE user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil')) as john_activities,
    (SELECT COUNT(*) FROM transfer_offers WHERE id IN (SELECT transfer_offer_id FROM transfer_offer_recipients WHERE recipient_user_id = (SELECT id FROM users WHERE email = 'john.smith@example.mil'))) as john_offers;

COMMIT;

-- Summary of enhancements:
-- ✅ Added 7 new users with realistic military roles
-- ✅ Created diverse connection network (accepted, pending, blocked)
-- ✅ Enhanced all properties with DA2062 fields (unit_of_issue, condition_code, category, etc.)
-- ✅ Added property components and parent-child relationships
-- ✅ Created diverse document types (DA2404, DA5988E, DA3161) with attachments
-- ✅ Added active, expired, and accepted transfer offers
-- ✅ Created comprehensive activity logs showing various user actions
-- ✅ Added property condition history tracking
-- ✅ Included property photo/document attachments
-- ✅ Added digital signatures for completed transfers
-- ✅ Simulated offline sync queue entries
-- ✅ Created historical transfer records showing chain of custody
-- ✅ Added catalog update entries

-- This creates a rich, realistic demo environment showcasing all active features