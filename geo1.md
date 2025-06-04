Thanks! I’ll take a look through your iOS application to get a sense of its features, and also review the `handreceipt/sql` directory to understand the schema and identify opportunities for mock data insertion. I’ll then create a SQL migration script that populates your test account (`toole.brendan@gmail.com`) with representative mock data across all features.

I’ll let you know when the mock data migration is ready for your review.


# SQL Migration to Seed Test User Data Across All Features

To populate the **test account** (Brendan Toole) with comprehensive mock data, we will insert sample records for every major feature of the HandReceipt application. This includes creating additional users (for connections and transfers), inventory properties assigned to the test user, transfer records (completed, pending, and even a rejected example), a document (digital hand receipt form), and network connections. Below, we outline the approach and then provide the SQL migration script.

## Approach Overview

* **Test User and Peers:** Ensure the test user (`toole.brendan`) exists, then create a few **peer users** to simulate connections and transfers. We’ll assign realistic names, ranks, and use a default password hash (e.g. bcrypt of "password123") for these users. All new users will have role `user` by default and status `active`.
* **Inventory Properties:** Populate the test user’s **Property Book** with several items (weapons, optics, radios, etc.), using the schema defined in the `properties` table. We will vary their `current_status` to showcase different conditions:

  * *Active/Assigned Items:* e.g. an M4 Carbine rifle, Night Vision Goggles – these appear as operational gear.
  * *Maintenance Item:* an item marked with `current_status = 'maintenance'` (and condition `needs_repair`) to appear under “In Maintenance” on the dashboard.
  * *Lost Item:* an item marked `current_status = 'lost'` to count as non-operational.
  * Each item will be assigned to the test user via `assigned_to_user_id`, except items still held by other users (for pending transfers).
  * We’ll also set a **photo URL** on one item to test image display (the app shows an “Add Photo” prompt if none). For example, the Night Vision device can have a placeholder image URL in its `photo_url` field.
* **Transfers (Hand Receipts):** Create records in the `transfers` table to simulate:

  * *Completed incoming transfers:* gear that the test user received from others (e.g. an M4 from a supply NCO, NVGs from another unit). These will have `status = 'completed'` and include a `from_user_id` (the giver) and `to_user_id` (the test user). We use realistic timestamps in `request_date` and `resolved_date` to place these events in the past.
  * *Pending incoming transfer:* an offer awaiting the test user’s acceptance (e.g. a crew-served weapon offered by the supply NCO). This will have `status = 'pending'` and a recent `request_date` (no `resolved_date` yet).
  * *Pending outgoing transfer:* an item the test user is loaning out to a friend (e.g. a spare radio) with `status = 'pending'`. The item remains assigned to the test user until accepted, so it stays in their inventory during the pending state.
  * *Rejected transfer:* an example where a request was **denied**. We simulate the test user requesting an item from another user who rejects it (marked `status = 'rejected'` with a `resolved_date` and note). This populates the “Recent Activity” feed with a rejected event.
  * **Note:** We omit the `transfer_type` and `initiator_id` fields in inserts – the schema defaults `transfer_type` to "offer", and these details aren’t critical for basic UI display.
* **User Connections:** Establish **social network links** in the `user_connections` table:

  * Accepted connections between the test user and each peer user (so they appear in the test user’s network list). We insert one row per connection with `connection_status = 'accepted'`.
  * A pending connection request from a new user to the test user (`connection_status = 'pending'`) to surface an inbound request notification. In the dashboard, `pendingConnectionRequests` will reflect this.
* **Documents (Maintenance/Transfer Forms):** Insert a record into the `documents` table to simulate an **unread document** in the test user’s inbox. For example, after the test user received the M4, the supply NCO sends a digital DA-2062 **transfer form** for them to sign:

  * `type = 'transfer_form'` (subtype "DA2062"), with `sender_user_id` as the supply NCO and `recipient_user_id` as the test user.
  * We include a JSON payload in `form_data` (e.g. basic form info) and mark `status = 'unread'`. This will trigger the “Documents Inbox” card on the dashboard (since `unreadCount > 0`).
  * (If needed, maintenance forms could also be represented similarly with `type = 'maintenance_form'`, but here we focus on a transfer form for brevity.)

