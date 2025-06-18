#!/bin/bash

echo "🔍 Diagnosing HandReceipt Login Issue"
echo "====================================="

# Check if we can reach the API
echo -e "\n1️⃣ Testing API connectivity:"
echo -n "   Health check: "
if curl -s -o /dev/null -w "%{http_code}" https://api.handreceipt.com/health 2>/dev/null | grep -q "200"; then
    echo "✅ OK (200)"
else
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.handreceipt.com/health 2>/dev/null)
    echo "❌ Failed (Status: $STATUS)"
fi

# Test CORS headers
echo -e "\n2️⃣ Testing CORS headers:"
echo "   Request from https://www.handreceipt.com:"
CORS_HEADERS=$(curl -s -I -H "Origin: https://www.handreceipt.com" https://api.handreceipt.com/api/auth/me 2>/dev/null | grep -i "access-control")
if [ -n "$CORS_HEADERS" ]; then
    echo "$CORS_HEADERS" | sed 's/^/   /'
else
    echo "   ❌ No CORS headers found"
fi

# Test login endpoint
echo -e "\n3️⃣ Testing login endpoint:"
echo "   Sending test login request..."
LOGIN_RESPONSE=$(curl -s -X POST https://api.handreceipt.com/api/auth/login \
    -H "Content-Type: application/json" \
    -H "Origin: https://www.handreceipt.com" \
    -d '{"email":"test@example.com","password":"wrongpassword"}' \
    -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)

HTTP_STATUS=$(echo "$LOGIN_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
BODY=$(echo "$LOGIN_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "   Status Code: $HTTP_STATUS"
echo "   Response: $BODY"

# Check for double CORS headers
echo -e "\n4️⃣ Checking for duplicate CORS headers:"
FULL_HEADERS=$(curl -s -I -X OPTIONS -H "Origin: https://www.handreceipt.com" https://api.handreceipt.com/api/auth/login 2>/dev/null)
CORS_COUNT=$(echo "$FULL_HEADERS" | grep -i "access-control-allow-origin" | wc -l)
if [ "$CORS_COUNT" -gt 1 ]; then
    echo "   ⚠️  Found $CORS_COUNT Access-Control-Allow-Origin headers (should be 1)"
    echo "   This can cause CORS issues!"
else
    echo "   ✅ Single CORS header found"
fi

# Test with actual credentials (if provided)
if [ "$1" == "--test-login" ] && [ -n "$2" ] && [ -n "$3" ]; then
    echo -e "\n5️⃣ Testing with provided credentials:"
    LOGIN_TEST=$(curl -s -X POST https://api.handreceipt.com/api/auth/login \
        -H "Content-Type: application/json" \
        -H "Origin: https://www.handreceipt.com" \
        -d "{\"email\":\"$2\",\"password\":\"$3\"}" \
        -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)
    
    TEST_STATUS=$(echo "$LOGIN_TEST" | grep "HTTP_STATUS:" | cut -d':' -f2)
    TEST_BODY=$(echo "$LOGIN_TEST" | sed '/HTTP_STATUS:/d')
    
    echo "   Status: $TEST_STATUS"
    if [ "$TEST_STATUS" == "200" ]; then
        echo "   ✅ Login successful!"
    else
        echo "   ❌ Login failed"
        echo "   Response: $TEST_BODY"
    fi
fi

echo -e "\n📋 Summary:"
echo "   - API endpoint: https://api.handreceipt.com"
echo "   - Frontend origin: https://www.handreceipt.com"
echo "   - CORS should allow this origin"

echo -e "\n💡 Next steps:"
echo "   1. If CORS headers are missing, check nginx and backend configs"
echo "   2. If duplicate headers exist, remove nginx CORS handling"
echo "   3. Check backend logs: ssh to server and run:"
echo "      sudo docker-compose -f /opt/handreceipt/deployments/lightsail/docker-compose.yml logs app --tail=50" 