# Azure Deployment Configuration for HandReceipt

## Azure Subscription Information
- **Subscription Name**: Azure subscription 1
- **Subscription ID**: 98b9185a-60b8-4df4-b8a4-73e6d35b176f
- **Current Monthly Cost**: $11.73

## Existing Azure Resources (from ptchampion project)
These resources already exist and can be referenced:
- **PostgreSQL Server**: ptchampion-db (Azure Database for PostgreSQL flexible server)
- **App Service**: ptchampion-api-westus
- **Key Vault**: ptchampion-kv
- **Storage Account**: ptchampionweb
- **Front Door**: ptchampion-frontend
- **SQL Server**: handreceipt-ledger-server (for ledger functionality)

## Proposed HandReceipt Resources
To avoid conflicts with existing resources, we'll use the following naming:

### Resource Group
- **Production**: handreceipt-prod-rg
- **Staging**: handreceipt-staging-rg
- **Development**: handreceipt-dev-rg

### Container Apps Environment
- **Name Pattern**: handreceipt-{env}-cae
- **Location**: East US (to match existing resources)

### Container Registry
- **Name Pattern**: handreceipt{env}acr
- **SKU**: Basic (can upgrade to Standard if needed)

### PostgreSQL Database
Options:
1. **Reuse existing**: ptchampion-db (if it's not in active use)
2. **Create new**: handreceipt-{env}-postgres

### Storage Account
Options:
1. **Reuse existing**: ptchampionweb (has existing containers)
2. **Create new**: handreceipt{env}storage

### Key Vault
Options:
1. **Reuse existing**: ptchampion-kv
2. **Create new**: handreceipt-{env}-kv

### Container Apps
- **Backend API**: handreceipt-backend-api
- **Worker**: handreceipt-worker
- **ImmuDB**: handreceipt-immudb

## Migration Considerations

### Database Migration
If reusing ptchampion-db:
- Create a new database named 'handreceipt' within the existing server
- Use separate schemas or prefixes to avoid conflicts

If creating new PostgreSQL:
- Use Flexible Server tier (Burstable B2ms for cost optimization)
- Enable high availability only for production

### Storage Migration
If reusing ptchampionweb storage account:
- Create new containers: 'handreceipt-documents', 'handreceipt-photos'
- Use separate containers to avoid conflicts

If creating new storage:
- Standard LRS for development/staging
- Standard GRS for production (geo-redundancy)

### Cost Optimization
Based on current $11.73/month spend:
- Consider using existing resources where possible
- Use Container Apps consumption plan (pay per use)
- Start with Burstable tier for PostgreSQL
- Use Basic tier for Container Registry

## Environment Variables Update
Update the deployment scripts with:
```bash
# For reusing existing resources
export EXISTING_POSTGRES_SERVER="ptchampion-db"
export EXISTING_STORAGE_ACCOUNT="ptchampionweb"
export EXISTING_KEY_VAULT="ptchampion-kv"

# Subscription ID
export AZURE_SUBSCRIPTION_ID="98b9185a-60b8-4df4-b8a4-73e6d35b176f"
``` 