Using the above strategy, the SQL migration below inserts the mock data. It uses **`ON CONFLICT ... DO NOTHING`** for idempotency (so running it won’t duplicate entries if they already exist). Make sure to run this against the same database the app uses (e.g. development or test environment).

## SQL Migration Script

```sql
-- 1. Ensure the test user exists (Brendan Toole) and create peer accounts
INSERT INTO users (username, email, password, name, rank)
VALUES 
    ('toole.brendan', 'toole.brendan@gmail.com', 
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',  -- bcrypt hash for "password123"
     'Brendan Toole', 'SPC'),   -- Specialist rank for example
    ('john.doe', 'john.doe@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',
     'John Doe', 'SFC'),       -- John Doe (Supply NCO, Sergeant First Class)
    ('sarah.thompson', 'sarah.thompson@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',
     'Sarah Thompson', '1LT'), -- Sarah Thompson (Platoon Leader, 1st Lieutenant)
    ('james.wilson', 'james.wilson@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',
     'James Wilson', 'SSG'),   -- James Wilson (Squad Leader, Staff Sergeant)
    ('alice.smith', 'alice.smith@example.mil',
     '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6',
     'Alice Smith', 'CPT')     -- Alice Smith (Company Commander, Captain)
ON CONFLICT (username) DO NOTHING;

-- 2. Establish user connections (network)
-- Accepted connections: Test user <-> John, Sarah, James
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
VALUES 
    ((SELECT id FROM users WHERE username = 'toole.brendan'),
     (SELECT id FROM users WHERE username = 'john.doe'),
     'accepted', NOW()),
    ((SELECT id FROM users WHERE username = 'toole.brendan'),
     (SELECT id FROM users WHERE username = 'sarah.thompson'),
     'accepted', NOW()),
    ((SELECT id FROM users WHERE username = 'toole.brendan'),
     (SELECT id FROM users WHERE username = 'james.wilson'),
     'accepted', NOW())
ON CONFLICT DO NOTHING;

-- Pending connection: Alice Smith -> Brendan (Alice sent request that Brendan has not accepted yet)
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
VALUES (
    (SELECT id FROM users WHERE username = 'alice.smith'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'pending', NOW()
) ON CONFLICT DO NOTHING;

-- 3. Insert properties (inventory items)
-- Two M4 carbines for the test user: one active, one undergoing maintenance
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, photo_url, created_at)
VALUES 
    ('M4 Carbine', 'M4-2025-000001',
     'M4 Carbine, 5.56mm rifle (NSN 1005-01-231-0973)', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     NULL, NOW()),
    ('M4 Carbine', 'M4-2025-000002',
     'M4 Carbine, 5.56mm rifle - undergoing repairs', 
     'maintenance', 'needs_repair',     -- Mark this one as in maintenance:contentReference[oaicite:20]{index=20}:contentReference[oaicite:21]{index=21}
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     NULL, NOW())
ON CONFLICT (serial_number) DO NOTHING;

-- Night Vision Goggles assigned to the test user (received from Sarah)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, photo_url, created_at)
VALUES (
    'AN/PVS-14 Night Vision', 'NVG-2025-000001',
    'AN/PVS-14 Night Vision Monocular (NSN 5855-01-534-5931)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'https://via.placeholder.com/400x300.png?text=Night+Vision',  -- sample image URL:contentReference[oaicite:22]{index=22}
    NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- Two PRC-152A Radios for the test user (one will be loaned out)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, created_at)
VALUES 
    ('AN/PRC-152A Radio', 'RADIO-2025-000001',
     'AN/PRC-152A Multiband Radio (NSN 5820-01-451-8250)', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     NOW()),
    ('AN/PRC-152A Radio', 'RADIO-2025-000002',
     'AN/PRC-152A Multiband Radio (NSN 5820-01-451-8250) - spare unit', 
     'active', 'serviceable',
     (SELECT id FROM users WHERE username = 'toole.brendan'),
     NOW())
ON CONFLICT (serial_number) DO NOTHING;

-- A field item (Lensatic Compass) that was lost by the test user (non-operational example)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, created_at)
VALUES (
    'Lensatic Compass', 'COMP-2025-000001',
    'Lensatic Compass for land navigation', 
    'lost', 'unserviceable',    -- Mark as lost/unserviceable (non-operational):contentReference[oaicite:23]{index=23}:contentReference[oaicite:24]{index=24}
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- Properties assigned to other users (for transfer scenarios):
-- Crew-served weapon (M240B Machine Gun) still assigned to John Doe (he will offer it to Brendan)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, created_at)
VALUES (
    'M240B Machine Gun', 'M240B-2025-000001',
    'M240B 7.62mm Machine Gun (NSN 1005-01-565-7445)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'john.doe'),
    NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- Enhanced Night Vision Goggle (ENVG) assigned to Sarah Thompson (Brendan requested it but it was not transferred)
INSERT INTO properties (name, serial_number, description, current_status, condition, assigned_to_user_id, created_at)
VALUES (
    'AN/PSQ-20 ENVG', 'ENVG-2025-000001',
    'AN/PSQ-20 Enhanced Night Vision Goggle (NSN 5855-01-647-6498)', 
    'active', 'serviceable',
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    NOW()
) ON CONFLICT (serial_number) DO NOTHING;

-- 4. Insert transfer records (hand receipts / property transfers)
-- Completed transfer: John Doe issued an M4 Carbine to Brendan 30 days ago (now reflected in Brendan's inventory)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'completed',
    NOW() - INTERVAL '30 days',
    NOW() - INTERVAL '30 days' + INTERVAL '2 hours',
    'Initial issue of M4 Carbine to SPC Toole'
FROM properties p
WHERE p.serial_number = 'M4-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Completed transfer: Sarah Thompson transferred AN/PVS-14 NVGs to Brendan 60 days ago
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'completed',
    NOW() - INTERVAL '60 days',
    NOW() - INTERVAL '60 days' + INTERVAL '1 hour',
    'Transfer of night vision goggles to SPC Toole for deployment'
FROM properties p
WHERE p.serial_number = 'NVG-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Pending incoming transfer: John Doe has offered Brendan a M240B (awaiting Brendan's approval)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'john.doe'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'pending',
    NOW() - INTERVAL '2 days',
    'Offer: M240B Machine Gun for temporary attachment to unit'
FROM properties p
WHERE p.serial_number = 'M240B-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'john.doe')
ON CONFLICT DO NOTHING;

-- Pending outgoing transfer: Brendan is lending a spare radio to James Wilson (awaiting James's acceptance)
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    (SELECT id FROM users WHERE username = 'james.wilson'),
    'pending',
    NOW() - INTERVAL '1 day',
    'Loan of AN/PRC-152A Radio (spare) for training exercise'
FROM properties p
WHERE p.serial_number = 'RADIO-2025-000002' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;

-- Rejected transfer: Brendan requested Sarah's ENVG 5 days ago, but Sarah rejected it 4 days ago
INSERT INTO transfers (property_id, from_user_id, to_user_id, status, request_date, resolved_date, notes)
SELECT 
    p.id,
    (SELECT id FROM users WHERE username = 'sarah.thompson'),
    (SELECT id FROM users WHERE username = 'toole.brendan'),
    'rejected',
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days',
    'Request for ENVG denied: item already assigned to another unit'
FROM properties p
WHERE p.serial_number = 'ENVG-2025-000001' 
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'sarah.thompson')
ON CONFLICT DO NOTHING;

-- 5. Insert an unread document (digital transfer form) for the M4 issue
INSERT INTO documents (type, subtype, title, sender_user_id, recipient_user_id, property_id, form_data, status, sent_at)
SELECT 
    'transfer_form', 'DA2062',
    'Hand Receipt - M4 Carbine (DA 2062)',
    (SELECT id FROM users WHERE username = 'john.doe'),        -- sender (John)
    (SELECT id FROM users WHERE username = 'toole.brendan'),   -- recipient (Brendan)
    p.id,
    -- Minimal form data JSON (could include fields like item, sender, receiver, signatures, etc.)
    '{"item":"M4 Carbine","serial":"M4-2025-000001","issuedBy":"John Doe","issuedTo":"Brendan Toole","form":"DA 2062"}'::jsonb,
    'unread',
    NOW() - INTERVAL '29 days'   -- sent one day after issue
FROM properties p
WHERE p.serial_number = 'M4-2025-000001'
  AND p.assigned_to_user_id = (SELECT id FROM users WHERE username = 'toole.brendan')
ON CONFLICT DO NOTHING;
```

