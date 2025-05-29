#!/bin/bash

# HandReceipt AWS Lightsail Deployment Script
# Usage: ./deploy-to-lightsail.sh

set -e

# Configuration
INSTANCE_NAME="handreceipt-primary"
BACKUP_INSTANCE_NAME="handreceipt-backup"
BLUEPRINT_ID="ubuntu_22_04"
BUNDLE_ID="small_3_0"  # 2 GB RAM, 1 vCPU, 60 GB SSD
REGION="us-east-1"
BACKUP_REGION="eu-central-1"
KEY_PAIR_NAME="handreceipt-key"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}HandReceipt AWS Lightsail Deployment${NC}"
echo "======================================"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS CLI is not configured. Please run 'aws configure'${NC}"
    exit 1
fi

# Function to check if instance exists
instance_exists() {
    aws lightsail get-instances --query "instances[?name=='$1'].name" --output text | grep -q "$1"
}

# Function to create instance
create_instance() {
    local instance_name=$1
    local region=$2
    
    echo -e "${YELLOW}Creating Lightsail instance: $instance_name in $region${NC}"
    
    # Create key pair if it doesn't exist
    if ! aws lightsail get-key-pairs --region $region --query "keyPairs[?name=='$KEY_PAIR_NAME'].name" --output text | grep -q "$KEY_PAIR_NAME"; then
        aws lightsail create-key-pair --key-pair-name $KEY_PAIR_NAME --region $region
        echo -e "${GREEN}Created key pair: $KEY_PAIR_NAME${NC}"
    fi
    
    # Create instance
    aws lightsail create-instances \
        --instance-names $instance_name \
        --availability-zone "${region}a" \
        --blueprint-id $BLUEPRINT_ID \
        --bundle-id $BUNDLE_ID \
        --key-pair-name $KEY_PAIR_NAME \
        --region $region \
        --user-data file://user-data.sh
    
    echo -e "${GREEN}Instance $instance_name created. Waiting for it to be ready...${NC}"
    
    # Wait for instance to be running
    while true; do
        STATE=$(aws lightsail get-instances --region $region --query "instances[?name=='$instance_name'].state.name" --output text)
        if [ "$STATE" = "running" ]; then
            break
        fi
        echo -n "."
        sleep 10
    done
    echo ""
    echo -e "${GREEN}Instance $instance_name is running${NC}"
}

# Create user data script for initial setup
cat > user-data.sh << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y docker.io docker-compose git curl

# Enable Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install

# Create application directory
mkdir -p /opt/handreceipt
chown ubuntu:ubuntu /opt/handreceipt

# Install fail2ban for security
apt-get install -y fail2ban

# Configure firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw --force enable

# Install certbot for SSL
snap install core; snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

echo "Initial setup complete"
EOF

# Check if primary instance exists
if instance_exists $INSTANCE_NAME; then
    echo -e "${YELLOW}Instance $INSTANCE_NAME already exists${NC}"
    read -p "Do you want to continue with deployment? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    create_instance $INSTANCE_NAME $REGION
fi

# Get instance IP
INSTANCE_IP=$(aws lightsail get-instances --region $REGION --query "instances[?name=='$INSTANCE_NAME'].publicIpAddress" --output text)
echo -e "${GREEN}Instance IP: $INSTANCE_IP${NC}"

# Create static IP if not exists
STATIC_IP_NAME="${INSTANCE_NAME}-ip"
if ! aws lightsail get-static-ips --region $REGION --query "staticIps[?name=='$STATIC_IP_NAME'].name" --output text | grep -q "$STATIC_IP_NAME"; then
    aws lightsail allocate-static-ip --static-ip-name $STATIC_IP_NAME --region $REGION
    aws lightsail attach-static-ip --static-ip-name $STATIC_IP_NAME --instance-name $INSTANCE_NAME --region $REGION
    echo -e "${GREEN}Static IP allocated and attached${NC}"
fi

STATIC_IP=$(aws lightsail get-static-ips --region $REGION --query "staticIps[?name=='$STATIC_IP_NAME'].ipAddress" --output text)
echo -e "${GREEN}Static IP: $STATIC_IP${NC}"

# Open ports
echo -e "${YELLOW}Opening required ports...${NC}"
aws lightsail open-instance-public-ports --region $REGION \
    --port-info fromPort=80,toPort=80,protocol=tcp \
    --instance-name $INSTANCE_NAME

aws lightsail open-instance-public-ports --region $REGION \
    --port-info fromPort=443,toPort=443,protocol=tcp \
    --instance-name $INSTANCE_NAME

aws lightsail open-instance-public-ports --region $REGION \
    --port-info fromPort=8080,toPort=8080,protocol=tcp \
    --instance-name $INSTANCE_NAME

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
cd ../..
tar -czf deployment.tar.gz \
    docker-compose.yml \
    deployments/lightsail/docker-compose.yml \
    deployments/lightsail/nginx.conf \
    deployments/docker/Dockerfile \
    deployments/docker/Dockerfile.worker \
    cmd \
    internal \
    go.mod \
    go.sum \
    configs \
    migrations

# Copy files to instance
echo -e "${YELLOW}Deploying to instance...${NC}"
scp -o StrictHostKeyChecking=no -i ~/.ssh/$KEY_PAIR_NAME deployment.tar.gz ubuntu@$STATIC_IP:/opt/handreceipt/
scp -o StrictHostKeyChecking=no -i ~/.ssh/$KEY_PAIR_NAME deployments/lightsail/setup-instance.sh ubuntu@$STATIC_IP:/opt/handreceipt/

# Execute setup on instance
ssh -o StrictHostKeyChecking=no -i ~/.ssh/$KEY_PAIR_NAME ubuntu@$STATIC_IP << 'ENDSSH'
cd /opt/handreceipt
tar -xzf deployment.tar.gz
chmod +x setup-instance.sh
sudo ./setup-instance.sh
ENDSSH

# Cleanup
rm deployment.tar.gz
rm user-data.sh

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}Primary instance: http://$STATIC_IP:8080${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Point your domain to IP: $STATIC_IP"
echo "2. Run: sudo certbot --nginx -d yourdomain.com"
echo "3. Update environment variables in docker-compose.yml"

# Ask if user wants to create backup instance
read -p "Do you want to create a backup instance in EU? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    create_instance $BACKUP_INSTANCE_NAME $BACKUP_REGION
    BACKUP_IP=$(aws lightsail get-instances --region $BACKUP_REGION --query "instances[?name=='$BACKUP_INSTANCE_NAME'].publicIpAddress" --output text)
    echo -e "${GREEN}Backup instance created at: $BACKUP_IP${NC}"
fi 