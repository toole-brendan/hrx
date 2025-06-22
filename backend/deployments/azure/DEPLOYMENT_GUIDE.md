# HandReceipt Azure Migration - Complete Deployment Guide

This guide provides step-by-step instructions for migrating your HandReceipt application from AWS Lightsail to Microsoft Azure.

## Overview

The migration involves moving from a single Lightsail VM running Docker Compose to Azure's managed services:

- **AWS Lightsail VM** → **Azure Container Apps**
- **PostgreSQL (container)** → **Azure Database for PostgreSQL Flexible Server**
- **MinIO (container)** → **Azure Blob Storage**
- **ImmuDB (container)** → **Azure SQL Database ledger tables** (immutable audit trail)
- **Nginx (container)** → **Azure Container Apps ingress** (built-in SSL/TLS)
- **Prometheus/Grafana** → **Azure Monitor + Application Insights**

## Prerequisites

1. **Azure CLI** installed and configured
2. **Docker** installed locally
3. **Azure subscription** with appropriate permissions
4. **SSH access** to your current Lightsail instance
5. **Domain name** (optional, for custom domain setup)

## Step 1: Prepare Azure Environment

### 1.1 Install Azure CLI (if not already installed)

```bash
# macOS
brew install azure-cli

# Windows
winget install Microsoft.AzureCLI

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### 1.2 Login to Azure

```bash
az login
az account list --output table
az account set --subscription "your-subscription-id"
```

### 1.3 Set Environment Variables

Create a `.env` file with your configuration:

```bash
# Required variables
export SUBSCRIPTION_ID="your-azure-subscription-id"
export POSTGRES_ADMIN_PASSWORD="YourSecurePassword123!"

# Optional variables
export RESOURCE_GROUP="handreceipt-prod-rg"
export LOCATION="eastus"
export ENVIRONMENT="prod"
export BASE_NAME="handreceipt"
export CUSTOM_DOMAIN="handreceipt.yourdomain.com"

# For data migration
export LIGHTSAIL_HOST="your-lightsail-ip"
export LIGHTSAIL_SSH_KEY="~/.ssh/your-lightsail-key.pem"
```

Load the environment variables:
```bash
source .env
```

## Step 2: Deploy Azure Infrastructure

### 2.1 Navigate to Azure Deployment Directory

```bash
cd backend/deployments/azure
```

### 2.2 Run the Deployment Script

```bash
chmod +x deploy-azure.sh
./deploy-azure.sh
```

This script will:
- Create the resource group
- Deploy all Azure resources using Bicep
- Build and push Docker images to Azure Container Registry
- Deploy Container Apps
- Configure networking and security

### 2.3 Verify Infrastructure Deployment

Check that all resources were created:

```bash
az resource list --resource-group $RESOURCE_GROUP --output table
```

You should see:
- Container Apps Environment
- PostgreSQL Flexible Server
- Storage Account
- Key Vault
- Container Registry
- Log Analytics Workspace
- Application Insights

## Step 3: Migrate Data

### 3.1 Prepare Migration Environment

Set additional environment variables for data migration:

```bash
# Get Azure resource details from deployment outputs
export AZURE_POSTGRES_HOST=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name infrastructure \
  --query "properties.outputs.postgresServerFqdn.value" \
  --output tsv)

export AZURE_STORAGE_ACCOUNT=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name infrastructure \
  --query "properties.outputs.storageAccountName.value" \
  --output tsv)

export AZURE_STORAGE_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --query "[0].value" \
  --output tsv)

