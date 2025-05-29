# Troubleshooting Environment Variables on Lightsail

## Problem
The application is not reading environment variables when deployed on AWS Lightsail.

## Root Cause
The docker-compose file expects the `.env` file to be in `/opt/handreceipt/deployments/lightsail/` but the setup script was only copying it to `/opt/handreceipt/.env`.

## Quick Fix

SSH into your Lightsail instance and run:

```bash
# Navigate to the application directory
cd /opt/handreceipt

# Copy the environment file to the correct location
sudo cp deployments/lightsail/production.env deployments/lightsail/.env

# Restart the services
cd deployments/lightsail
sudo docker-compose down
sudo docker-compose up -d

# Check if services are running
sudo docker-compose ps

# Check application logs
sudo docker-compose logs app
```

## Permanent Fix

Use the provided fix script:

```bash
# Upload the fix script to your server
scp -i ~/.ssh/handreceipt-key-us-east-1 backend/deployments/lightsail/fix-env-vars.sh ubuntu@YOUR_IP:/opt/handreceipt/

# SSH into the server
ssh -i ~/.ssh/handreceipt-key-us-east-1 ubuntu@YOUR_IP

# Run the fix script
cd /opt/handreceipt
chmod +x fix-env-vars.sh
sudo ./fix-env-vars.sh
```

## Understanding the Environment Variable Setup

1. **Go Application Configuration**:
   - Uses Viper for configuration management
   - Environment variable prefix: `HANDRECEIPT_`
   - Example: `HANDRECEIPT_DATABASE_HOST` maps to `database.host` in config

2. **Docker Compose**:
   - Uses `env_file: .env` directive
   - Expects `.env` file in the same directory as docker-compose.yml
   - In production: `/opt/handreceipt/deployments/lightsail/.env`

3. **File Locations**:
   - Production env template: `backend/deployments/lightsail/production.env`
   - Active env file: `/opt/handreceipt/deployments/lightsail/.env`
   - Docker compose: `/opt/handreceipt/deployments/lightsail/docker-compose.yml`

## Verifying Environment Variables

1. **Check if .env file exists**:
   ```bash
   ls -la /opt/handreceipt/deployments/lightsail/.env
   ```

2. **Verify environment variables are loaded in container**:
   ```bash
   sudo docker-compose exec app env | grep HANDRECEIPT
   ```

3. **Check application logs**:
   ```bash
   sudo docker-compose logs app | grep -i "config\|environment"
   ```

4. **Test the API**:
   ```bash
   curl http://localhost:8080/health
   ```

## Common Issues

### Issue 1: Wrong Dockerfile Version
- You have multiple Dockerfiles with different Go versions
- Ensure docker-compose uses the correct one: `deployments/docker/Dockerfile`

### Issue 2: Missing Environment Variables
- Check that all required variables are in production.env
- Required prefixes: `HANDRECEIPT_`

### Issue 3: Permission Issues
- Ensure files are owned by ubuntu user
- Run: `sudo chown -R ubuntu:ubuntu /opt/handreceipt`

### Issue 4: Docker Not Reading .env
- Ensure .env is in the same directory as docker-compose.yml
- Check docker-compose syntax: `env_file: .env`

## Environment Variable Reference

```env
# JWT Configuration
HANDRECEIPT_JWT_SECRET_KEY=your-secret-key

# Database
HANDRECEIPT_DATABASE_HOST=postgres
HANDRECEIPT_DATABASE_PORT=5432
HANDRECEIPT_DATABASE_USER=handreceipt
HANDRECEIPT_DATABASE_PASSWORD=your-password
HANDRECEIPT_DATABASE_NAME=handreceipt

# ImmuDB
HANDRECEIPT_IMMUDB_HOST=immudb
HANDRECEIPT_IMMUDB_PORT=3322
HANDRECEIPT_IMMUDB_USERNAME=immudb
HANDRECEIPT_IMMUDB_PASSWORD=your-password
HANDRECEIPT_IMMUDB_DATABASE=defaultdb
HANDRECEIPT_IMMUDB_ENABLED=true

# MinIO
HANDRECEIPT_MINIO_ENDPOINT=minio:9000
HANDRECEIPT_MINIO_ACCESS_KEY_ID=your-access-key
HANDRECEIPT_MINIO_SECRET_ACCESS_KEY=your-secret-key
HANDRECEIPT_MINIO_USE_SSL=false
HANDRECEIPT_MINIO_BUCKET_NAME=handreceipt
HANDRECEIPT_MINIO_ENABLED=true

# Server
HANDRECEIPT_SERVER_PORT=8080
HANDRECEIPT_SERVER_ENVIRONMENT=production
``` 