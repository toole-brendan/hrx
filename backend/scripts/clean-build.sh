#!/bin/bash
# Clean build script - removes Docker cache and rebuilds

echo "🧹 Cleaning Docker build cache..."

# Remove any existing containers
echo "Stopping and removing HandReceipt containers..."
docker ps -a | grep handreceipt | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
docker ps -a | grep handreceipt | awk '{print $1}' | xargs -r docker rm 2>/dev/null || true

# Remove dangling images
echo "Removing dangling images..."
docker image prune -f

# Remove build cache
echo "Removing Docker build cache..."
docker builder prune -f

# Clean any mock files that might have been left behind
echo "Cleaning any mock files..."
find . -name "*mock*.go" -type f -delete 2>/dev/null || true

# Build with no cache
echo "🔨 Building with --no-cache..."
docker-compose build --no-cache app worker

echo "✅ Clean build complete!" 