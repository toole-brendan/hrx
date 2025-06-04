#!/bin/bash

# HandReceipt Backend Diagnostic Script for Azure Container Apps
set -e

RESOURCE_GROUP="handreceipt-prod-rg"
BACKEND_APP_NAME="handreceipt-backend"
IMMUDB_APP_NAME="immudb"

echo "🔍 Diagnosing HandReceipt Backend Issues..."

# Check if Azure CLI is logged in
if ! az account show >/dev/null 2>&1; then
    echo "❌ Please log in to Azure CLI first: az login"
    exit 1
fi

echo "✅ Azure CLI is authenticated"

# 1. Check Backend Container App Status
echo ""
echo "📊 Backend Container App Status:"
az containerapp show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{name: name, status: properties.runningStatus, replicas: properties.template.scale, fqdn: properties.configuration.ingress.fqdn}" \
    --output table

# 2. Check ImmuDB Container App Status
echo ""
echo "📊 ImmuDB Container App Status:"
az containerapp show \
    --name "$IMMUDB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{name: name, status: properties.runningStatus, replicas: properties.template.scale, fqdn: properties.configuration.ingress.fqdn}" \
    --output table

# 3. Get Backend Environment Variables
echo ""
echo "⚙️  Backend Environment Variables (ImmuDB related):"
az containerapp show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.template.containers[0].env[?contains(name, 'IMMUDB')]" \
    --output table

# 4. Get Recent Backend Logs (last 50 lines)
echo ""
echo "📋 Recent Backend Logs (last 50 lines):"
az containerapp logs show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --tail 50 || echo "Could not retrieve backend logs"

# 5. Get Recent ImmuDB Logs (last 30 lines)
echo ""
echo "📋 Recent ImmuDB Logs (last 30 lines):"
az containerapp logs show \
    --name "$IMMUDB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --tail 30 || echo "Could not retrieve ImmuDB logs"

# 6. Test Backend Health Endpoint
echo ""
echo "🔍 Testing Backend Health Endpoint:"
BACKEND_URL=$(az containerapp show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv)

if [ -n "$BACKEND_URL" ]; then
    echo "Backend URL: https://$BACKEND_URL"
    echo "Testing health endpoint..."
    
    # Test with verbose curl
    curl -v -m 10 "https://$BACKEND_URL/health" || echo "❌ Health check failed"
    
    echo ""
    echo "Testing root endpoint..."
    curl -v -m 10 "https://$BACKEND_URL/" || echo "❌ Root endpoint failed"
else
    echo "❌ Could not get backend URL"
fi

# 7. Check Container App Environment Status
echo ""
echo "📊 Container Apps Environment Status:"
az containerapp env show \
    --name "handreceipt-prod-cae" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{name: name, provisioningState: properties.provisioningState}" \
    --output table

echo ""
echo "🎯 Diagnostic Summary:"
echo "1. Check the backend logs above for specific error messages"
echo "2. Look for ImmuDB connection errors or database connection issues"
echo "3. Verify environment variables are set correctly"
echo "4. Check if both containers are in 'Running' status"
echo ""
echo "Common issues to look for:"
echo "- Database connection failures"
echo "- Missing environment variables"
echo "- ImmuDB authentication errors"
echo "- Container startup crashes"
echo "- Network connectivity issues between containers" 