#!/bin/bash

# Setup PostgreSQL for HandReceipt

echo "Setting up PostgreSQL database for HandReceipt..."

# Use the current user as the PostgreSQL superuser (common on macOS with Homebrew)
CURRENT_USER=$(whoami)

# Create the database user
psql -U $CURRENT_USER -d postgres -c "CREATE USER handreceipt WITH PASSWORD 'handreceipt_password';" 2>/dev/null || echo "User handreceipt might already exist"

# Create the database
psql -U $CURRENT_USER -d postgres -c "CREATE DATABASE handreceipt OWNER handreceipt;" 2>/dev/null || echo "Database handreceipt might already exist"

# Grant all privileges
psql -U $CURRENT_USER -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE handreceipt TO handreceipt;"

# Also grant necessary permissions on the public schema
psql -U $CURRENT_USER -d handreceipt -c "GRANT ALL ON SCHEMA public TO handreceipt;"
psql -U $CURRENT_USER -d handreceipt -c "GRANT CREATE ON SCHEMA public TO handreceipt;"

echo "Database setup complete!"
echo ""
echo "You can now run the backend with:"
echo "  cd backend && go run cmd/server/main.go" 