**Explanation:**

* We first insert the test user and additional users (John, Sarah, James, Alice) if they don’t already exist. The `password` uses a bcrypt hash for "password123" for convenience. The `name` and `rank` fields are set for realism (email/unit can be adjusted as needed).
* Next, we create connections. John, Sarah, and James are added as **accepted connections** for Brendan (so they appear in his network). We also insert a **pending connection** from Alice to Brendan (status 'pending') – when Brendan logs in, he’ll see a pending request from Alice.
* Then we insert multiple **properties**. Most are assigned to the test user (using his user\_id). We add:

  * Two M4 Carbines: one active, one under maintenance (note the `maintenance` status and `needs_repair` condition on the second).
  * Night Vision Goggles (NVG) assigned to Brendan (with a sample `photo_url` to illustrate the image feature).
  * Two PRC-152A Radios assigned to Brendan (simulating he has a spare).
  * A Lensatic Compass marked as `lost` (to represent a non-operational item in his list).
    We also insert properties for other users where needed: a M240B machine gun still assigned to John (he hasn’t transferred it yet) and an ENVG assigned to Sarah (since Brendan’s request for it was denied, it remains with Sarah).
* After seeding items, we create **transfer records** linking these items and users:

  * John → Brendan (M4 issue) and Sarah → Brendan (NVG transfer) are marked *completed*. These will show up as past events in “Recent Activity” with status completed.
  * John → Brendan (M240B) is *pending*, awaiting Brendan’s action (it will increment the dashboard’s `pendingTransfers` count).
  * Brendan → James (Radio loan) is *pending*, awaiting James’s acceptance. This simulates Brendan sharing equipment; it remains in his inventory until accepted.
  * Sarah → Brendan (ENVG) is *rejected*, showing a request that was turned down. This populates the activity feed with a “rejected” entry and helps confirm that edge case in the UI.
    All transfers use `NOW()` with offsets to spread out the timeline (e.g. 60 days ago, 30 days ago, last week) for realism. We include explanatory `notes` on each transfer (these might appear in detail views or audit logs).
