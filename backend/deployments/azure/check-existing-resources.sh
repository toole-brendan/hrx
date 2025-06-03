#!/bin/bash

# Script to check Azure resources for HandReceipt deployment

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Azure subscription and configuration
SUBSCRIPTION_ID="98b9185a-60b8-4df4-b8a4-73e6d35b176f"
RESOURCE_GROUP="handreceipt-prod-rg"
LOCATION="eastus2"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set subscription
print_status "Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

print_status "Checking HandReceipt Azure resources..."

# Check Resource Group
print_status "Checking resource group: $RESOURCE_GROUP"
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found resource group: $RESOURCE_GROUP"
    
    # Get location
    ACTUAL_LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
    if [ "$ACTUAL_LOCATION" = "$LOCATION" ]; then
        print_success "Resource group is in correct location: $LOCATION"
    else
        print_warning "Resource group is in $ACTUAL_LOCATION, expected $LOCATION"
    fi
else
    print_warning "Resource group $RESOURCE_GROUP does not exist - will be created during deployment"
fi

# Check PostgreSQL Server
print_status "Checking PostgreSQL server: handreceipt-prod-postgres"
if az postgres flexible-server show --name handreceipt-prod-postgres --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found PostgreSQL server: handreceipt-prod-postgres"
    
    # List databases
    print_status "Databases in handreceipt-prod-postgres:"
    az postgres flexible-server db list --server-name handreceipt-prod-postgres --resource-group "$RESOURCE_GROUP" --output table
else
    print_warning "PostgreSQL server handreceipt-prod-postgres not found - will be created during deployment"
fi

# Check Storage Account
print_status "Checking storage account: handreceiptprodstorage"
if az storage account show --name handreceiptprodstorage --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found storage account: handreceiptprodstorage"
    
    # List containers
    print_status "Containers in handreceiptprodstorage:"
    az storage container list --account-name handreceiptprodstorage --output table 2>/dev/null || print_warning "Could not list containers (need access key)"
else
    print_warning "Storage account handreceiptprodstorage not found - will be created during deployment"
fi

# Check Key Vault
print_status "Checking key vault: handreceipt-prod-kv"
if az keyvault show --name handreceipt-prod-kv --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found key vault: handreceipt-prod-kv"
    
    # Check access
    if az keyvault secret list --vault-name handreceipt-prod-kv &>/dev/null; then
        print_success "Have access to handreceipt-prod-kv secrets"
        print_status "Secrets in vault:"
        az keyvault secret list --vault-name handreceipt-prod-kv --output table
    else
        print_warning "No access to handreceipt-prod-kv secrets"
    fi
else
    print_warning "Key vault handreceipt-prod-kv not found - will be created during deployment"
fi

# Check Container Registry
print_status "Checking container registry: handreceiptprodacr"
if az acr show --name handreceiptprodacr --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found container registry: handreceiptprodacr"
    
    # Get login server
    LOGIN_SERVER=$(az acr show --name handreceiptprodacr --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)
    print_status "Login server: $LOGIN_SERVER"
else
    print_warning "Container registry handreceiptprodacr not found - will be created during deployment"
fi

# Check Container Apps Environment
print_status "Checking Container Apps environment: handreceipt-prod-cae"
if az containerapp env show --name handreceipt-prod-cae --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found Container Apps environment: handreceipt-prod-cae"
    
    # List container apps in environment
    print_status "Container Apps in environment:"
    az containerapp list --resource-group "$RESOURCE_GROUP" --output table
else
    print_warning "Container Apps environment handreceipt-prod-cae not found - will be created during deployment"
fi

# Check individual Container Apps
print_status "Checking individual Container Apps..."

# Backend API
if az containerapp show --name handreceipt-backend-api --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found backend API container app"
    BACKEND_URL=$(az containerapp show --name handreceipt-backend-api --resource-group "$RESOURCE_GROUP" --query "properties.configuration.ingress.fqdn" -o tsv)
    print_status "Backend URL: https://$BACKEND_URL"
else
    print_warning "Backend API container app not found"
fi

# Worker
if az containerapp show --name handreceipt-worker --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found worker container app"
else
    print_warning "Worker container app not found"
fi

# ImmuDB
if az containerapp show --name immudb --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_success "Found ImmuDB container app"
else
    print_warning "ImmuDB container app not found"
fi

# Summary
echo
print_status "=== DEPLOYMENT STATUS SUMMARY ==="
echo

# Count existing resources
EXISTING_COUNT=0
TOTAL_COUNT=6

if az group show --name "$RESOURCE_GROUP" &>/dev/null; then ((EXISTING_COUNT++)); fi
if az postgres flexible-server show --name handreceipt-prod-postgres --resource-group "$RESOURCE_GROUP" &>/dev/null; then ((EXISTING_COUNT++)); fi
if az storage account show --name handreceiptprodstorage --resource-group "$RESOURCE_GROUP" &>/dev/null; then ((EXISTING_COUNT++)); fi
if az keyvault show --name handreceipt-prod-kv --resource-group "$RESOURCE_GROUP" &>/dev/null; then ((EXISTING_COUNT++)); fi
if az acr show --name handreceiptprodacr --resource-group "$RESOURCE_GROUP" &>/dev/null; then ((EXISTING_COUNT++)); fi
if az containerapp env show --name handreceipt-prod-cae --resource-group "$RESOURCE_GROUP" &>/dev/null; then ((EXISTING_COUNT++)); fi

print_status "Infrastructure Status: $EXISTING_COUNT/$TOTAL_COUNT resources exist"

if [ $EXISTING_COUNT -eq 0 ]; then
    print_warning "No HandReceipt resources found - this appears to be a fresh deployment"
    print_status "Next step: Run the deployment script to create all resources"
elif [ $EXISTING_COUNT -eq $TOTAL_COUNT ]; then
    print_success "All HandReceipt infrastructure exists - ready for application deployment"
else
    print_warning "Partial deployment detected - you may need to run the full deployment script"
fi

echo
print_status "To deploy: cd backend/deployments/azure && ./deploy-azure.sh" 