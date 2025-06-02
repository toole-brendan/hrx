#!/bin/bash

# Manual PUB LOG data deployment script
# This uploads the PUB LOG data files to your production server

set -e

# Configuration
LIGHTSAIL_IP="44.193.254.155"
SSH_KEY_PATH="~/.ssh/lightsail_key"  # Update this path to your SSH key

echo "🚀 Deploying PUB LOG data to production..."

# Check if data files exist
if [ ! -d "backend/internal/publog/data" ] || [ -z "$(ls -A backend/internal/publog/data/*.txt 2>/dev/null)" ]; then
    echo "❌ No PUB LOG data files found in backend/internal/publog/data/"
    exit 1
fi

echo "📦 Creating PUB LOG data package..."
tar czf /tmp/publog_data_manual.tar.gz -C backend/internal/publog/data *.txt

echo "📤 Uploading to production server..."
scp -i $SSH_KEY_PATH /tmp/publog_data_manual.tar.gz ubuntu@$LIGHTSAIL_IP:/tmp/

echo "📥 Extracting on production server..."
ssh -i $SSH_KEY_PATH ubuntu@$LIGHTSAIL_IP << 'EOF'
    set -e
    
    echo "🔄 Extracting PUB LOG data..."
    cd /opt/handreceipt
    
    # Create backup of existing data if any
    if [ -d "backend/internal/publog/data" ] && [ "$(ls -A backend/internal/publog/data/*.txt 2>/dev/null)" ]; then
        echo "📦 Backing up existing data..."
        sudo tar czf /tmp/publog_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C backend/internal/publog/data *.txt
    fi
    
    # Extract new data
    sudo mkdir -p backend/internal/publog/data
    sudo tar xzf /tmp/publog_data_manual.tar.gz -C backend/internal/publog/data/
    sudo chown -R ubuntu:ubuntu backend/internal/publog/data/
    
    echo "✅ PUB LOG data deployed"
    echo "📊 Data files:"
    ls -lh backend/internal/publog/data/*.txt | head -5
    
    # Restart the backend service
    echo "🔄 Restarting backend service..."
    cd backend
    sudo docker-compose restart app
    
    echo "⏳ Waiting for service to be ready..."
    sleep 10
    
    # Test the service
    if curl -s -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ Backend service is healthy"
    else
        echo "❌ Backend health check failed"
        sudo docker-compose logs --tail=50 app
    fi
EOF

echo "✅ PUB LOG data deployment complete!"
echo "🔗 Test the universal search at: https://api.handreceipt.com/api/nsn/universal-search?q=radio"

# Cleanup
rm -f /tmp/publog_data_manual.tar.gz 