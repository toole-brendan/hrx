#!/bin/bash
# Fix nginx and SSL configuration for api.handreceipt.com

set -e

echo "🔧 Fixing Nginx and SSL Configuration"
echo "====================================="

# Install nginx if not installed
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing nginx..."
    sudo apt update
    sudo apt install -y nginx
fi

# Create nginx configuration for api.handreceipt.com
echo "📝 Creating nginx configuration..."
sudo tee /etc/nginx/sites-available/api.handreceipt.com > /dev/null << 'NGINX_EOF'
server {
    listen 80;
    server_name api.handreceipt.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

# Enable the site
echo "🔗 Enabling nginx site..."
sudo ln -sf /etc/nginx/sites-available/api.handreceipt.com /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "✅ Testing nginx configuration..."
sudo nginx -t

# Restart nginx
echo "🔄 Restarting nginx..."
sudo systemctl restart nginx
sudo systemctl enable nginx

# Check if nginx is running
if sudo systemctl is-active --quiet nginx; then
    echo "✅ Nginx is running"
else
    echo "❌ Nginx failed to start"
    sudo systemctl status nginx
    exit 1
fi

# Install certbot if not installed
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing certbot..."
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Get SSL certificate
echo "🔒 Setting up SSL certificate..."
sudo certbot --nginx -d api.handreceipt.com --non-interactive --agree-tos --email noreply@handreceipt.com --redirect

# Set up auto-renewal
echo "🔄 Setting up SSL auto-renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

echo ""
echo "✅ Configuration complete!"
echo ""
echo "Test URLs:"
echo "  - http://api.handreceipt.com/health"
echo "  - https://api.handreceipt.com/health"
echo ""
echo "📊 Status:"
sudo systemctl status nginx --no-pager
echo ""
echo "🔍 To view nginx logs: sudo tail -f /var/log/nginx/error.log" 