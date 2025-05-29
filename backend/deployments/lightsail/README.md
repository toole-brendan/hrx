# HandReceipt AWS Lightsail Deployment Guide

This comprehensive guide covers deploying, managing, and maintaining the HandReceipt Go backend on AWS Lightsail.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Deployment](#initial-deployment)
- [Accessing Your Server](#accessing-your-server)
- [Database Management](#database-management)
- [Service Management](#service-management)
- [Configuration Updates](#configuration-updates)
- [Monitoring and Logs](#monitoring-and-logs)
- [Backup and Recovery](#backup-and-recovery)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Prerequisites

### 1. AWS CLI Installation
```bash
# macOS
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
```

### 2. SSH Key Setup
```bash
# Create SSH key for Lightsail (if not using existing)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/handreceipt-key

# Set proper permissions
chmod 400 ~/.ssh/handreceipt-key
```

## Initial Deployment

### Step 1: Create Lightsail Instance

```bash
# Using AWS Console (Recommended for first time)
1. Go to AWS Lightsail Console
2. Click "Create instance"
3. Select:
   - Region: us-east-1 (or your preferred region)
   - Platform: Linux/Unix
   - Blueprint: Ubuntu 20.04 LTS
   - Instance plan: $10/month (2 GB RAM) minimum
   - Name: handreceipt-primary
4. Add your SSH key
5. Create instance
```

### Step 2: Initial Server Setup

```bash
# SSH into your new instance
ssh -i ~/.ssh/handreceipt-key ubuntu@YOUR_INSTANCE_IP

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for docker group to take effect
exit
ssh -i ~/.ssh/handreceipt-key ubuntu@YOUR_INSTANCE_IP
```

### Step 3: Deploy Application

```bash
# Create application directory
sudo mkdir -p /opt/handreceipt
sudo chown -R ubuntu:ubuntu /opt/handreceipt

# Upload your application files
# From your local machine:
cd backend
tar -czf deployment.tar.gz docker-compose.production.yml Dockerfile Dockerfile.worker \
    deployments/lightsail/nginx.conf deployments/lightsail/prometheus.yml \
    cmd internal go.mod go.sum configs migrations

scp -i ~/.ssh/handreceipt-key deployment.tar.gz ubuntu@YOUR_INSTANCE_IP:/tmp/

# Back on the server:
cd /opt/handreceipt
tar -xzf /tmp/deployment.tar.gz
mv docker-compose.production.yml docker-compose.yml
```

### Step 4: Configure Environment

```bash
# Create configuration file
cat > /opt/handreceipt/configs/config.yaml << 'EOF'
# HandReceipt Backend Configuration

# Server configuration
server:
  port: "8080"
  host: "0.0.0.0"
  environment: "production"

# Database configuration
database:
  host: "postgres"
  port: 5432
  user: "handreceipt"
  password: "handreceipt123"  # CHANGE THIS
  name: "handreceipt"
  ssl_mode: "disable"

# ImmuDB configuration
immudb:
  host: "immudb"
  port: 3322
  username: "immudb"
  password: "immudb"
  database: "defaultdb"
  enabled: true

# MinIO configuration
minio:
  endpoint: "minio:9000"
  access_key_id: "handreceipt-minio"
  secret_access_key: "CHANGE_THIS_SECRET"  # CHANGE THIS
  use_ssl: false
  bucket_name: "handreceipt"
  enabled: true

# JWT configuration
jwt:
  secret_key: "CHANGE_THIS_JWT_SECRET"  # CHANGE THIS
  access_expiry: "24h"
  refresh_expiry: "168h"
EOF
```

### Step 5: Start Services

```bash
# Build and start all services
cd /opt/handreceipt
sudo docker-compose build
sudo docker-compose up -d

# Check status
sudo docker-compose ps

# View logs
sudo docker-compose logs -f app
```

## Accessing Your Server

### SSH Access
```bash
# Basic SSH
ssh -i ~/.ssh/handreceipt-key ubuntu@YOUR_INSTANCE_IP

# SSH with port forwarding (useful for database access)
ssh -i ~/.ssh/handreceipt-key -L 5432:localhost:5432 ubuntu@YOUR_INSTANCE_IP
```

### API Endpoints
- Main API: `http://YOUR_INSTANCE_IP:8080`
- Health Check: `http://YOUR_INSTANCE_IP:8080/health`
- MinIO Console: `http://YOUR_INSTANCE_IP:9001`
- Grafana: `http://YOUR_INSTANCE_IP:3000`

## Database Management

### Accessing PostgreSQL

```bash
# Method 1: Direct access from server
sudo docker exec -it handreceipt_postgres_1 psql -U handreceipt -d handreceipt

# Method 2: Using psql with password
sudo docker exec -it handreceipt_postgres_1 \
  psql postgresql://handreceipt:handreceipt123@localhost:5432/handreceipt

# Method 3: From your local machine (requires SSH tunnel)
# First, create SSH tunnel:
ssh -i ~/.ssh/handreceipt-key -L 5432:localhost:5432 ubuntu@YOUR_INSTANCE_IP

# Then in another terminal:
psql -h localhost -p 5432 -U handreceipt -d handreceipt
```

### Common Database Operations

```sql
-- View all tables
\dt

-- Describe a table
\d users

-- View data
SELECT * FROM users;
SELECT * FROM properties;
SELECT * FROM transfers;

-- Check database size
SELECT pg_database_size('handreceipt');

-- View active connections
SELECT pid, usename, application_name, client_addr, state 
FROM pg_stat_activity 
WHERE datname = 'handreceipt';

-- Exit psql
\q
```

### Database Backup

```bash
# Backup database
sudo docker exec handreceipt_postgres_1 \
  pg_dump -U handreceipt handreceipt > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup with compression
sudo docker exec handreceipt_postgres_1 \
  pg_dump -U handreceipt handreceipt | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Automated backup script
cat > /opt/handreceipt/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/handreceipt/backups"
mkdir -p $BACKUP_DIR
DATE=$(date +%Y%m%d_%H%M%S)

# Backup PostgreSQL
docker exec handreceipt_postgres_1 pg_dump -U handreceipt handreceipt | \
  gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# Keep only last 7 days
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: postgres_$DATE.sql.gz"
EOF

chmod +x /opt/handreceipt/backup.sh

# Add to crontab for daily backups at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/handreceipt/backup.sh") | crontab -
```

### Database Restore

```bash
# Restore from backup
gunzip < backup_20240529_120000.sql.gz | \
  sudo docker exec -i handreceipt_postgres_1 psql -U handreceipt -d handreceipt

# Or without compression
sudo docker exec -i handreceipt_postgres_1 \
  psql -U handreceipt -d handreceipt < backup.sql
```

### Modifying Database Schema

```bash
# Connect to database
sudo docker exec -it handreceipt_postgres_1 psql -U handreceipt -d handreceipt

# Add a new column
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

# Create an index
CREATE INDEX idx_properties_status ON properties(current_status);

# Add a constraint
ALTER TABLE transfers ADD CONSTRAINT check_dates 
  CHECK (resolved_date >= request_date);
```

## Service Management

### Starting and Stopping Services

```bash
# Stop all services
cd /opt/handreceipt
sudo docker-compose down

# Start all services
sudo docker-compose up -d

# Restart a specific service
sudo docker-compose restart app

# Stop a specific service
sudo docker-compose stop postgres

# Start a specific service
sudo docker-compose start postgres

# View service status
sudo docker-compose ps
```

### Updating the Application

```bash
# 1. Update code on your local machine
# 2. Create new deployment package
cd backend
tar -czf deployment-update.tar.gz docker-compose.production.yml Dockerfile \
    Dockerfile.worker cmd internal go.mod go.sum configs migrations

# 3. Upload to server
scp -i ~/.ssh/handreceipt-key deployment-update.tar.gz ubuntu@YOUR_INSTANCE_IP:/tmp/

# 4. On the server, backup current version
cd /opt/handreceipt
sudo tar -czf backup-$(date +%Y%m%d).tar.gz .

# 5. Extract update
sudo tar -xzf /tmp/deployment-update.tar.gz

# 6. Rebuild and restart
sudo docker-compose build app worker
sudo docker-compose up -d app worker

# 7. Check logs
sudo docker-compose logs -f app
```

## Configuration Updates

### Updating Environment Variables

```bash
# Edit config file
sudo nano /opt/handreceipt/configs/config.yaml

# After making changes, rebuild and restart
cd /opt/handreceipt
sudo docker-compose build app worker
sudo docker-compose up -d app worker
```

### Common Configuration Changes

```yaml
# Change database password
database:
  password: "new_secure_password"

# Enable/disable services
immudb:
  enabled: false

# Change JWT expiry
jwt:
  access_expiry: "12h"
  refresh_expiry: "7d"
```

## Monitoring and Logs

### Viewing Logs

```bash
# View all logs
sudo docker-compose logs

# View specific service logs
sudo docker-compose logs app
sudo docker-compose logs postgres

# Follow logs in real-time
sudo docker-compose logs -f app

# View last 100 lines
sudo docker-compose logs --tail=100 app

# View logs since a specific time
sudo docker-compose logs --since="2024-05-29T12:00:00" app
```

### Monitoring Resources

```bash
# Check disk usage
df -h

# Check memory usage
free -h

# Check Docker resource usage
sudo docker stats

# Check specific container
sudo docker stats handreceipt_app_1
```

### Setting Up Alerts

```bash
# Create monitoring script
cat > /opt/handreceipt/monitor.sh << 'EOF'
#!/bin/bash

# Check if app is running
if ! docker ps | grep -q handreceipt_app_1; then
    echo "ALERT: App container is not running!" | mail -s "HandReceipt Alert" your-email@example.com
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "ALERT: Disk usage is at ${DISK_USAGE}%!" | mail -s "HandReceipt Disk Alert" your-email@example.com
fi
EOF

chmod +x /opt/handreceipt/monitor.sh

# Add to crontab (every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/handreceipt/monitor.sh") | crontab -
```

## Backup and Recovery

### Full System Backup

```bash
# Create comprehensive backup script
cat > /opt/handreceipt/full-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/handreceipt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

echo "Starting full backup..."

# 1. Database backup
docker exec handreceipt_postgres_1 pg_dump -U handreceipt handreceipt | \
  gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# 2. Configuration backup
tar -czf $BACKUP_DIR/config_$DATE.tar.gz configs/

# 3. Docker volumes backup
docker run --rm \
  -v handreceipt_postgres_data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/postgres_volume_$DATE.tar.gz /data

# 4. Application code backup
tar -czf $BACKUP_DIR/app_$DATE.tar.gz --exclude=backups .

echo "Backup completed at $BACKUP_DIR"
ls -lh $BACKUP_DIR/*$DATE*
EOF

chmod +x /opt/handreceipt/full-backup.sh
```

### Disaster Recovery

```bash
# Complete recovery procedure
# 1. Create new Lightsail instance
# 2. Install Docker and Docker Compose (see Initial Setup)
# 3. Restore from backup:

# Copy backups to new server
scp -i ~/.ssh/handreceipt-key /path/to/backups/* ubuntu@NEW_IP:/tmp/

# On new server:
cd /opt/handreceipt
tar -xzf /tmp/app_20240529.tar.gz
tar -xzf /tmp/config_20240529.tar.gz

# Start services
docker-compose up -d

# Restore database
gunzip < /tmp/postgres_20240529.sql.gz | \
  docker exec -i handreceipt_postgres_1 psql -U handreceipt -d handreceipt
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Services Won't Start
```bash
# Check logs
sudo docker-compose logs

# Check if ports are in use
sudo netstat -tlnp | grep -E '(8080|5432|3322|9000)'

# Clean restart
sudo docker-compose down -v
sudo docker system prune -a
sudo docker-compose up -d
```

#### 2. Database Connection Failed
```bash
# Check if PostgreSQL is running
sudo docker ps | grep postgres

# Test connection
sudo docker exec handreceipt_postgres_1 pg_isready -U handreceipt

# Check PostgreSQL logs
sudo docker logs handreceipt_postgres_1

# Verify password in config matches docker-compose.yml
grep password /opt/handreceipt/configs/config.yaml
grep POSTGRES_PASSWORD /opt/handreceipt/docker-compose.yml
```

#### 3. Out of Disk Space
```bash
# Check disk usage
df -h

# Clean Docker
sudo docker system prune -a --volumes

# Remove old logs
sudo find /var/lib/docker/containers -name "*.log" -exec truncate -s 0 {} \;

# Remove old backups
find /opt/handreceipt/backups -name "*.gz" -mtime +30 -delete
```

#### 4. High Memory Usage
```bash
# Check memory usage by container
sudo docker stats --no-stream

# Restart memory-heavy services
sudo docker-compose restart postgres

# Add memory limits to docker-compose.yml
# Under each service:
deploy:
  resources:
    limits:
      memory: 512M
```

### Debug Mode

```bash
# Run app in debug mode
cd /opt/handreceipt
sudo docker-compose stop app
sudo docker-compose run --rm app ./handreceipt

# Enable verbose logging
# Edit configs/config.yaml:
logging:
  level: "debug"
```

## Security

### Firewall Configuration

```bash
# Check current rules
sudo ufw status

# Allow only necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 8080/tcp  # API (remove in production, use nginx)
sudo ufw enable
```

### SSL Certificate Setup

```bash
# Install Certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot certonly --standalone -d your-domain.com

# Update nginx configuration to use SSL
# Edit nginx.conf to include SSL settings
```

### Security Checklist

- [ ] Change all default passwords
- [ ] Set up firewall rules
- [ ] Enable SSL/TLS
- [ ] Disable root SSH access
- [ ] Set up fail2ban
- [ ] Regular security updates
- [ ] Monitor logs for suspicious activity
- [ ] Backup encryption

## Performance Tuning

### PostgreSQL Optimization

```bash
# Edit PostgreSQL configuration
sudo docker exec -it handreceipt_postgres_1 bash
vi /var/lib/postgresql/data/postgresql.conf

# Key settings to adjust:
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
work_mem = 4MB
```

### Application Optimization

```yaml
# In configs/config.yaml
database:
  max_open_conns: 25
  max_idle_conns: 5
  conn_max_lifetime: "5m"
```

## Useful Commands Reference

```bash
# Quick health check
curl http://localhost:8080/health

# View running containers
sudo docker ps

# Database quick connect
sudo docker exec -it handreceipt_postgres_1 psql -U handreceipt -d handreceipt

# View recent logs
sudo docker-compose logs --tail=50 -f app

# Restart everything
cd /opt/handreceipt && sudo docker-compose restart

# Check service resource usage
sudo docker stats --no-stream

# Backup database quickly
sudo docker exec handreceipt_postgres_1 pg_dump -U handreceipt handreceipt | gzip > quick-backup.sql.gz
```

## Support and Resources

- AWS Lightsail Documentation: https://lightsail.aws.amazon.com/ls/docs/
- Docker Documentation: https://docs.docker.com/
- PostgreSQL Documentation: https://www.postgresql.org/docs/
- HandReceipt Repository: [Your Repository URL]

For issues specific to this deployment, check the logs first:
```bash
sudo docker-compose logs app | grep ERROR
``` 