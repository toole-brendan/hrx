# HandReceipt AWS Lightsail Deployment Guide

## Your Instance Has Been Created! 🎉

**Instance Details:**
- **Static IP:** `44.193.254.155`
- **Instance Name:** handreceipt-primary
- **Region:** us-east-1

## Complete the Deployment

### Step 1: Access Your Instance via Lightsail Console

1. Go to the [AWS Lightsail Console](https://lightsail.aws.amazon.com/)
2. Click on your instance named `handreceipt-primary`
3. Click the "Connect using SSH" button to open the browser-based SSH terminal

### Step 2: Upload the Deployment Package

Since SSH key access is having issues, we'll use the browser method:

1. In your local terminal, upload the deployment package to a temporary location:
   ```bash
   # From the backend directory
   curl -F "file=@deployment.tar.gz" https://file.io
   ```
   This will give you a download URL.

2. In the Lightsail SSH browser window, download the file:
   ```bash
   cd /home/ubuntu
   wget <FILE.IO_URL> -O deployment.tar.gz
   ```

### Step 3: Run the Setup Script

In the Lightsail SSH browser window, run:

```bash
# Create the application directory
sudo mkdir -p /opt/handreceipt
sudo chown ubuntu:ubuntu /opt/handreceipt

# Move and extract the deployment
sudo mv deployment.tar.gz /opt/handreceipt/
cd /opt/handreceipt
tar -xzf deployment.tar.gz

# Run the setup
chmod +x deployments/lightsail/setup-instance.sh
sudo ./deployments/lightsail/setup-instance.sh
```

### Step 4: Verify the Deployment

After the setup completes, verify everything is running:

```bash
docker-compose ps
```

You should see all services (app, postgres, minio, nginx) running.

### Step 5: Test the API

```bash
# Test health endpoint
curl http://localhost:8080/health

# Test login (from outside)
curl http://44.193.254.155:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```

## Access Points

- **API:** http://44.193.254.155:8080
- **MinIO Console:** http://44.193.254.155:9001
  - Username: handreceipt-minio
  - Password: (check production.env)

## Next Steps

1. **Set up your domain:**
   - Point your domain to `44.193.254.155`
   - Update the DOMAIN variable in `/opt/handreceipt/.env`

2. **Enable SSL:**
   ```bash
   sudo certbot --nginx -d yourdomain.com
   ```

3. **Change default passwords:**
   - Login to the API and change the admin password immediately
   - Update database passwords in production if needed

4. **Set up backups:**
   - The backup script is at `/opt/handreceipt/backup.sh`
   - It's already scheduled to run nightly at 2 AM

## Troubleshooting

### Check logs:
```bash
docker-compose logs -f app
docker-compose logs -f postgres
```

### Restart services:
```bash
cd /opt/handreceipt
docker-compose restart
```

### View environment variables:
```bash
cat /opt/handreceipt/.env
```

## Security Checklist

- [ ] Changed admin password
- [ ] Set up SSL certificate
- [ ] Configured firewall (ufw is already set up)
- [ ] Set up monitoring alerts
- [ ] Tested backup and restore

## Support

If you encounter any issues:
1. Check the logs: `docker-compose logs`
2. Verify all services are running: `docker-compose ps`
3. Check disk space: `df -h`
4. Check memory: `free -m` 