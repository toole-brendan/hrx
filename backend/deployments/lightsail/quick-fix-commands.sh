#!/bin/bash
# Quick fix commands to run on your Lightsail instance
# Copy and paste these commands after SSHing into your server

echo "=== Starting environment variable fix ==="

# Navigate to the application directory
cd /opt/handreceipt

# Check current status
echo "Current directory structure:"
ls -la deployments/lightsail/ | grep -E "(production.env|\.env)"

# Copy the environment file to the correct location
echo "Copying production.env to .env in the correct location..."
sudo cp deployments/lightsail/production.env deployments/lightsail/.env

# Verify the copy was successful
echo "Verifying .env file exists:"
ls -la deployments/lightsail/.env

# Show first few lines of env file (without sensitive data)
echo "Environment variable prefixes (first 5 lines):"
head -5 deployments/lightsail/.env | cut -d'=' -f1

# Navigate to docker-compose directory
cd deployments/lightsail

# Stop current containers
echo "Stopping current containers..."
sudo docker-compose down

# Start containers with new environment
echo "Starting containers with updated environment..."
sudo docker-compose up -d

# Wait for services to initialize
echo "Waiting for services to start (15 seconds)..."
sleep 15

# Check service status
echo "Current service status:"
sudo docker-compose ps

# Check if app container has environment variables
echo "Checking if app container has HANDRECEIPT_ variables:"
sudo docker-compose exec app env | grep -c HANDRECEIPT_ || echo "0 HANDRECEIPT_ variables found"

# Check app logs for configuration loading
echo "Checking app logs for configuration messages:"
sudo docker-compose logs --tail=50 app | grep -i "config\|environment\|viper\|loaded" || echo "No config messages found"

# Test the health endpoint
echo "Testing health endpoint:"
curl -s http://localhost:8080/health || echo "Health check failed"

echo "=== Fix complete ==="
echo ""
echo "If you see HANDRECEIPT_ variables and the health check passes, the fix worked!"
echo "If not, run: sudo docker-compose logs app" 