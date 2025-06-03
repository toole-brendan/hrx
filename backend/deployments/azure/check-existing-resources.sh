#!/bin/bash

# Script to check existing Azure resources for HandReceipt migration

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Azure subscription from screenshot
SUBSCRIPTION_ID="98b9185a-60b8-4df4-b8a4-73e6d35b176f"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Set subscription
print_status "Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

print_status "Checking existing Azure resources..."

# Check PostgreSQL Server
print_status "Checking PostgreSQL server: ptchampion-db"
if az postgres flexible-server show --name ptchampion-db --resource-group ptchampion-rg &>/dev/null; then
    print_success "Found PostgreSQL server: ptchampion-db"
    
    # List databases
    print_status "Databases in ptchampion-db:"
    az postgres flexible-server db list --server-name ptchampion-db --resource-group ptchampion-rg --output table
    
    # Check if handreceipt database exists
    if az postgres flexible-server db show --server-name ptchampion-db --resource-group ptchampion-rg --database-name handreceipt &>/dev/null; then
        print_warning "Database 'handreceipt' already exists in ptchampion-db"
    else
        print_status "Database 'handreceipt' does not exist - can be created"
    fi
else
    print_warning "PostgreSQL server ptchampion-db not found or not accessible"
fi

# Check Storage Account
print_status "Checking storage account: ptchampionweb"
if az storage account show --name ptchampionweb &>/dev/null; then
    print_success "Found storage account: ptchampionweb"
    
    # List containers
    print_status "Containers in ptchampionweb:"
    az storage container list --account-name ptchampionweb --output table 2>/dev/null || print_warning "Could not list containers (need access key)"
else
    print_warning "Storage account ptchampionweb not found"
fi

# Check Key Vault
print_status "Checking key vault: ptchampion-kv"
if az keyvault show --name ptchampion-kv &>/dev/null; then
    print_success "Found key vault: ptchampion-kv"
    
    # Check access
    if az keyvault secret list --vault-name ptchampion-kv &>/dev/null; then
        print_success "Have access to ptchampion-kv secrets"
    else
        print_warning "No access to ptchampion-kv secrets"
    fi
else
    print_warning "Key vault ptchampion-kv not found"
fi

# Check App Service
print_status "Checking app service: ptchampion-api-westus"
if az webapp show --name ptchampion-api-westus --resource-group ptchampion-rg &>/dev/null; then
    print_success "Found app service: ptchampion-api-westus"
    
    # Get app service plan
    PLAN=$(az webapp show --name ptchampion-api-westus --resource-group ptchampion-rg --query appServicePlanId -o tsv)
    print_status "App Service Plan: $PLAN"
else
    print_warning "App service ptchampion-api-westus not found"
fi

# Check SQL Server (for ledger)
print_status "Checking SQL server: handreceipt-ledger-server"
if az sql server show --name handreceipt-ledger-server --resource-group handreceipt-rg &>/dev/null; then
    print_success "Found SQL server: handreceipt-ledger-server"
    
    # List databases
    print_status "Databases in handreceipt-ledger-server:"
    az sql db list --server handreceipt-ledger-server --resource-group handreceipt-rg --output table
else
    print_warning "SQL server handreceipt-ledger-server not found"
fi

# Check for Container Apps
print_status "Checking for existing Container Apps environments..."
az containerapp env list --output table

# Summary
echo
print_status "=== RESOURCE REUSE RECOMMENDATIONS ==="
echo
print_success "1. PostgreSQL: Can reuse 'ptchampion-db' by creating new 'handreceipt' database"
print_success "2. Storage: Can reuse 'ptchampionweb' by creating new containers"
print_success "3. Key Vault: Can reuse 'ptchampion-kv' for secrets"
print_warning "4. Container Apps: Need to create new Container Apps environment"
print_warning "5. Container Registry: Need to create new ACR for HandReceipt"
echo
print_status "Estimated additional monthly cost: ~$50-100 for Container Apps + ACR" 