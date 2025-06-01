-- Development seed data for user connections (friends network)
-- This creates sample connections between existing users for testing

-- First ensure we have some test users
INSERT INTO users (username, password, name, rank, unit) 
VALUES 
    ('test.user1', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'Test User One', 'SGT', 'Alpha Company'),
    ('test.user2', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'Test User Two', 'SSG', 'Bravo Company'),
    ('test.user3', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'Test User Three', 'SFC', 'Charlie Company')
ON CONFLICT (username) DO NOTHING;

-- Create connections between existing users
-- This creates a network where each user is connected to a few others
WITH user_pairs AS (
    SELECT 
        u1.id as user1_id,
        u2.id as user2_id,
        ROW_NUMBER() OVER (ORDER BY RANDOM()) as rn
    FROM users u1
    CROSS JOIN users u2
    WHERE u1.id < u2.id  -- Avoid duplicate pairs
      AND u1.username NOT LIKE 'test.%' OR u2.username NOT LIKE 'test.%'  -- Mix test and real users
)
-- Create accepted connections
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
SELECT 
    user1_id,
    user2_id,
    'accepted',
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (rn % 30))  -- Vary creation dates
FROM user_pairs
WHERE rn <= 15  -- Limit number of connections
ON CONFLICT (user_id, connected_user_id) DO NOTHING;

-- Create reverse connections (friendships are bidirectional)
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
SELECT 
    user2_id,
    user1_id,
    'accepted',
    CURRENT_TIMESTAMP - (INTERVAL '1 day' * (rn % 30))
FROM user_pairs
WHERE rn <= 15
ON CONFLICT (user_id, connected_user_id) DO NOTHING;

-- Add some pending connection requests
WITH pending_pairs AS (
    SELECT 
        u1.id as requester_id,
        u2.id as recipient_id
    FROM users u1
    CROSS JOIN users u2
    WHERE u1.id != u2.id
      AND NOT EXISTS (
          SELECT 1 FROM user_connections uc 
          WHERE (uc.user_id = u1.id AND uc.connected_user_id = u2.id)
             OR (uc.user_id = u2.id AND uc.connected_user_id = u1.id)
      )
    ORDER BY RANDOM()
    LIMIT 5
)
INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at)
SELECT 
    requester_id,
    recipient_id,
    'pending',
    CURRENT_TIMESTAMP - (INTERVAL '1 hour' * (ROW_NUMBER() OVER ()))
FROM pending_pairs
ON CONFLICT (user_id, connected_user_id) DO NOTHING;

-- Summary query to verify connections
SELECT 
    'Total Connections' as metric,
    COUNT(*) as count
FROM user_connections
WHERE connection_status = 'accepted'
UNION ALL
SELECT 
    'Pending Requests' as metric,
    COUNT(*) as count
FROM user_connections
WHERE connection_status = 'pending'
UNION ALL
SELECT 
    'Users with Connections' as metric,
    COUNT(DISTINCT user_id) as count
FROM user_connections
WHERE connection_status = 'accepted'; 