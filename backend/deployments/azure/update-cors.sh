#!/bin/bash

# Update CORS configuration for HandReceipt backend on Azure Container Apps

# Set variables
RESOURCE_GROUP="handreceipt-prod-rg"
BACKEND_APP_NAME="handreceipt-backend"

echo "🔧 Updating CORS configuration for HandReceipt backend..."

# Update environment variables with proper CORS origins
az containerapp update \
  --name $BACKEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars \
    CORS_ORIGINS="https://www.handreceipt.com,https://handreceipt.com,http://localhost:3000,http://localhost:5173,capacitor://localhost" \
    CORS_ALLOWED_ORIGINS="https://www.handreceipt.com,https://handreceipt.com,http://localhost:3000,http://localhost:5173,capacitor://localhost" \
    CORS_ALLOWED_METHODS="GET,POST,PUT,DELETE,PATCH,OPTIONS" \
    CORS_ALLOWED_HEADERS="*" \
    CORS_CREDENTIALS="true"

if [ $? -eq 0 ]; then
    echo "✅ CORS configuration updated successfully!"
    echo "🔄 The container will restart automatically to apply changes."
    echo ""
    echo "📝 Configured origins:"
    echo "  - https://www.handreceipt.com (production)"
    echo "  - https://handreceipt.com (production without www)"
    echo "  - http://localhost:3000 (local development)"
    echo "  - http://localhost:5173 (Vite development)"
    echo "  - capacitor://localhost (iOS app)"
else
    echo "❌ Failed to update CORS configuration"
    exit 1
fi 