#!/bin/bash

# Emergency fix for HandReceipt backend startup issues
set -e

RESOURCE_GROUP="handreceipt-prod-rg"
BACKEND_APP_NAME="handreceipt-backend"

echo "🚑 Emergency Backend Fix - Disabling ImmuDB temporarily..."

# Disable ImmuDB to isolate the issue
az containerapp update \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --set-env-vars \
        HANDRECEIPT_IMMUDB_ENABLED="false" \
        HANDRECEIPT_DATABASE_SSL_MODE="require"

echo "✅ ImmuDB disabled. Waiting for backend to restart..."
sleep 60

# Test health endpoint
BACKEND_URL=$(az containerapp show \
    --name "$BACKEND_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv)

echo "🔍 Testing health endpoint: https://$BACKEND_URL/health"
curl -f "https://$BACKEND_URL/health" && echo "✅ Backend is healthy!" || echo "❌ Still failing" 