* Finally, we insert a **document** record: a *transfer\_form* (DA 2062 hand receipt) sent from John to Brendan for the M4 issuance. We mark it as `unread`, so when Brendan logs in, the dashboard will show a “Documents Inbox” card prompting him to view it. We attach a simple JSON `form_data` with key details (in a real scenario this would contain the full form fields).

With this migration applied, the test user *Brendan Toole* will log in and see a richly populated app:

* **Property Book:** multiple items listed (weapons, equipment, etc.), with various statuses (most “Operational”, one “In Maintenance”, one “Lost” contributing to the dashboard’s status breakdown). The NVG item will display a photo (from `photo_url`) instead of the placeholder “Tap to add photo” prompt.
* **Transfers/Activity:** the dashboard “Recent Activity” section will list recent transfers – e.g. the M4 and NVG transfers (completed), the pending offers, and the rejected request – each with appropriate labels/status. The *pending transfers count* on the dashboard will reflect the two pending transfers.
* **Connections:** the **Network/Connections** section will show the test user has established connections with John, Sarah, and James (3 connections), and one pending request from Alice. In the app’s connections screen, Alice would appear under pending requests awaiting approval.
* **Documents:** a **Documents Inbox** card will be visible on the dashboard (since an unread document exists). Brendan can open it to see the transfer form (DA 2062) that John sent, demonstrating the in-app PDF/document feature.

This seeded data covers **all major features** of the application – inventory management, transfers (issuing/requesting/loaning gear), maintenance status tracking, the user network, and document exchange – allowing you to observe how the app UI renders a fully populated scenario. Be sure to adjust any specific IDs or values as needed for your environment, and run the migration. Once applied, log into the iOS app with the test account to verify that all sections (Dashboard, Property list, Connections, Documents, etc.) show the expected mock data.

**Sources:**

* HandReceipt schema definitions for users, properties, connections, transfers, etc.
* Example dev seed data illustrating user and equipment inserts.
* iOS Dashboard view logic showing unread documents and pending requests counts.
* Domain and migration references for statuses (`maintenance`, `needs_repair`, etc.).
