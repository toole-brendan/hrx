#!/bin/bash

# HandReceipt AWS Lightsail Deployment Script (Fixed)
# Usage: ./deploy-to-lightsail-fixed.sh

set -e

# Configuration
INSTANCE_NAME="handreceipt-primary"
BACKUP_INSTANCE_NAME="handreceipt-backup"
BLUEPRINT_ID="ubuntu_22_04"
BUNDLE_ID="small_3_0"  # 2 GB RAM, 1 vCPU, 60 GB SSD
REGION="us-east-1"
BACKUP_REGION="eu-central-1"
KEY_PAIR_NAME="handreceipt-key"
KEY_PATH="$HOME/.ssh/$KEY_PAIR_NAME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}HandReceipt AWS Lightsail Deployment (Fixed)${NC}"
echo "============================================="

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
    local key_name="${KEY_PAIR_NAME}-${region}"
    local key_path="$HOME/.ssh/${key_name}"
    
    echo -e "${YELLOW}Creating Lightsail instance: $instance_name in $region${NC}"
    
    # Check if key pair exists in AWS
    if ! aws lightsail get-key-pairs --region $region --query "keyPairs[?name=='$key_name'].name" --output text | grep -q "$key_name"; then
        echo -e "${YELLOW}Creating new key pair: $key_name${NC}"
        
        # Create key pair and save the private key
        aws lightsail create-key-pair \
            --key-pair-name $key_name \
            --region $region \
            --query 'privateKeyBase64' \
            --output text | base64 -d > "$key_path"
        
        # Set proper permissions
        chmod 600 "$key_path"
        
        echo -e "${GREEN}Created key pair and saved to: $key_path${NC}"
    else
        echo -e "${YELLOW}Key pair $key_name already exists${NC}"
        
        # Check if we have the private key locally
        if [ ! -f "$key_path" ]; then
            echo -e "${RED}ERROR: Key pair exists in AWS but private key not found at: $key_path${NC}"
            echo -e "${YELLOW}You need to either:${NC}"
            echo "1. Download the key from Lightsail console"
            echo "2. Delete the key pair and recreate it:"
            echo "   aws lightsail delete-key-pair --key-pair-name $key_name --region $region"
            return 1
        fi
    fi
    
    # Create instance
    aws lightsail create-instances \
        --instance-names $instance_name \
        --availability-zone "${region}a" \
        --blueprint-id $BLUEPRINT_ID \
        --bundle-id $BUNDLE_ID \
        --key-pair-name $key_name \
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
    
    # Store the key path for later use
    if [ "$region" = "$REGION" ]; then
        PRIMARY_KEY_PATH="$key_path"
    else
        BACKUP_KEY_PATH="$key_path"
    fi
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
    # Set the key path for existing instance
    PRIMARY_KEY_PATH="$HOME/.ssh/${KEY_PAIR_NAME}-${REGION}"
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

# Wait a bit for SSH to be ready
echo -e "${YELLOW}Waiting for SSH to be ready...${NC}"
sleep 30

# Test SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$PRIMARY_KEY_PATH" ubuntu@$STATIC_IP "echo 'SSH connection successful'"; then
    echo -e "${GREEN}SSH connection confirmed${NC}"
else
    echo -e "${RED}SSH connection failed${NC}"
    echo -e "${YELLOW}Please check:${NC}"
    echo "1. Key file exists at: $PRIMARY_KEY_PATH"
    echo "2. Key has correct permissions (600)"
    echo "3. Security group allows SSH (port 22)"
    echo ""
    echo "You can still continue with browser-based SSH"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

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

# Try to deploy via SSH
if [ -f "$PRIMARY_KEY_PATH" ]; then
    echo -e "${YELLOW}Deploying to instance via SSH...${NC}"
    
    # Copy files to instance
    if scp -o StrictHostKeyChecking=no -i "$PRIMARY_KEY_PATH" deployment.tar.gz ubuntu@$STATIC_IP:/opt/handreceipt/; then
        scp -o StrictHostKeyChecking=no -i "$PRIMARY_KEY_PATH" deployments/lightsail/setup-instance.sh ubuntu@$STATIC_IP:/opt/handreceipt/
        
        # Execute setup on instance
        ssh -o StrictHostKeyChecking=no -i "$PRIMARY_KEY_PATH" ubuntu@$STATIC_IP << 'ENDSSH'
cd /opt/handreceipt
tar -xzf deployment.tar.gz
chmod +x setup-instance.sh
sudo ./setup-instance.sh
ENDSSH
        
        DEPLOYMENT_SUCCESS=true
    else
        echo -e "${RED}SSH deployment failed${NC}"
        DEPLOYMENT_SUCCESS=false
    fi
else
    echo -e "${RED}No SSH key found, cannot deploy automatically${NC}"
    DEPLOYMENT_SUCCESS=false
fi

# Cleanup
rm -f deployment.tar.gz user-data.sh

if [ "$DEPLOYMENT_SUCCESS" = true ]; then
    echo -e "${GREEN}✅ Deployment complete!${NC}"
    echo -e "${GREEN}Primary instance: http://$STATIC_IP:8080${NC}"
else
    echo -e "${YELLOW}⚠️  Automated deployment failed${NC}"
    echo ""
    echo "Please complete deployment manually:"
    echo "1. Connect via Lightsail browser SSH"
    echo "2. Upload deployment.tar.gz"
    echo "3. Run setup-instance.sh"
    echo ""
    echo "Or use the fix-ssh-access.sh script to resolve SSH issues"
fi

echo ""
echo -e "${YELLOW}Instance Details:${NC}"
echo "Static IP: $STATIC_IP"
echo "SSH Key: $PRIMARY_KEY_PATH"
echo "SSH Command: ssh -i $PRIMARY_KEY_PATH ubuntu@$STATIC_IP"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Point your domain to IP: $STATIC_IP"
echo "2. Run: sudo certbot --nginx -d yourdomain.com"
echo "3. Update environment variables in docker-compose.yml" 