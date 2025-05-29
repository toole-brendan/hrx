#!/bin/bash

# HandReceipt Lightsail SSH Access Fix Script
# This script helps fix SSH access issues

set -e

# Configuration
INSTANCE_NAME="handreceipt-primary"
REGION="us-east-1"
KEY_PAIR_NAME="handreceipt-key"
KEY_PATH="$HOME/.ssh/$KEY_PAIR_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}HandReceipt SSH Access Fix${NC}"
echo "=========================="

# Option 1: Download existing key pair (if you have access to Lightsail console)
echo -e "${YELLOW}Option 1: Download key from Lightsail Console${NC}"
echo "1. Go to https://lightsail.aws.amazon.com/ls/webapp/home/instances"
echo "2. Click on your instance 'handreceipt-primary'"
echo "3. Go to the 'Connect' tab"
echo "4. Click 'Download default key'"
echo "5. Save it as: $KEY_PATH"
echo ""
read -p "Have you downloaded the key? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    chmod 600 "$KEY_PATH"
    echo -e "${GREEN}Key permissions set. Try connecting:${NC}"
    echo "ssh -i $KEY_PATH ubuntu@44.193.254.155"
    exit 0
fi

# Option 2: Create new key pair and update instance
echo -e "${YELLOW}Option 2: Create new SSH key pair${NC}"
read -p "Do you want to create a new key pair? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Generate new SSH key
    ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "handreceipt-lightsail"
    
    echo -e "${GREEN}New key pair generated at: $KEY_PATH${NC}"
    echo -e "${YELLOW}Now you need to add this key to your instance:${NC}"
    echo ""
    echo "1. Copy this public key:"
    echo "---"
    cat "${KEY_PATH}.pub"
    echo "---"
    echo ""
    echo "2. Go to Lightsail Console and connect via browser SSH"
    echo "3. Once connected, run:"
    echo "   echo 'YOUR_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys"
    echo ""
    echo "4. Then you can SSH with:"
    echo "   ssh -i $KEY_PATH ubuntu@44.193.254.155"
    exit 0
fi

# Option 3: Use AWS CLI to get instance access
echo -e "${YELLOW}Option 3: Use AWS Session Manager (if available)${NC}"
echo "Checking if instance has Session Manager..."

# Check instance access details
INSTANCE_INFO=$(aws lightsail get-instance-access-details \
    --instance-name $INSTANCE_NAME \
    --region $REGION 2>/dev/null || echo "")

if [ -n "$INSTANCE_INFO" ]; then
    echo -e "${GREEN}Instance access details:${NC}"
    echo "$INSTANCE_INFO" | jq '.'
fi

# Option 4: Use Lightsail browser-based SSH
echo ""
echo -e "${YELLOW}Option 4: Use Lightsail Browser SSH (Recommended)${NC}"
echo "This is the easiest method:"
echo "1. Go to https://lightsail.aws.amazon.com/ls/webapp/home/instances"
echo "2. Click on 'handreceipt-primary'"
echo "3. Click the orange 'Connect using SSH' button"
echo ""
echo "Once connected via browser, you can:"
echo "- Add your local SSH key to authorized_keys"
echo "- Complete the deployment manually"

# Option 5: Reset instance SSH access
echo ""
echo -e "${YELLOW}Option 5: Reset SSH access (Last Resort)${NC}"
echo "If all else fails, you can reset the instance's SSH keys:"
echo ""
echo "Run this command to delete and recreate the key pair:"
echo "aws lightsail delete-key-pair --key-pair-name $KEY_PAIR_NAME --region $REGION"
echo ""
echo "Then create a new one and save it properly:"
cat << 'EOF'

# Create new key pair and save it
aws lightsail create-key-pair \
    --key-pair-name handreceipt-key \
    --region us-east-1 \
    --query 'privateKeyBase64' \
    --output text | base64 -d > ~/.ssh/handreceipt-key

# Set proper permissions
chmod 600 ~/.ssh/handreceipt-key

# Test connection
ssh -i ~/.ssh/handreceipt-key ubuntu@44.193.254.155
EOF

echo ""
echo -e "${GREEN}Current instance details:${NC}"
echo "Instance: handreceipt-primary"
echo "Static IP: 44.193.254.155"
echo "Username: ubuntu"
echo "Region: us-east-1" 