#!/bin/bash

# HandReceipt Local Development Startup Script

set -e

echo "🚀 Starting HandReceipt Local Development Environment"
echo "===================================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

# Navigate to backend directory
cd "$(dirname "$0")"

# Create local data directories
mkdir -p data/{postgres,minio}

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Start infrastructure services
echo "🏗️  Starting infrastructure services..."
docker-compose up -d postgres minio

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if services are healthy
echo "🔍 Checking service health..."
docker-compose ps

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose exec -T postgres psql -U handreceipt -d handreceipt < migrations/001_initial_schema.up.sql || true
docker-compose exec -T postgres psql -U handreceipt -d handreceipt < migrations/003_nsn_catalog.sql || true

# Create MinIO bucket
echo "📦 Creating MinIO bucket..."
docker-compose exec -T minio mc alias set local http://localhost:9000 minioadmin minioadmin123
docker-compose exec -T minio mc mb local/handreceipt || true

# Build and start the API
echo "🔨 Building API..."
go build -o bin/server cmd/server/main.go

# Export environment variables for local development
export HANDRECEIPT_DATABASE_HOST=localhost
export HANDRECEIPT_DATABASE_PORT=5432
export HANDRECEIPT_DATABASE_USER=handreceipt
export HANDRECEIPT_DATABASE_PASSWORD=handreceipt_password
export HANDRECEIPT_DATABASE_NAME=handreceipt
# Ledger configuration (using PostgreSQL ledger tables)
export HANDRECEIPT_LEDGER_TYPE=postgres
export HANDRECEIPT_LEDGER_ENABLED=true
export HANDRECEIPT_MINIO_ENDPOINT=localhost:9000
export HANDRECEIPT_MINIO_ACCESS_KEY_ID=minioadmin
export HANDRECEIPT_MINIO_SECRET_ACCESS_KEY=minioadmin123
export HANDRECEIPT_MINIO_USE_SSL=false
export HANDRECEIPT_MINIO_BUCKET_NAME=handreceipt
export HANDRECEIPT_JWT_SECRET_KEY=dev-secret-key-change-in-production
export HANDRECEIPT_SERVER_PORT=8080
export HANDRECEIPT_SERVER_ENVIRONMENT=development

# Start the API server
echo "🚀 Starting API server..."
./bin/server &
API_PID=$!

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down..."
    kill $API_PID 2>/dev/null || true
    docker-compose down
    exit 0
}

trap cleanup INT TERM

echo ""
echo "✅ HandReceipt is running!"
echo "============================"
echo ""
echo "🌐 API Server: http://localhost:8080"
echo "📊 MinIO Console: http://localhost:9001 (minioadmin/minioadmin123)"
echo "🗄️  PostgreSQL: localhost:5432 (handreceipt/handreceipt_password)"
echo ""
echo "📱 Test Endpoints:"
echo "   - Health Check: curl http://localhost:8080/health"
echo "   - Login: curl -X POST http://localhost:8080/api/auth/login -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"admin123\"}'"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Wait for the API process
wait $API_PID 