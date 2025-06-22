#!/bin/bash

# Simple development startup script for HandReceipt backend
set -e

echo "🚀 Starting HandReceipt Backend Development Environment"
echo "====================================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

# Navigate to backend directory
cd "$(dirname "$0")"

# Start only the essential services with docker-compose
echo "🏗️  Starting database and storage services..."
docker-compose up -d postgres immudb minio

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 5

# Run database migrations
echo "🗄️  Running database migrations..."
cd ../sql
./apply_migrations.sh || echo "⚠️  Migrations may have already been applied"
cd ../backend

# Build the Go application
echo "🔨 Building Go application..."
go build -o bin/server cmd/server/main.go

# Use local config file
export HANDRECEIPT_CONFIG_NAME=config.local

# Export environment variables for local development
export HANDRECEIPT_DATABASE_HOST=localhost
export HANDRECEIPT_DATABASE_PORT=5432
export HANDRECEIPT_DATABASE_USER=handreceipt
export HANDRECEIPT_DATABASE_PASSWORD=cvOrf7fVpmyxvnkqeKOo5g==
export HANDRECEIPT_DATABASE_NAME=handreceipt
export HANDRECEIPT_SERVER_PORT=8080
export HANDRECEIPT_SERVER_ENVIRONMENT=development
export HANDRECEIPT_JWT_SECRET_KEY=dev-secret-key-change-in-production

# Optional services (can be disabled for minimal setup)
export HANDRECEIPT_IMMUDB_ENABLED=false
export HANDRECEIPT_MINIO_ENABLED=false

# CORS settings for local development
export CORS_ORIGINS="http://localhost:5001,http://localhost:5173,http://localhost:3000"

echo ""
echo "✅ Services are ready!"
echo "===================="
echo ""
echo "🌐 Starting API server on http://localhost:8080"
echo ""

# Run the server
./bin/server 