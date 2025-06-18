#!/bin/bash

# HandReceipt Frontend Deployment Script for Azure
# This script deploys the React frontend to Azure Storage Static Website

set -e

# Configuration
ENVIRONMENT=${ENVIRONMENT:-prod}
BASE_NAME="handreceipt"
RESOURCE_GROUP="${BASE_NAME}-${ENVIRONMENT}-rg"
STORAGE_ACCOUNT_NAME="${BASE_NAME}${ENVIRONMENT}storage"
CDN_PROFILE_NAME="${BASE_NAME}-${ENVIRONMENT}-cdn"
CDN_ENDPOINT_NAME="${BASE_NAME}-${ENVIRONMENT}-frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 HandReceipt Frontend Deployment to Azure${NC}"
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo ""

# Check if we're in the right directory
if [ ! -f "../../../web/package.json" ]; then
    echo -e "${RED}❌ Error: This script must be run from backend/deployments/azure directory${NC}"
    echo "Current directory: $(pwd)"
    echo "Looking for: ../../../web/package.json"
    exit 1
fi

# Check if Azure CLI is logged in
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Azure CLI not logged in. Please run 'az login'${NC}"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Error: Node.js is not installed${NC}"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ Error: npm is not installed${NC}"
    exit 1
fi

# Step 1: Install dependencies
echo -e "${BLUE}📦 Installing dependencies...${NC}"
cd ../../../web
npm ci

# Step 2: Build the application
echo -e "${BLUE}🔨 Building React application...${NC}"

# Set environment variables for production build
export VITE_API_URL="https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io"
export VITE_APP_ENVIRONMENT="$ENVIRONMENT"

npm run build

# Check if build was successful
if [ ! -d "dist/public" ]; then
    echo -e "${RED}❌ Error: Build failed - dist/public directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build completed successfully${NC}"

# Step 3: Enable static website hosting (skip if already enabled)
echo -e "${BLUE}🌐 Ensuring static website hosting is enabled...${NC}"
az storage blob service-properties update \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --static-website \
    --index-document index.html \
    --404-document index.html > /dev/null 2>&1 || echo "Static website already configured"

# Step 4: Deploy to Azure Storage
echo -e "${BLUE}📤 Uploading files to Azure Storage...${NC}"
az storage blob upload-batch \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --destination '$web' \
    --source dist/public \
    --overwrite

echo -e "${GREEN}✅ Files uploaded successfully${NC}"

# Step 5: Get storage website URL
STATIC_WEBSITE_URL=$(az storage account show \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "primaryEndpoints.web" \
    --output tsv)

echo -e "${GREEN}✅ Static website URL: $STATIC_WEBSITE_URL${NC}"

# Step 6: Purge CDN cache (if CDN exists)
echo -e "${BLUE}🔄 Checking for CDN endpoint...${NC}"
if az cdn endpoint show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CDN_ENDPOINT_NAME" \
    --profile-name "$CDN_PROFILE_NAME" > /dev/null 2>&1; then
    
    echo -e "${BLUE}🔄 Purging CDN cache...${NC}"
    az cdn endpoint purge \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CDN_ENDPOINT_NAME" \
        --profile-name "$CDN_PROFILE_NAME" \
        --content-paths "/*"
    
    # Get CDN URL
    CDN_HOSTNAME=$(az cdn endpoint show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CDN_ENDPOINT_NAME" \
        --profile-name "$CDN_PROFILE_NAME" \
        --query "hostName" \
        --output tsv)
    
    CDN_URL="https://$CDN_HOSTNAME"
    echo -e "${GREEN}✅ CDN cache purged${NC}"
    echo -e "${GREEN}🌍 CDN URL: $CDN_URL${NC}"
else
    echo -e "${YELLOW}⚠️  CDN endpoint not found - using direct storage URL${NC}"
    CDN_URL=""
fi

# Step 7: Summary
echo ""
echo -e "${GREEN}🎉 Frontend deployment completed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo "📁 Files deployed to: $STORAGE_ACCOUNT_NAME/$web"
echo "🌐 Static Website URL: $STATIC_WEBSITE_URL"
if [ -n "$CDN_URL" ]; then
    echo "🌍 CDN URL (Recommended): $CDN_URL"
    echo ""
    echo -e "${YELLOW}💡 Use the CDN URL for production traffic for better performance${NC}"
else
    echo ""
    echo -e "${YELLOW}💡 Consider setting up Azure CDN for better performance${NC}"
fi

echo ""
echo -e "${BLUE}🔗 Next Steps:${NC}"
echo "1. Test your application at the provided URL(s)"
echo "2. Configure custom domain if needed"
echo "3. Set up monitoring and alerts"
echo "4. Configure CORS if needed for API calls"

# Return to original directory
cd ../backend/deployments/azure

echo -e "${GREEN}✅ Deployment script completed${NC}" 