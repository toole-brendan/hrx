#!/bin/bash

# HandReceipt Backend Development Runner
# This script sets up the environment and runs the backend server for local development

echo "🚀 Starting HandReceipt Backend in Development Mode..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    echo "📝 Please create a .env file with your production database credentials."
    echo "   You can copy dev.env.example to .env and fill in the values:"
    echo "   cp dev.env.example .env"
    exit 1
fi

# Load environment variables from .env file
set -a
source .env
set +a

# Export the config name to use development config
export HANDRECEIPT_CONFIG_NAME=config.development

# Check if required environment variables are set
if [ -z "$HANDRECEIPT_DATABASE_PASSWORD" ]; then
    echo "❌ HANDRECEIPT_DATABASE_PASSWORD not set in .env file!"
    echo "   Please add your production database password to the .env file."
    exit 1
fi

echo "✅ Environment variables loaded"
echo "📊 Database: $HANDRECEIPT_DATABASE_HOST"
echo "👤 Database User: $HANDRECEIPT_DATABASE_USER"
echo "🔧 Config: $HANDRECEIPT_CONFIG_NAME"
echo "🌐 Server Port: $HANDRECEIPT_SERVER_PORT"
echo ""

# Run the server
echo "🏃 Starting server..."
go run cmd/server/main.go 