#!/bin/bash

# Fix obsolete files on HandReceipt server
set -e

echo "🔧 HandReceipt Obsolete Files Fix Script"
echo "======================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}[INFO]${NC} Starting cleanup of obsolete files..."

# Navigate to the backend directory
cd /opt/handreceipt/backend

echo -e "${GREEN}[INFO]${NC} Current directory: $(pwd)"

# Stop services first
echo -e "${YELLOW}[STEP 1]${NC} Stopping services..."
sudo docker-compose down || true

# Clean up obsolete Go files
echo -e "${YELLOW}[STEP 2]${NC} Removing obsolete handler files..."
sudo rm -f internal/api/handlers/inventory_handler.go
sudo rm -f internal/api/handlers/qrcode_handler.go
sudo rm -f internal/api/handlers/report_handler.go

echo -e "${YELLOW}[STEP 3]${NC} Removing any mock files..."
sudo find . -name "*mock*.go" -type f -delete
sudo find . -name "mock_*.go" -type f -delete
sudo find . -name "*_mock.go" -type f -delete

# List remaining handler files
echo -e "${YELLOW}[STEP 4]${NC} Remaining handler files:"
ls -la internal/api/handlers/

# Clean Docker build cache
echo -e "${YELLOW}[STEP 5]${NC} Cleaning Docker build cache..."
sudo docker system prune -f

# Rebuild the application
echo -e "${YELLOW}[STEP 6]${NC} Rebuilding application..."
sudo docker-compose build --no-cache app worker

# Start services
echo -e "${YELLOW}[STEP 7]${NC} Starting services..."
sudo docker-compose up -d

# Wait for services to be ready
echo -e "${YELLOW}[STEP 8]${NC} Waiting for services to be ready..."
sleep 15

# Check service status
echo -e "${YELLOW}[STEP 9]${NC} Checking service status..."
sudo docker-compose ps

# Check app logs
echo -e "${YELLOW}[STEP 10]${NC} Recent app logs:"
sudo docker-compose logs --tail=20 app

# Test health endpoint
echo -e "${YELLOW}[STEP 11]${NC} Testing health endpoint..."
if curl -s -f http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend is healthy!${NC}"
else
    echo -e "${YELLOW}⚠️  Backend health check failed, checking logs...${NC}"
    sudo docker-compose logs app
fi

echo -e "${GREEN}[INFO]${NC} Fix script completed!" 