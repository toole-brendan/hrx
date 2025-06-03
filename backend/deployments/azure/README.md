# HandReceipt Azure Migration Guide

This guide walks through migrating the HandReceipt application from AWS Lightsail to Microsoft Azure.

## Architecture Overview

### Current Lightsail Stack
- Docker Compose on single VM
- PostgreSQL (containerized)
- ImmuDB (containerized) 
- MinIO (containerized)
- Nginx (containerized)
- Go Backend + Worker (containerized)
- Prometheus/Grafana (containerized)

### Target Azure Stack
- **Azure Container Apps** - Host application containers
- **Azure Database for PostgreSQL Flexible Server** - Managed PostgreSQL
- **Azure Blob Storage** - Replace MinIO object storage
- **ImmuDB** - Continue in container (no Azure equivalent)
- **Azure Application Gateway** - Replace Nginx (optional)
- **Azure Monitor + Application Insights** - Replace Prometheus/Grafana

## Prerequisites

1. Azure CLI installed and logged in
2. Docker installed locally
3. Azure Container Registry (ACR) set up
4. Resource group created in target region

## Migration Steps

1. [Provision Azure Resources](#step-1-provision-azure-resources)
2. [Migrate Database](#step-2-migrate-database)
3. [Migrate File Storage](#step-3-migrate-file-storage)
4. [Deploy Containers](#step-4-deploy-containers)
5. [Configure DNS and SSL](#step-5-configure-dns-and-ssl)
6. [Test and Validate](#step-6-test-and-validate)
7. [Cutover and Cleanup](#step-7-cutover-and-cleanup)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Resource Group                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │ Container Apps  │  │   PostgreSQL     │                 │
│  │   Environment   │  │ Flexible Server  │                 │
│  │                 │  │                  │                 │
│  │ ┌─────────────┐ │  │ ┌──────────────┐ │                 │
│  │ │ HandReceipt │ │  │ │   Database   │ │                 │
│  │ │ Backend API │ │  │ │              │ │                 │
│  │ └─────────────┘ │  │ └──────────────┘ │                 │
│  │                 │  └──────────────────┘                 │
│  │ ┌─────────────┐ │                                       │
│  │ │   ImmuDB    │ │  ┌──────────────────┐                 │
│  │ │  Container  │ │  │   Blob Storage   │                 │
│  │ └─────────────┘ │  │                  │                 │
│  │                 │  │ ┌──────────────┐ │                 │
│  │ ┌─────────────┐ │  │ │  Documents   │ │                 │
│  │ │   Worker    │ │  │ │  Container   │ │                 │
│  │ │  Container  │ │  │ └──────────────┘ │                 │
│  │ └─────────────┘ │  └──────────────────┘                 │
│  └─────────────────┘                                       │
│                                                             │
│  ┌─────────────────┐  ┌──────────────────┐                 │
│  │   Key Vault     │  │  File Share      │                 │
│  │    (Secrets)    │  │ (ImmuDB data)    │                 │
│  └─────────────────┘  └──────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## Configuration Files

- `infrastructure.bicep` - Azure infrastructure as code
- `container-apps.yml` - Container Apps configuration  
- `azure-compose.yml` - Azure-specific compose file
- `azure.env` - Azure environment variables
- `deploy-azure.sh` - Deployment automation script
- `migrate-data.sh` - Data migration script

## Cost Estimation

| Service | Configuration | Monthly Cost (Est.) |
|---------|---------------|-------------------|
| Container Apps | 2 vCPU, 4GB RAM | $50-100 |
| PostgreSQL Flexible | Burstable B2ms | $40-80 |
| Blob Storage | Standard LRS, 100GB | $5-10 |
| Key Vault | Standard tier | $3 |
| **Total** | | **$98-193** |

## Security Considerations

- All secrets stored in Azure Key Vault
- Network isolation with VNet integration
- Managed identities for service authentication
- SSL/TLS termination at Container Apps ingress
- Private endpoints for database access

## Monitoring and Logging

- Azure Monitor for metrics and alerts
- Application Insights for APM
- Log Analytics for centralized logging
- Built-in health checks and auto-scaling

---

Continue to the detailed step-by-step implementation guide below. 