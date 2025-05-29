#!/bin/bash
# Fix Docker network conflict on Lightsail

set -e

echo "=== Fixing Docker network conflict ==="

# Navigate to deployment directory
cd /opt/handreceipt/deployments/lightsail

# Stop and remove all containers and networks
echo "Stopping all containers..."
sudo docker-compose down -v

# Remove any conflicting networks
echo "Cleaning up Docker networks..."
sudo docker network prune -f

# Check if there's a network conflict in docker-compose-fixed.yml
echo "Checking docker-compose configuration..."
if grep -q "subnet: 172.20.0.0/16" docker-compose-fixed.yml; then
    echo "Found subnet configuration that conflicts. Using alternative compose file..."
    # Use the regular docker-compose.yml which doesn't have fixed subnet
    sudo cp docker-compose.yml docker-compose-fixed.yml
else
    echo "No subnet conflict found in configuration."
fi

# Alternatively, remove the entire ipam section from the compose file
# This sed command removes the ipam configuration block
sudo sed -i '/ipam:/,/^[[:space:]]*[^[:space:]]/{/^[[:space:]]*[^[:space:]]/!d;}' docker-compose-fixed.yml 2>/dev/null || true

# Start services with clean network
echo "Starting services..."
sudo docker-compose -f docker-compose-fixed.yml up -d

# Wait for services to initialize
echo "Waiting for services to start (20 seconds)..."
sleep 20

# Check service status
echo ""
echo "=== Service Status ==="
sudo docker-compose ps

# Check if environment variables are loaded
echo ""
echo "=== Environment Variables Check ==="
ENV_COUNT=$(sudo docker-compose exec app env | grep -c HANDRECEIPT_ || echo "0")
echo "Found $ENV_COUNT HANDRECEIPT_ environment variables"

# Check application logs
echo ""
echo "=== Application Logs (last 20 lines) ==="
sudo docker-compose logs --tail=20 app

# Test health endpoint
echo ""
echo "=== Health Check ==="
HEALTH_RESPONSE=$(curl -s -w "\nHTTP Status: %{http_code}" http://localhost:8080/health)
echo "$HEALTH_RESPONSE"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "If services are not running properly, check:"
echo "1. Full logs: sudo docker-compose logs app"
echo "2. Network issues: sudo docker network ls"
echo "3. Container issues: sudo docker ps -a" 