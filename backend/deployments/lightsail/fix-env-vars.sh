#!/bin/bash

# Fix environment variables loading issue on Lightsail
set -e

echo "Fixing environment variable configuration..."

# Navigate to the handreceipt directory
cd /opt/handreceipt

# Check if production.env exists in the deployments/lightsail directory
if [ -f deployments/lightsail/production.env ]; then
    echo "Found production.env file"
    
    # Copy production.env to the correct location as .env
    cp deployments/lightsail/production.env deployments/lightsail/.env
    echo "Copied production.env to deployments/lightsail/.env"
    
    # Also ensure it's in the root directory for the application
    cp deployments/lightsail/production.env .env
    echo "Copied production.env to root .env"
    
else
    echo "ERROR: production.env not found in deployments/lightsail/"
    echo "Please ensure production.env is uploaded to the server"
    exit 1
fi

# Verify the environment variables are set correctly
echo ""
echo "Verifying environment variables..."
if grep -q "HANDRECEIPT_" deployments/lightsail/.env; then
    echo "✓ Environment variables have correct HANDRECEIPT_ prefix"
else
    echo "✗ Environment variables missing HANDRECEIPT_ prefix"
fi

# Restart the services to pick up the new environment
echo ""
echo "Restarting Docker services..."
cd deployments/lightsail
docker-compose down
docker-compose up -d

# Wait for services to start
sleep 10

# Check service status
echo ""
echo "Checking service status..."
docker-compose ps

# Test if the app can read environment variables
echo ""
echo "Testing environment variable loading..."
if docker-compose logs app | grep -q "Using config file\|JWT_SECRET\|database"; then
    echo "✓ Application appears to be reading configuration"
else
    echo "⚠ Could not verify if application is reading configuration"
    echo "Check logs with: docker-compose logs app"
fi

echo ""
echo "Fix complete! Environment variables should now be loaded correctly."
echo ""
echo "To verify:"
echo "1. Check app logs: docker-compose logs app"
echo "2. Check if services are healthy: docker-compose ps"
echo "3. Test the API: curl http://localhost:8080/health" 