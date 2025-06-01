#!/bin/bash

# Fix database views blocking migrations
set -e

echo "🔧 HandReceipt Database Views Fix Script"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}[INFO]${NC} Starting database views fix..."

# Navigate to the backend directory
cd /opt/handreceipt/backend

echo -e "${GREEN}[INFO]${NC} Current directory: $(pwd)"

# Function to execute SQL
execute_sql() {
    sudo docker exec backend_postgres_1 psql -U handreceipt -d handreceipt -c "$1"
}

# Stop the app services first (keep database running)
echo -e "${YELLOW}[STEP 1]${NC} Stopping application services..."
sudo docker-compose stop app worker || true

# Check for views that might be blocking the migration
echo -e "${YELLOW}[STEP 2]${NC} Checking for views in the database..."
execute_sql "SELECT schemaname, viewname FROM pg_views WHERE schemaname NOT IN ('pg_catalog', 'information_schema');" || true

# Drop all user-created views
echo -e "${YELLOW}[STEP 3]${NC} Dropping all user-created views..."
execute_sql "DO \$\$ DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT schemaname, viewname FROM pg_views WHERE schemaname NOT IN ('pg_catalog', 'information_schema'))
    LOOP
        EXECUTE 'DROP VIEW IF EXISTS ' || quote_ident(r.schemaname) || '.' || quote_ident(r.viewname) || ' CASCADE';
    END LOOP;
END \$\$;" || true

# Check for any rules
echo -e "${YELLOW}[STEP 4]${NC} Checking for rules..."
execute_sql "SELECT n.nspname as schema, c.relname as table, r.rulename as rule 
FROM pg_rewrite r 
JOIN pg_class c ON r.ev_class = c.oid 
JOIN pg_namespace n ON c.relnamespace = n.oid 
WHERE r.rulename != '_RETURN' 
AND n.nspname NOT IN ('pg_catalog', 'information_schema');" || true

# Alternative: Reset the entire database (nuclear option)
echo -e "${YELLOW}[STEP 5]${NC} Do you want to reset the entire database? This will DELETE ALL DATA! (y/N)"
read -t 10 -n 1 RESET_DB || RESET_DB="N"
echo

if [[ "$RESET_DB" =~ ^[Yy]$ ]]; then
    echo -e "${RED}[WARNING]${NC} Resetting database..."
    
    # Drop and recreate the database
    execute_sql "DROP DATABASE IF EXISTS handreceipt;"
    sudo docker exec backend_postgres_1 createdb -U handreceipt handreceipt
    
    echo -e "${GREEN}[INFO]${NC} Database reset complete"
else
    echo -e "${GREEN}[INFO]${NC} Keeping existing data, only removed views"
fi

# Restart the application
echo -e "${YELLOW}[STEP 6]${NC} Restarting application services..."
sudo docker-compose up -d app worker

# Wait for services to be ready
echo -e "${YELLOW}[STEP 7]${NC} Waiting for services to be ready..."
sleep 20

# Check service status
echo -e "${YELLOW}[STEP 8]${NC} Checking service status..."
sudo docker-compose ps

# Check app logs
echo -e "${YELLOW}[STEP 9]${NC} Recent app logs:"
sudo docker-compose logs --tail=30 app

# Test health endpoint
echo -e "${YELLOW}[STEP 10]${NC} Testing health endpoint..."
if curl -s -f http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is healthy!${NC}"
else
    echo -e "${YELLOW}⚠️  Backend health check failed, checking detailed logs...${NC}"
    sudo docker-compose logs app | tail -50
fi

echo -e "${GREEN}[INFO]${NC} Database fix script completed!" 