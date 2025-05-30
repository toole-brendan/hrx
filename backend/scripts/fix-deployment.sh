#!/bin/bash
# Quick fix script for HandReceipt deployment issues

set -e

echo "🔧 HandReceipt Deployment Fix Script"
echo "===================================="

# Navigate to backend directory
cd /opt/handreceipt/backend || cd /opt/handreceipt

echo "📍 Current directory: $(pwd)"

# Stop the app container
echo "🛑 Stopping app container..."
sudo docker-compose stop app || true
sudo docker rm backend_app_1 || true

# Wait for other services to be ready
echo "⏳ Checking service status..."

# Check PostgreSQL
if sudo docker exec backend_postgres_1 pg_isready -U handreceipt -d handreceipt > /dev/null 2>&1; then
    echo "✅ PostgreSQL is ready"
else
    echo "❌ PostgreSQL is not ready"
    sudo docker-compose logs --tail=20 postgres
fi

# Check MinIO
if curl -s -f http://localhost:9000/minio/health/live > /dev/null 2>&1; then
    echo "✅ MinIO is ready"
else
    echo "⚠️ MinIO is not ready - app will start without it"
fi

# Check ImmuDB
if nc -z localhost 3322 > /dev/null 2>&1; then
    echo "✅ ImmuDB port is open"
else
    echo "⚠️ ImmuDB is not ready"
fi

# Update the routes.go file to fix the conflict
echo "🔧 Fixing route conflicts..."
if [ -f "internal/api/routes/routes.go" ]; then
    # Use sed to fix the route parameter names
    sudo sed -i 's/:propertyId/:id/g' internal/api/routes/routes.go
    echo "✅ Fixed route parameter names"
fi

# Rebuild the app
echo "🔨 Rebuilding app container..."
sudo docker-compose build app

# Start the app
echo "🚀 Starting app container..."
sudo docker-compose up -d app

# Wait for app to start
echo "⏳ Waiting for app to start..."
sleep 10

# Check if app is healthy
if curl -s -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ App is healthy!"
    curl -s http://localhost:8080/health | jq .
else
    echo "❌ App health check failed"
    echo "📝 App logs:"
    sudo docker-compose logs --tail=50 app
fi

echo ""
echo "📊 Container status:"
sudo docker-compose ps

echo ""
echo "🔍 To view logs: sudo docker-compose logs -f app" 