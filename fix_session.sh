#!/bin/bash

SSH_KEY_PATH="~/.ssh/handreceipt-new"
LIGHTSAIL_IP="44.193.254.155"

echo "🔧 Fixing session configuration..."

ssh -i $SSH_KEY_PATH ubuntu@$LIGHTSAIL_IP << 'EOF'
  cd /opt/handreceipt/backend
  
  # Add session configuration to use memory instead of Redis
  sudo bash -c 'echo "" >> configs/config.yaml'
  sudo bash -c 'echo "# Session configuration" >> configs/config.yaml'
  sudo bash -c 'echo "session:" >> configs/config.yaml'
  sudo bash -c 'echo "  provider: memory" >> configs/config.yaml'
  sudo bash -c 'echo "  secret: 9xr/uSKNDqOfSPkVOpujQUW3nzll5ykcT8nzu9W9Cvc=" >> configs/config.yaml'
  sudo bash -c 'echo "  max_age: 86400" >> configs/config.yaml'
  
  echo "✅ Configuration updated"
  
  # Restart the app
  echo "🔄 Restarting app..."
  sudo docker-compose restart app
  
  echo "✅ App restarted"
EOF

echo "✅ Fix completed!" 