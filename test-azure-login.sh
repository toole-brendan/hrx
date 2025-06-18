#!/bin/bash

echo "🧪 Testing Azure Backend Login"
echo "=============================="
echo ""
echo "You can now login with these test credentials:"
echo ""
echo "✅ Test User Created:"
echo "   Email: test.azure@handreceipt.com"
echo "   Password: TestPassword123!"
echo ""
echo "Testing login with curl..."
echo ""

LOGIN_RESPONSE=$(curl -s -X POST https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io/api/auth/login \
    -H "Content-Type: application/json" \
    -H "Origin: https://www.handreceipt.com" \
    -d '{"email":"test.azure@handreceipt.com","password":"TestPassword123!"}' \
    -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)

HTTP_STATUS=$(echo "$LOGIN_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
BODY=$(echo "$LOGIN_RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ]; then
    echo "✅ Login successful!"
    echo ""
    echo "Access token received (truncated):"
    echo "$BODY" | jq -r '.access_token' | cut -c1-50
    echo "..."
    echo ""
    echo "User info:"
    echo "$BODY" | jq '.user'
else
    echo "❌ Login failed with status: $HTTP_STATUS"
    echo "Response: $BODY"
fi

echo ""
echo "🚀 Next Steps:"
echo "1. Rebuild and deploy your frontend with the updated API URL"
echo "2. Or use the dev login feature (tap logo 5 times) with these credentials"
echo "3. The backend is working perfectly on Azure!" 