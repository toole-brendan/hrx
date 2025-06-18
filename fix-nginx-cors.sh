#!/bin/bash

echo "🔧 Fixing nginx CORS configuration"
echo "=================================="

# Create a backup of current nginx config
echo "1. Backing up current nginx configuration..."
sudo cp /etc/nginx/sites-available/api.handreceipt.com /etc/nginx/sites-available/api.handreceipt.com.backup

# Create new nginx config without CORS headers (let backend handle it)
echo "2. Creating new nginx configuration..."
sudo tee /etc/nginx/sites-available/api.handreceipt.com > /dev/null << 'NGINX_EOF'
# HandReceipt API Server Configuration
server {
    listen 80;
    server_name api.handreceipt.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name api.handreceipt.com;
    
    # SSL configuration (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/api.handreceipt.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.handreceipt.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Logging
    access_log /var/log/nginx/api.handreceipt.com.access.log;
    error_log /var/log/nginx/api.handreceipt.com.error.log;
    
    # Proxy settings
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Body size (for file uploads)
    client_max_body_size 100M;
    
    # API endpoints - NO CORS headers here, backend handles it
    location /api/ {
        # Remove /api prefix when proxying to backend
        rewrite ^/api/(.*) /$1 break;
        
        proxy_pass http://localhost:8080;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8080/health;
        access_log off;
    }
    
    # Root location
    location / {
        return 404;
    }
}
NGINX_EOF

echo "3. Testing nginx configuration..."
if sudo nginx -t; then
    echo "   ✅ Configuration is valid"
else
    echo "   ❌ Configuration has errors. Restoring backup..."
    sudo cp /etc/nginx/sites-available/api.handreceipt.com.backup /etc/nginx/sites-available/api.handreceipt.com
    exit 1
fi

echo "4. Reloading nginx..."
sudo systemctl reload nginx

echo "5. Testing CORS headers..."
sleep 2
CORS_TEST=$(curl -s -I -H "Origin: https://www.handreceipt.com" https://api.handreceipt.com/api/auth/me 2>/dev/null | grep -i "access-control-allow-origin")
if [ -n "$CORS_TEST" ]; then
    echo "   ✅ CORS headers present:"
    echo "   $CORS_TEST"
else
    echo "   ⚠️  No CORS headers found. Backend might need restart."
fi

echo -e "\n✅ nginx configuration updated!"
echo "   - Removed CORS headers from nginx (backend handles them)"
echo "   - Kept all other proxy settings intact"
echo ""
echo "If CORS is still not working, restart the backend:"
echo "   cd /opt/handreceipt/deployments/lightsail"
echo "   sudo docker-compose restart app" 