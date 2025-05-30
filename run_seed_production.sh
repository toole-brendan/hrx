#!/bin/bash

# HandReceipt Production Seed Data Script
# This script runs the dev seed data on the production database

LIGHTSAIL_IP="44.193.254.155"
SSH_KEY_PATH="~/.ssh/handreceipt-new"  # Updated to use the correct key

echo "🚀 Running seed data on HandReceipt production database..."

# First, copy the seed file to the server
echo "📤 Copying seed data file to server..."
scp -i $SSH_KEY_PATH sql/production_seed.sql ubuntu@$LIGHTSAIL_IP:/tmp/

# Then run the seed data via SSH
ssh -i $SSH_KEY_PATH ubuntu@$LIGHTSAIL_IP << 'EOF'
  set -e
  
  echo "📍 Connected to Lightsail instance"
  
  # Check if we're in the right directory
  cd /opt/handreceipt/backend
  
  echo "🐘 Checking PostgreSQL container..."
  POSTGRES_CONTAINER=$(sudo docker ps --format "{{.Names}}" | grep postgres | head -1)
  
  if [ -z "$POSTGRES_CONTAINER" ]; then
    echo "❌ PostgreSQL container not found!"
    exit 1
  fi
  
  echo "✅ Found PostgreSQL container: $POSTGRES_CONTAINER"
  
  # Copy seed file into the container
  echo "📋 Copying seed file to container..."
  sudo docker cp /tmp/production_seed.sql $POSTGRES_CONTAINER:/tmp/
  
  # Run the seed data
  echo "🌱 Running seed data..."
  sudo docker exec -i $POSTGRES_CONTAINER psql -U handreceipt -d handreceipt < /tmp/production_seed.sql
  
  # Verify the test users were created
  echo "🔍 Verifying test user creation..."
  sudo docker exec $POSTGRES_CONTAINER psql -U handreceipt -d handreceipt -c "SELECT username, name, rank FROM users WHERE username IN ('michael.rodriguez', 'john.doe', 'jane.smith', 'bob.wilson');"
  
  # Clean up
  sudo docker exec $POSTGRES_CONTAINER rm /tmp/production_seed.sql
  rm /tmp/production_seed.sql
  
  echo "✅ Seed data applied successfully!"
  echo ""
  echo "📝 Test user credentials:"
  echo "   Username: michael.rodriguez"
  echo "   Password: password123"
  echo ""
  echo "   (All test users have the same password: password123)"
  echo ""
  echo "🔐 You can now use the dev login (tap logo 5 times) to login as this user"
EOF

echo "✅ Production seed completed!" 