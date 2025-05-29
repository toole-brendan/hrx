#!/bin/bash

# HandReceipt Instance Setup Script
# This runs on the Lightsail instance after deployment

set -e

echo "Setting up HandReceipt on Lightsail instance..."

# Create necessary directories
mkdir -p /opt/handreceipt/data/{postgres,immudb,minio}
mkdir -p /opt/handreceipt/backups
mkdir -p /opt/handreceipt/logs

# Set proper permissions
chown -R ubuntu:ubuntu /opt/handreceipt

# Check if production.env exists and use it
if [ -f /opt/handreceipt/deployments/lightsail/production.env ]; then
    echo "Using existing production.env file..."
    # Copy to BOTH locations where it's needed
    cp /opt/handreceipt/deployments/lightsail/production.env /opt/handreceipt/.env
    cp /opt/handreceipt/deployments/lightsail/production.env /opt/handreceipt/deployments/lightsail/.env
else
    echo "Creating new environment file..."
    # Create environment file
    cat > /opt/handreceipt/.env << EOF
# Database
POSTGRES_DB=handreceipt
POSTGRES_USER=handreceipt
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# ImmuDB
IMMUDB_ADMIN_PASSWORD=$(openssl rand -base64 32)

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$(openssl rand -base64 32)

# JWT
JWT_SECRET_KEY=$(openssl rand -base64 64)

# Domain (update this after setting up DNS)
DOMAIN=handreceipt.example.com
EOF
fi

# Load environment variables
source /opt/handreceipt/.env

# Update docker-compose.yml with production values
cd /opt/handreceipt

# Use the Lightsail-specific docker-compose
cp deployments/lightsail/docker-compose.yml docker-compose.yml

# Create nginx configuration without SSL initially
cat > deployments/lightsail/nginx-nossl.conf << 'NGINX_EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Backend API
    upstream handreceipt-api {
        server app:8080;
    }

    server {
        listen 80;
        server_name _;

        # API endpoints
        location /api {
            proxy_pass http://handreceipt-api;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Health check
        location /health {
            proxy_pass http://handreceipt-api/health;
            access_log off;
        }

        # Root redirect
        location / {
            return 301 /api;
        }
    }
}
NGINX_EOF

# Use the non-SSL nginx config initially
cp deployments/lightsail/nginx-nossl.conf deployments/lightsail/nginx.conf

# Create Prometheus configuration
mkdir -p /opt/handreceipt/deployments/lightsail
cat > /opt/handreceipt/deployments/lightsail/prometheus.yml << 'PROM_EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'handreceipt-api'
    static_configs:
      - targets: ['app:8080']
  
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
PROM_EOF

# Build and start the application
echo "Building and starting HandReceipt..."
cd /opt/handreceipt
docker-compose build
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 30

# Check service health
docker-compose ps

# Create backup script
cat > /opt/handreceipt/backup.sh << 'BACKUP_EOF'
#!/bin/bash
# HandReceipt Backup Script

BACKUP_DIR="/opt/handreceipt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Load environment
source /opt/handreceipt/.env

# Backup PostgreSQL
docker exec handreceipt-postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# Backup ImmuDB
docker exec handreceipt-immudb immuadmin database list
docker exec handreceipt-immudb immuadmin database export defaultdb > $BACKUP_DIR/immudb_$DATE.bak

# Backup MinIO data
docker run --rm \
  -v handreceipt_minio_data:/data \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/minio_$DATE.tar.gz /data

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.bak" -mtime +7 -delete

echo "Backup completed: $DATE"
BACKUP_EOF

chmod +x /opt/handreceipt/backup.sh

# Setup cron for backups
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/handreceipt/backup.sh >> /opt/handreceipt/logs/backup.log 2>&1") | crontab -

# Create systemd service for docker-compose
cat > /etc/systemd/system/handreceipt.service << 'SYSTEMD_EOF'
[Unit]
Description=HandReceipt Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/handreceipt
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Enable the service
systemctl daemon-reload
systemctl enable handreceipt.service

# Setup log rotation
cat > /etc/logrotate.d/handreceipt << 'LOGROTATE_EOF'
/opt/handreceipt/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ubuntu ubuntu
}
LOGROTATE_EOF

# Print summary
echo "==========================================="
echo "HandReceipt Setup Complete!"
echo "==========================================="
echo ""
echo "Services running:"
docker-compose ps
echo ""
echo "Environment file: /opt/handreceipt/.env"
echo "Backup script: /opt/handreceipt/backup.sh"
echo ""
echo "Next steps:"
echo "1. Update DOMAIN in .env file"
echo "2. Point your domain to this server"
echo "3. Run: sudo certbot --nginx -d yourdomain.com"
echo "4. Access the API at http://$(curl -s ifconfig.me):8080"
echo ""
echo "Default admin credentials:"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "⚠️  IMPORTANT: Change the admin password immediately!"
echo "" 