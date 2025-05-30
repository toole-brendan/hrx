# HandReceipt Deployment Guide

## Architecture Overview

HandReceipt uses a microservices architecture with the following components:

### Core Services
- **Backend API** (Go/Gin) - Main application server on port 8080
- **PostgreSQL** - Primary relational database for user data, properties, and transfers
- **ImmuDB** - Immutable ledger for audit trail (replaces AWS QLDB)
- **MinIO** - S3-compatible object storage for photos and documents
- **Nginx** - Reverse proxy and load balancer

### Frontend Services
- **Web App** (React/Vite) - Deployed to S3 + CloudFront
- **iOS App** - Native mobile application

## Key Architecture Decisions

### Why ImmuDB instead of AWS QLDB?
- **Self-hosted**: Complete control over data and infrastructure
- **Cost-effective**: No AWS service charges
- **Open source**: Community support and transparency
- **Immutable ledger**: Cryptographic proof of data integrity
- **Performance**: Lower latency for on-premise deployments

### Database Strategy
- **PostgreSQL**: Primary data store for current state
- **ImmuDB**: Immutable audit trail for all changes
- **Dual-write pattern**: Write to both databases for consistency

## Deployment Environments

### Production (AWS Lightsail)
- **Instance**: Ubuntu 20.04 LTS on Lightsail
- **Domain**: api.handreceipt.com
- **SSL**: Let's Encrypt via Certbot
- **Monitoring**: Prometheus + Grafana

### Local Development
```bash
cd backend
docker-compose up -d
```

## Configuration

### Environment Variables
The application uses a hierarchical configuration system:
1. Default values in code
2. `configs/config.yaml` - Base configuration
3. `configs/config.production.yaml` - Production overrides
4. Environment variables (highest priority)

### Critical Configuration

#### JWT Authentication
```yaml
jwt:
  secret_key: "YOUR_SECRET_KEY"  # Must be changed in production
  access_expiry: "24h"
  refresh_expiry: "168h"
```

#### ImmuDB Configuration
```yaml
immudb:
  host: "immudb"  # Docker service name
  port: 3322
  username: "immudb"
  password: "SECURE_PASSWORD"
  database: "defaultdb"
  enabled: true
```

#### Database Configuration
```yaml
database:
  host: "postgres"  # Docker service name
  port: 5432
  user: "handreceipt"
  password: "SECURE_PASSWORD"
  name: "handreceipt"
  ssl_mode: "disable"  # Enable in production with proper certs
```

## Deployment Process

### GitHub Actions Workflow
The deployment is automated via `.github/workflows/deploy-production.yml`:

1. **Frontend Deployment**
   - Build React app with production API URL
   - Upload to S3 bucket
   - Invalidate CloudFront cache

2. **Backend Deployment**
   - Create deployment package
   - Upload to Lightsail via SSH
   - Build Docker images
   - Start services with docker-compose

### Manual Deployment
```bash
# SSH to Lightsail
ssh -i ~/.ssh/handreceipt-key ubuntu@YOUR_IP

# Navigate to app directory
cd /opt/handreceipt/backend

# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose build
docker-compose up -d
```

## Monitoring and Maintenance

### Health Checks
- API Health: `https://api.handreceipt.com/health`
- Database: `docker exec backend_postgres_1 pg_isready`
- ImmuDB: Check port 3322 connectivity
- MinIO: Console at port 9001

### Logs
```bash
# View all logs
docker-compose logs -f

# Specific service logs
docker-compose logs -f app
docker-compose logs -f immudb
```

### Backup Strategy
1. **PostgreSQL**: Daily pg_dump backups
2. **ImmuDB**: Immutable by design, replicate for DR
3. **MinIO**: Bucket replication to S3

## Troubleshooting

### Common Issues

1. **Route Conflicts**
   - Ensure specific routes come before wildcard routes in Gin router
   - Example: `/:propertyId/qrcodes` before `/:id`

2. **Service Connection Issues**
   - Use Docker service names, not localhost
   - Ensure all services are on the same network

3. **Port Conflicts**
   - App: 8080
   - PostgreSQL: 5432
   - ImmuDB: 3322, 9497
   - MinIO: 9000, 9001

### Emergency Recovery
```bash
# Stop all services
docker-compose down

# Remove volumes (careful - data loss!)
docker-compose down -v

# Fresh start
docker-compose up -d
```

## Security Considerations

1. **Change all default passwords** before production deployment
2. **Enable SSL/TLS** for all external connections
3. **Configure firewall** to restrict access
4. **Regular security updates** for base images
5. **Audit logs** via ImmuDB for compliance

## Future Enhancements

1. **Redis Cache** - Currently disabled, enable for performance
2. **Horizontal Scaling** - Add load balancer for multiple app instances
3. **Kubernetes** - Migration path for orchestration
4. **Monitoring** - Expand Prometheus metrics and alerts 