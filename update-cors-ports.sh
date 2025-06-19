#!/bin/bash

# Update CORS configuration to include additional local development ports
echo "🔧 Updating CORS configuration for HandReceipt backend..."
echo "Adding support for ports 5001, 5002, and 5003"

# Set variables
RESOURCE_GROUP="handreceipt-prod-rg"
BACKEND_APP_NAME="handreceipt-backend"

# Updated CORS origins including the new ports
CORS_ORIGINS="https://www.handreceipt.com,https://handreceipt.com,http://localhost:3000,http://localhost:5001,http://localhost:5002,http://localhost:5003,http://localhost:5173,capacitor://localhost"

echo "🌐 New CORS origins:"
echo "  - https://www.handreceipt.com (production)"
echo "  - https://handreceipt.com (production without www)"
echo "  - http://localhost:3000 (local development)"
echo "  - http://localhost:5001 (Vite dev server)"
echo "  - http://localhost:5002 (Vite dev server alternate)"
echo "  - http://localhost:5003 (Vite dev server alternate)"
echo "  - http://localhost:5173 (Vite dev server default)"
echo "  - capacitor://localhost (iOS app)"
echo ""

# Update the Azure Container App
az containerapp update \
  --name $BACKEND_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars \
    CORS_ORIGINS="$CORS_ORIGINS" \
    CORS_ALLOWED_ORIGINS="$CORS_ORIGINS" \
    CORS_ALLOWED_METHODS="GET,POST,PUT,DELETE,PATCH,OPTIONS" \
    CORS_ALLOWED_HEADERS="*" \
    CORS_CREDENTIALS="true"

if [ $? -eq 0 ]; then
    echo "✅ CORS configuration updated successfully!"
    echo "🔄 The container will restart automatically to apply changes."
    echo ""
    echo "📝 You can now connect your frontend from any of these ports:"
    echo "  - localhost:5001"
    echo "  - localhost:5002" 
    echo "  - localhost:5003"
    echo "  - localhost:5173"
    echo "  - localhost:3000"
    echo ""
    echo "⏳ Wait 1-2 minutes for the container to restart, then try your login again."
else
    echo "❌ Failed to update CORS configuration"
    echo "Make sure you're logged into Azure CLI: az login"
    exit 1
fi 