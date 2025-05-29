#!/bin/bash

# HandReceipt Manual Setup Script for Lightsail
# Run this script on the Lightsail instance via browser SSH

set -e

echo "🚀 HandReceipt Manual Setup"
echo "=========================="

# Update system
sudo apt-get update
sudo apt-get install -y docker.io docker-compose git curl unzip

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Create application directory
sudo mkdir -p /opt/handreceipt
sudo chown $USER:$USER /opt/handreceipt
cd /opt/handreceipt

# Download the deployment package from GitHub (or you can upload it)
echo "Please upload the deployment.tar.gz file to /opt/handreceipt/"
echo "You can use the Lightsail browser file transfer feature"
echo ""
echo "Once uploaded, press Enter to continue..."
read

# Extract the deployment package
tar -xzf deployment.tar.gz

# Run the setup script
chmod +x deployments/lightsail/setup-instance.sh
sudo ./deployments/lightsail/setup-instance.sh

echo "✅ Setup complete!" 