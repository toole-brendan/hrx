#!/bin/bash

# Commands to check the HandReceipt database on AWS Lightsail
# Run these after SSH'ing into your Lightsail instance

echo "=== Checking HandReceipt Database on Lightsail ==="
echo ""

# 1. First SSH into your Lightsail instance:
echo "Step 1: SSH into Lightsail (run this locally):"
echo "ssh -i ~/.ssh/your-lightsail-key.pem ubuntu@44.193.254.155"
echo ""

echo "Step 2: Once connected, navigate to the HandReceipt directory:"
echo "cd /opt/handreceipt"
echo ""

echo "Step 3: Connect to the PostgreSQL database in Docker:"
echo "sudo docker-compose exec postgres psql -U handreceipt -d handreceipt"
echo ""

echo "Step 4: Run these commands in psql to check the database:"
cat << 'EOF'

-- List all tables
\dt

-- Check table counts
SELECT 
    'users' as table_name, COUNT(*) as count FROM users
UNION ALL
    SELECT 'properties', COUNT(*) FROM properties
UNION ALL
    SELECT 'transfers', COUNT(*) FROM transfers
UNION ALL
    SELECT 'transfer_items', COUNT(*) FROM transfer_items
UNION ALL
    SELECT 'activities', COUNT(*) FROM activities
UNION ALL
    SELECT 'nsn_records', COUNT(*) FROM nsn_records
UNION ALL
    SELECT 'user_connections', COUNT(*) FROM user_connections
UNION ALL
    SELECT 'transfer_offers', COUNT(*) FROM transfer_offers
UNION ALL
    SELECT 'da2062_imports', COUNT(*) FROM da2062_imports
UNION ALL
    SELECT 'catalog_updates', COUNT(*) FROM catalog_updates
UNION ALL
    SELECT 'attachments', COUNT(*) FROM attachments;

-- Check users table structure
\d users

-- Check properties table structure
\d properties

-- Check if there are any users
SELECT id, username, email, first_name, last_name, rank, unit FROM users;

-- Check if NSN records were loaded
SELECT COUNT(*) as nsn_count FROM nsn_records;
SELECT * FROM nsn_records LIMIT 5;

-- Exit psql
\q

EOF

echo ""
echo "Alternative: Run all checks in one command from your local machine:"
echo 'ssh -i ~/.ssh/your-lightsail-key.pem ubuntu@44.193.254.155 "cd /opt/handreceipt && sudo docker-compose exec -T postgres psql -U handreceipt -d handreceipt -c \"SELECT tablename FROM pg_tables WHERE schemaname = '"'"'public'"'"' ORDER BY tablename;\""' 