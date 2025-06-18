#!/bin/bash

echo "🔍 Diagnosing HandReceipt Azure Login/Registration Issue"
echo "======================================================="

# Azure configuration from the workflow
RESOURCE_GROUP="handreceipt-prod-rg"
BACKEND_APP_NAME="handreceipt-backend"
WORKER_APP_NAME="handreceipt-worker"
POSTGRES_SERVER="handreceipt-prod-postgres"

echo -e "\n1️⃣ Testing API connectivity:"
echo -n "   Health check: "
if curl -s -o /dev/null -w "%{http_code}" https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io/health 2>/dev/null | grep -q "200"; then
    echo "✅ OK (200)"
else
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io/health 2>/dev/null)
    echo "❌ Failed (Status: $STATUS)"
fi

echo -e "\n2️⃣ Testing CORS headers:"
echo "   Request from https://www.handreceipt.com:"
CORS_HEADERS=$(curl -s -I -H "Origin: https://www.handreceipt.com" https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io/api/auth/me 2>/dev/null | grep -i "access-control")
if [ -n "$CORS_HEADERS" ]; then
    echo "$CORS_HEADERS" | sed 's/^/   /'
else
    echo "   ❌ No CORS headers found"
fi

echo -e "\n3️⃣ Testing registration endpoint:"
REGISTER_RESPONSE=$(curl -s -X POST https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io/api/auth/register \
    -H "Content-Type: application/json" \
    -H "Origin: https://www.handreceipt.com" \
    -d '{"email":"test.azure@handreceipt.com","password":"TestPassword123!","first_name":"Test","last_name":"User","rank":"PVT","unit":"Test Unit"}' \
    -w "\nHTTP_STATUS:%{http_code}" 2>/dev/null)

HTTP_STATUS=$(echo "$REGISTER_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
BODY=$(echo "$REGISTER_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "   Status Code: $HTTP_STATUS"
echo "   Response: $BODY"

echo -e "\n📋 Azure CLI Commands to check backend:"
echo "   Make sure you're logged into Azure CLI first:"
echo "   az login"
echo ""
echo "   # Check Container App status"
echo "   az containerapp show --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP --query \"properties.runningStatus\""
echo ""
echo "   # Get recent logs"
echo "   az containerapp logs show --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP --tail 50"
echo ""
echo "   # Check environment variables"
echo "   az containerapp show --name $BACKEND_APP_NAME --resource-group $RESOURCE_GROUP --query \"properties.template.containers[0].env[]\""
echo ""
echo "   # Check PostgreSQL connection"
echo "   az postgres flexible-server show --name $POSTGRES_SERVER --resource-group $RESOURCE_GROUP" 