export AZURE_POSTGRES_PASSWORD=$POSTGRES_ADMIN_PASSWORD
export AZURE_POSTGRES_USER="hradmin"
export AZURE_POSTGRES_DB="handreceipt"
export AZURE_STORAGE_CONTAINER="documents"
```

### 3.2 Run Data Migration

```bash
chmod +x migrate-data.sh
./migrate-data.sh
```

This script will:
- Backup PostgreSQL database from Lightsail
- Restore database to Azure PostgreSQL
- Migrate audit data to Azure SQL ledger tables
- Migrate MinIO files to Azure Blob Storage
- Generate a migration report

### 3.3 Verify Data Migration

Check that data was migrated successfully:

```bash
# Check PostgreSQL tables
PGPASSWORD=$AZURE_POSTGRES_PASSWORD psql \
  -h $AZURE_POSTGRES_HOST \
  -U $AZURE_POSTGRES_USER \
  -d $AZURE_POSTGRES_DB \
  -c "\dt"

# Check Azure Blob Storage
az storage blob list \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --account-key $AZURE_STORAGE_KEY \
  --container-name $AZURE_STORAGE_CONTAINER \
  --output table
```

## Step 4: Configure Application

### 4.1 Update Container Apps with Secrets

The deployment script should have already configured Key Vault secrets, but verify they're accessible:

```bash
# Test Key Vault access
az keyvault secret list --vault-name handreceipt-prod-kv --output table
```

### 4.2 Verify Ledger Tables

Verify that Azure SQL ledger tables are properly configured:

```bash
# Connect to Azure SQL Database
PGPASSWORD=$AZURE_POSTGRES_PASSWORD psql \
  -h $AZURE_POSTGRES_HOST \
  -U $AZURE_POSTGRES_USER \
  -d $AZURE_POSTGRES_DB \
  -c "SELECT * FROM sys.database_ledger_transactions LIMIT 5;"

# Verify ledger digest
az sql db ledger-digest-uploads show \
  --resource-group $RESOURCE_GROUP \
  --server handreceipt-prod-sql \
  --database handreceipt
```

## Step 5: Configure DNS and SSL

### 5.1 Get Application URL

```bash
BACKEND_URL=$(az containerapp show \
  --resource-group $RESOURCE_GROUP \
  --name handreceipt-backend-api \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv)

echo "Application URL: https://$BACKEND_URL"
```

### 5.2 Configure Custom Domain (Optional)

If you have a custom domain:

```bash
# Add custom domain to Container App
az containerapp hostname add \
  --resource-group $RESOURCE_GROUP \
  --name handreceipt-backend-api \
  --hostname $CUSTOM_DOMAIN

# Update your DNS records to point to the Container App FQDN
echo "Update DNS: $CUSTOM_DOMAIN CNAME $BACKEND_URL"
```

### 5.3 Configure SSL Certificate

Azure Container Apps provides automatic SSL for custom domains. Follow the Azure portal instructions to:
1. Verify domain ownership
2. Configure SSL certificate
3. Enable HTTPS redirect

## Step 6: Test and Validate

### 6.1 Health Check

```bash
curl -f "https://$BACKEND_URL/health"
```

Expected response:
```json
{
  "status": "healthy",
  "service": "handreceipt-api",
  "version": "1.0.0"
}
```

### 6.2 Test Application Functionality

1. **Authentication**: Test login/register endpoints
2. **Database**: Verify property and user data
3. **File Storage**: Test photo upload/download
4. **Ledger Tables**: Verify Azure SQL ledger functionality
5. **Mobile Apps**: Update API endpoints in mobile apps

### 6.3 Performance Testing

Monitor the application using Azure Monitor:

```bash
# View Container Apps metrics
az monitor metrics list \
  --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/handreceipt-backend-api" \
  --metric "Requests" \
  --output table
```

## Step 7: Update Client Applications

### 7.1 Update Web Frontend

Update the API base URL in your web frontend configuration:

```javascript
// Before (Lightsail)
const API_BASE_URL = 'https://your-lightsail-domain.com/api';

