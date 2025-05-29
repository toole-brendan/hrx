#!/bin/bash
# Fix Docker network conflict on Lightsail - Version 2

set -e

echo "=== Fixing Docker network conflict (v2) ==="

# Ensure we're in the right directory
cd /opt/handreceipt/deployments/lightsail

# Check what files we have
echo "Available docker-compose files:"
ls -la docker-compose*.yml

# Stop any running containers
echo "Stopping all containers..."
sudo docker-compose -f docker-compose.yml down -v 2>/dev/null || true

# Clean up networks
echo "Cleaning up Docker networks..."
sudo docker network prune -f

# Use the standard docker-compose.yml file
echo "Using docker-compose.yml..."

# Ensure .env file exists
if [ ! -f ".env" ]; then
    if [ -f "production.env" ]; then
        echo "Copying production.env to .env..."
        sudo cp production.env .env
    else
        echo "ERROR: No .env or production.env file found!"
        exit 1
    fi
fi

# Start services
echo "Starting services with docker-compose.yml..."
sudo docker-compose -f docker-compose.yml up -d

# Wait for services to initialize
echo "Waiting for services to start (20 seconds)..."
sleep 20

# Check service status
echo ""
echo "=== Service Status ==="
sudo docker-compose -f docker-compose.yml ps

# Check if environment variables are loaded
echo ""
echo "=== Environment Variables Check ==="
ENV_COUNT=$(sudo docker-compose -f docker-compose.yml exec -T app env | grep -c HANDRECEIPT_ || echo "0")
echo "Found $ENV_COUNT HANDRECEIPT_ environment variables"

# Check application logs
echo ""
echo "=== Application Logs (last 20 lines) ==="
sudo docker-compose -f docker-compose.yml logs --tail=20 app

# Test health endpoint
echo ""
echo "=== Health Check ==="
HEALTH_RESPONSE=$(curl -s -w "\nHTTP Status: %{http_code}" http://localhost:8080/health)
echo "$HEALTH_RESPONSE"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Services should now be running. Check:"
echo "1. Full logs: sudo docker-compose -f docker-compose.yml logs app"
echo "2. All services: sudo docker-compose -f docker-compose.yml ps" 