#!/bin/bash

# Minimal startup script - just the Go server
# This assumes you have PostgreSQL running somewhere (local or remote)

echo "🚀 Starting HandReceipt Backend (Minimal Mode)"
echo "============================================="

cd "$(dirname "$0")"

# Build the Go application
echo "🔨 Building Go application..."
go build -o bin/server cmd/server/main.go

# Export minimal environment variables
export HANDRECEIPT_DATABASE_HOST=localhost
export HANDRECEIPT_DATABASE_PORT=5432
export HANDRECEIPT_DATABASE_USER=handreceipt
export HANDRECEIPT_DATABASE_PASSWORD=handreceipt_password
export HANDRECEIPT_DATABASE_NAME=handreceipt
export HANDRECEIPT_SERVER_PORT=8080
export HANDRECEIPT_SERVER_ENVIRONMENT=development
export HANDRECEIPT_JWT_SECRET_KEY=dev-secret-key

# Disable optional services
export HANDRECEIPT_LEDGER_TYPE=postgres
export HANDRECEIPT_LEDGER_ENABLED=false
export HANDRECEIPT_MINIO_ENABLED=false

# CORS settings for local development
export CORS_ORIGINS="http://localhost:5001,http://localhost:5173,http://localhost:3000"

echo ""
echo "📝 Note: This minimal mode assumes you have PostgreSQL running"
echo "   If not, use ./start-dev.sh for full Docker setup"
echo ""
echo "🌐 Starting API server on http://localhost:8080"
echo ""

# Run the server
./bin/server 