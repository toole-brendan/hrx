#!/bin/bash

echo "🔍 Checking test user in database"
echo "================================="

# Check if we're on the Lightsail instance
if [ ! -d "/opt/handreceipt" ]; then
    echo "❌ This script should be run on the Lightsail instance"
    echo "   SSH to your server first: ssh -i your-key.pem ubuntu@44.193.254.155"
    exit 1
fi

cd /opt/handreceipt/deployments/lightsail

echo -e "\n1️⃣ Checking database connection..."
if sudo docker-compose exec postgres pg_isready -U handreceipt -d handreceipt > /dev/null 2>&1; then
    echo "   ✅ Database is ready"
else
    echo "   ❌ Database is not ready"
    exit 1
fi

echo -e "\n2️⃣ Looking for test users..."
echo "   Checking for michael.rodriguez@example.com..."
TEST_USER=$(sudo docker-compose exec postgres psql -U handreceipt -d handreceipt -t -c "SELECT email, first_name, last_name FROM users WHERE email = 'michael.rodriguez@example.com';" 2>/dev/null)

if [ -n "$TEST_USER" ]; then
    echo "   ✅ Found: $TEST_USER"
else
    echo "   ❌ User not found"
    echo ""
    echo "   Creating test user..."
    
    # Create test user with known password
    sudo docker-compose exec postgres psql -U handreceipt -d handreceipt << 'SQL_EOF'
-- Create test user with password 'password123'
INSERT INTO users (email, password_hash, first_name, last_name, rank, unit, status, created_at, updated_at)
VALUES (
    'michael.rodriguez@example.com',
    '$2a$10$YourHashHere',  -- This is a placeholder, we'll update it
    'Michael',
    'Rodriguez',
    'CPT',
    'Test Unit',
    'active',
    NOW(),
    NOW()
) ON CONFLICT (email) DO NOTHING;
SQL_EOF

    echo "   Note: You'll need to create this user through the registration API"
fi

echo -e "\n3️⃣ Listing all users in database:"
echo "   Email                              | Name"
echo "   -----------------------------------|------------------------"
sudo docker-compose exec postgres psql -U handreceipt -d handreceipt -t -c "SELECT RPAD(email, 35, ' ') || '| ' || first_name || ' ' || last_name FROM users ORDER BY created_at DESC LIMIT 10;" 2>/dev/null | sed 's/^/   /'

echo -e "\n4️⃣ Creating a proper test user via API..."
echo "   Registering test user via the API..."

REGISTER_RESPONSE=$(curl -s -X POST https://api.handreceipt.com/api/auth/register \
    -H "Content-Type: application/json" \
    -d '{
        "email": "test.user@handreceipt.com",
        "password": "TestPassword123!",
        "first_name": "Test",
        "last_name": "User",
        "rank": "PVT",
        "unit": "Test Unit"
    }' \
    -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)

REG_STATUS=$(echo "$REGISTER_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
REG_BODY=$(echo "$REGISTER_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$REG_STATUS" == "200" ] || [ "$REG_STATUS" == "201" ]; then
    echo "   ✅ Test user created successfully!"
    echo "   Email: test.user@handreceipt.com"
    echo "   Password: TestPassword123!"
elif echo "$REG_BODY" | grep -q "already exists"; then
    echo "   ℹ️  Test user already exists"
    echo "   Email: test.user@handreceipt.com"
    echo "   Password: TestPassword123!"
else
    echo "   ❌ Failed to create test user"
    echo "   Status: $REG_STATUS"
    echo "   Response: $REG_BODY"
fi

echo -e "\n📋 Summary:"
echo "   You can now test login with:"
echo "   - Email: test.user@handreceipt.com"
echo "   - Password: TestPassword123!"
echo ""
echo "   Or use the Dev Login feature (tap logo 5 times)" 