// After (Azure)
const API_BASE_URL = 'https://your-custom-domain.com/api';
// or
const API_BASE_URL = 'https://handreceipt-backend-api.kindocean-12345.eastus.azurecontainerapps.io/api';
```

### 7.2 Update Mobile Apps

Update the API endpoints in your iOS and Android applications:

```swift
// iOS - Update in your configuration file
let apiBaseURL = "https://your-new-azure-domain.com/api"
```

```kotlin
// Android - Update in your configuration
const val API_BASE_URL = "https://your-new-azure-domain.com/api"
```

## Step 8: Monitoring and Maintenance

### 8.1 Set Up Monitoring

Azure Monitor and Application Insights are automatically configured. Set up alerts:

```bash
# Create alert for high error rate
az monitor metrics alert create \
  --name "High Error Rate" \
  --resource-group $RESOURCE_GROUP \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/handreceipt-backend-api" \
  --condition "avg Requests > 100" \
  --description "Alert when error rate is high"
```

### 8.2 Set Up Backup Strategy

```bash
# Enable automated backups for PostgreSQL (already enabled by default)
az postgres flexible-server backup list \
  --resource-group $RESOURCE_GROUP \
  --name handreceipt-prod-postgres

# Set up blob storage backup (optional)
az storage blob service-properties update \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --enable-delete-retention true \
  --delete-retention-days 30
```

### 8.3 Cost Optimization

Monitor and optimize costs:

```bash
# View cost analysis
az consumption usage list \
  --start-date $(date -d "30 days ago" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --output table
```

## Step 9: Decommission Lightsail

### 9.1 Final Verification

Before decommissioning Lightsail:

1. ✅ All functionality tested on Azure
2. ✅ Data migration verified
3. ✅ Mobile apps updated and tested
4. ✅ DNS updated and propagated
5. ✅ Monitoring and alerts configured
6. ✅ Backup strategy in place

### 9.2 Create Final Backup

```bash
# Create final backup of Lightsail instance
ssh -i $LIGHTSAIL_SSH_KEY admin@$LIGHTSAIL_HOST "sudo tar czf /tmp/final-backup.tar.gz /opt/handreceipt"
scp -i $LIGHTSAIL_SSH_KEY admin@$LIGHTSAIL_HOST:/tmp/final-backup.tar.gz ./lightsail-final-backup.tar.gz
```

### 9.3 Terminate Lightsail Instance

Once everything is verified working on Azure:

1. Stop the Lightsail instance
2. Wait 24-48 hours to ensure no issues
3. Delete the Lightsail instance
4. Cancel any associated AWS services

## Troubleshooting

### Common Issues

1. **Container Apps not starting**
   - Check logs: `az containerapp logs show --name handreceipt-backend-api --resource-group $RESOURCE_GROUP`
   - Verify environment variables and secrets

2. **Database connection issues**
   - Check firewall rules
   - Verify SSL configuration
   - Test connection string

3. **Storage access issues**
   - Verify storage account keys
   - Check container permissions
   - Test blob operations

4. **Ledger table issues**
   - Verify ledger tables are enabled
   - Check Azure SQL permissions
   - Review ledger transaction logs

### Getting Help

- Azure Documentation: https://docs.microsoft.com/azure/
- Azure Support: Create support ticket in Azure Portal
- HandReceipt Issues: Check application logs and Azure Monitor

## Cost Estimation

Expected monthly costs for production workload:

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| Container Apps | 2 vCPU, 4GB RAM | $50-100 |
| PostgreSQL Flexible | Burstable B2ms | $40-80 |
| Blob Storage | Standard LRS, 100GB | $5-10 |
| Key Vault | Standard tier | $3 |
| Application Insights | Basic tier | $5-15 |
| **Total** | | **$103-208** |

## Security Best Practices

1. **Secrets Management**: All secrets stored in Key Vault
2. **Network Security**: Private endpoints for database
3. **Identity**: Managed identities for service authentication
4. **Monitoring**: Comprehensive logging and alerting
5. **Backup**: Automated backups with point-in-time recovery
6. **Updates**: Regular security updates via Container Apps

---

This completes the migration from AWS Lightsail to Microsoft Azure. Your HandReceipt application is now running on a scalable, managed cloud platform with enterprise-grade security and monitoring. 