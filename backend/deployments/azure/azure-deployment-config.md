# Azure Deployment Configuration for HandReceipt

## Azure Subscription Information
- **Subscription Name**: Azure subscription 1
- **Subscription ID**: 98b9185a-60b8-4df4-b8a4-73e6d35b176f
- **Tenant ID**: 7d69778a-2fe3-4d8b-be48-6e66a0db4640
- **Account**: toole.brendan@gmail.com
- **Current Resources**: Using fresh infrastructure (not reusing old ptchampion resources)

## HandReceipt Azure Resources (Fresh Deployment)
Using dedicated resources for HandReceipt to ensure clean separation and avoid conflicts:

### Resource Group
- **Production**: handreceipt-prod-rg
- **Staging**: handreceipt-staging-rg  
- **Development**: handreceipt-dev-rg
- **Location**: East US 2 (eastus2)

### Container Apps Environment
- **Name Pattern**: handreceipt-{env}-cae
- **Location**: East US 2 (consistent with resource group)

### Container Registry
- **Name Pattern**: handreceipt{env}acr
- **SKU**: Basic (can upgrade to Standard if needed)

### PostgreSQL Database
- **Name Pattern**: handreceipt-{env}-postgres
- **Type**: Azure Database for PostgreSQL Flexible Server
- **Tier**: Burstable B2ms (cost-optimized)
- **Database Name**: handreceipt

### Storage Account
- **Name Pattern**: handreceipt{env}storage
- **Type**: General Purpose v2
- **Redundancy**: Standard LRS (development/staging), Standard GRS (production)
- **Containers**: 
  - documents (for file storage)
  - immudb-data (for ImmuDB persistence via File Share)

### Key Vault
- **Name Pattern**: handreceipt-{env}-kv
- **Used for**: Storing secrets (DB passwords, storage keys, JWT secrets)

### Container Apps
- **Backend API**: handreceipt-backend-api
- **Worker**: handreceipt-worker  
- **ImmuDB**: immudb

## Migration Strategy

### Clean Infrastructure Approach
- **No resource reuse**: Creating all new resources for HandReceipt
- **Dedicated naming**: Clear separation from any existing resources
- **Cost efficiency**: Using consumption-based and burstable tiers where appropriate

### Resource Configuration
- **PostgreSQL**: New Flexible Server with proper sizing for workload
- **Storage**: New storage account with appropriate containers and file shares
- **Key Vault**: New vault for HandReceipt-specific secrets
- **Container Apps**: Fresh environment optimized for the HandReceipt workload

### Cost Optimization
Based on current subscription usage:
- Container Apps consumption plan (pay per use)
- Burstable PostgreSQL tier for cost efficiency
- Standard LRS storage for non-critical environments
- Basic tier Container Registry

## Environment Variables for Deployment
```bash
# Azure Account Information
export AZURE_SUBSCRIPTION_ID="98b9185a-60b8-4df4-b8a4-73e6d35b176f"
export AZURE_TENANT_ID="7d69778a-2fe3-4d8b-be48-6e66a0db4640"

# Deployment Configuration
export RESOURCE_GROUP="handreceipt-prod-rg"
export LOCATION="eastus2"
export ENVIRONMENT="prod"
export BASE_NAME="handreceipt"
```

## Benefits of Fresh Infrastructure
- **Clean slate**: No conflicts with existing resources
- **Optimized configuration**: Resources sized specifically for HandReceipt
- **Clear ownership**: Dedicated resources make management easier
- **Cost transparency**: Clear cost attribution for HandReceipt services
- **Security isolation**: Separate Key Vault and access policies 