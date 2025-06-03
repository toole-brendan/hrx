#!/bin/bash

# HandReceipt ImmuDB Connection Fix Script
# This script updates the Azure Container App environment variables to fix the ImmuDB connection issue

set -e

# Configuration
RESOURCE_GROUP="handreceipt-prod-rg"
BACKEND_APP_NAME="handreceipt-backend"

echo "🔧 Fixing ImmuDB connection for HandReceipt backend..."

# Check if Azure CLI is logged in
if ! az account show >/dev/null 2>&1; then
    echo "❌ Please log in to Azure CLI first: az login"
    exit 1
fi

echo "✅ Azure CLI is authenticated"

# Update the container app environment variables
echo "🔄 Updating container app environment variables..."

az containerapp update \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --set-env-vars \
        HANDRECEIPT_IMMUDB_HOST="immudb" \
        HANDRECEIPT_IMMUDB_PORT="3322" \
        HANDRECEIPT_IMMUDB_USERNAME="immudb" \
        HANDRECEIPT_IMMUDB_DATABASE="defaultdb" \
        HANDRECEIPT_IMMUDB_ENABLED="true"

echo "✅ Environment variables updated successfully"

# Wait for the deployment to complete
echo "⏳ Waiting for deployment to complete..."
sleep 30

# Check the status
echo "📊 Checking container app status..."
az containerapp show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.runningStatus" \
    --output tsv

# Get recent logs to verify the fix
echo "📋 Recent logs (checking for ImmuDB connection):"
az containerapp logs show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --tail 20 | grep -E "(ImmuDB|immu|Successfully connected)" || echo "No ImmuDB-related logs yet"

echo ""
echo "🎉 ImmuDB connection fix completed!"
echo ""
echo "🔍 What was fixed:"
echo "  - HANDRECEIPT_IMMUDB_HOST: Changed from FQDN to 'immudb' (container app name)"
echo "  - This allows internal communication between container apps in the same environment"
echo ""
echo "📋 Next steps:"
echo "  1. Monitor the logs for successful ImmuDB connection"
echo "  2. Test the API endpoints to ensure they're working"
echo "  3. If issues persist, check ImmuDB container app status" 