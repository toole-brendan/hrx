# HandReceipt AWS Lightsail Deployment

This directory contains everything needed to deploy the HandReceipt Go backend to AWS Lightsail.

## Prerequisites

1. **AWS CLI installed and configured**
   ```bash
   # Install AWS CLI
   curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
   sudo installer -pkg AWSCLIV2.pkg -target /
   
   # Configure AWS CLI
   aws configure
   ```

2. **AWS Lightsail SSH Key**
   - Go to AWS Lightsail console
   - Navigate to "Account" → "SSH keys"
   - Download the default key for your region (e.g., `LightsailDefaultKey-us-east-1.pem`)
   - Save it to `~/.ssh/` and set permissions: `chmod 400 ~/.ssh/LightsailDefaultKey-us-east-1.pem`

## Quick Deployment

### Step 1: Customize Environment Variables

1. Copy the production environment template:
   ```bash
   cp production.env production.env.local
   ```

2. Edit `production.env` and replace all `CHANGE_THIS_*` values with secure passwords:
   ```bash
   # Generate secure passwords
   openssl rand -base64 32  # For JWT_SECRET_KEY
   openssl rand -base64 16  # For database passwords
   ```

### Step 2: Deploy to AWS Lightsail

```bash
# Deploy the application
./deploy.sh

# Check deployment status
./deploy.sh status

# Destroy instance (if needed)
./deploy.sh destroy
```

## What Gets Deployed

The deployment creates:

- **AWS Lightsail Instance**: Ubuntu 20.04 with Docker and Docker Compose
- **Go Backend API**: Your HandReceipt application
- **PostgreSQL Database**: For relational data storage
- **ImmuDB**: For immutable ledger records
- **MinIO**: For object storage
- **NGINX**: Reverse proxy with SSL termination
- **Prometheus**: Metrics collection
- **Grafana**: Monitoring dashboards

## Architecture

```
Internet → NGINX (80/443) → Go API (8080) → PostgreSQL (5432)
                                        → ImmuDB (3322)
                                        → MinIO (9000)
```

## Accessing Your Application

After deployment, you'll have access to:

- **API**: `http://YOUR_INSTANCE_IP/api/`
- **Health Check**: `http://YOUR_INSTANCE_IP/health`
- **Grafana**: `http://YOUR_INSTANCE_IP:3000` (admin/admin)
- **MinIO Console**: `http://YOUR_INSTANCE_IP:9001`

## Post-Deployment Steps

### 1. Update DNS (Optional)
Point your domain to the instance IP address:
```bash
# Get instance IP
./deploy.sh status
```

### 2. Setup SSL Certificates (Recommended)
Replace self-signed certificates with proper SSL certificates:

```bash
# SSH into your instance
ssh -i ~/.ssh/LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_INSTANCE_IP

# Install Certbot
sudo apt update
sudo apt install certbot

# Get SSL certificate (replace your-domain.com)
sudo certbot certonly --standalone -d your-domain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem /home/ubuntu/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem /home/ubuntu/ssl/key.pem
sudo chown ubuntu:ubuntu /home/ubuntu/ssl/*.pem

# Restart NGINX
docker-compose restart nginx
```

### 3. Setup Monitoring
Access Grafana at `http://YOUR_INSTANCE_IP:3000`:
- Username: `admin`
- Password: `admin` (change on first login)

### 4. Backup Strategy
Set up regular backups for your data:

```bash
# Create backup script
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker exec handreceipt-postgres pg_dump -U handreceipt handreceipt > backup_postgres_$DATE.sql
docker exec handreceipt-immudb immuadmin backup > backup_immudb_$DATE.tar.gz
EOF

chmod +x backup.sh

# Add to crontab for daily backups
echo "0 2 * * * /home/ubuntu/backup.sh" | crontab -
```

## Troubleshooting

### Check Service Status
```bash
# SSH into instance
ssh -i ~/.ssh/LightsailDefaultKey-us-east-1.pem ubuntu@YOUR_INSTANCE_IP

# Check all services
docker-compose ps

# Check logs
docker-compose logs app
docker-compose logs postgres
docker-compose logs nginx
```

### Common Issues

1. **Services not starting**: Check logs and ensure environment variables are set correctly
2. **SSL certificate errors**: Verify certificate files exist and have correct permissions
3. **Database connection issues**: Ensure PostgreSQL is healthy and credentials are correct
4. **API not responding**: Check if the Go application started successfully

### Resource Monitoring
Monitor your instance resources:
```bash
# Check disk usage
df -h

# Check memory usage
free -h

# Check running processes
htop
```

## Scaling Considerations

For production use, consider:

1. **Upgrade Instance Size**: Use a larger Lightsail bundle for better performance
2. **Load Balancer**: Add a Lightsail load balancer for high availability
3. **Database Backup**: Set up automated database backups
4. **CDN**: Use CloudFront for static asset delivery
5. **Monitoring**: Set up CloudWatch alarms for critical metrics

## Security Best Practices

1. **Change Default Passwords**: Update all default passwords in `production.env`
2. **Firewall Rules**: Only open necessary ports
3. **SSL Certificates**: Use proper SSL certificates, not self-signed
4. **Regular Updates**: Keep the system and Docker images updated
5. **Access Control**: Limit SSH access to specific IP addresses

## Cost Estimation

AWS Lightsail pricing (as of 2024):
- **Nano (512MB RAM)**: $3.50/month
- **Micro (1GB RAM)**: $5.00/month
- **Small (2GB RAM)**: $10.00/month

Additional costs:
- **Static IP**: $2.00/month (optional)
- **Load Balancer**: $18.00/month (optional)
- **Backup Storage**: $0.05/GB/month

## Support

For issues with this deployment:
1. Check the troubleshooting section above
2. Review AWS Lightsail documentation
3. Check the HandReceipt repository issues

## Files in This Directory

- `docker-compose.yml`: Main deployment configuration
- `nginx.conf`: NGINX reverse proxy configuration
- `prometheus.yml`: Monitoring configuration
- `production.env`: Environment variables template
- `deploy.sh`: Automated deployment script
- `ssl/`: SSL certificates directory
- `README.md`: This documentation 