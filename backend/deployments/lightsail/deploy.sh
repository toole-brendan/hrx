#!/bin/bash

# HandReceipt AWS Lightsail Deployment Script
set -e

echo "🚀 HandReceipt AWS Lightsail Deployment"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LIGHTSAIL_INSTANCE_NAME="handreceipt-app"
LIGHTSAIL_REGION="us-east-1"
LIGHTSAIL_BUNDLE_ID="nano_2_0"  # 512 MB RAM, 1 vCPU, 20 GB SSD
LIGHTSAIL_BLUEPRINT_ID="ubuntu_24_04"
SSH_KEY_NAME="handreceipt-key"
SSH_KEY_PATH="~/.ssh/handreceipt-key.pem"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first:"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

print_status "AWS CLI is configured and ready"

# Check if production.env exists and has been customized
if [ ! -f "production.env" ]; then
    print_error "production.env file not found. Please create it first."
    exit 1
fi

if grep -q "CHANGE_THIS" production.env; then
    print_warning "production.env contains default values. Please update the passwords and secrets before deploying to production!"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Function to create Lightsail instance
create_lightsail_instance() {
    print_status "Creating Lightsail instance: $LIGHTSAIL_INSTANCE_NAME"
    
    # Check if instance already exists
    if aws lightsail get-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME" &> /dev/null; then
        print_warning "Instance $LIGHTSAIL_INSTANCE_NAME already exists"
        return 0
    fi
    
    # Create the instance
    aws lightsail create-instances \
        --instance-names "$LIGHTSAIL_INSTANCE_NAME" \
        --availability-zone "${LIGHTSAIL_REGION}a" \
        --blueprint-id "$LIGHTSAIL_BLUEPRINT_ID" \
        --bundle-id "$LIGHTSAIL_BUNDLE_ID" \
        --key-pair-name "$SSH_KEY_NAME" \
        --user-data file://user-data.sh
    
    print_status "Instance creation initiated. Waiting for it to be running..."
    
    # Wait for instance to be running
    while true; do
        STATE=$(aws lightsail get-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME" --query 'instance.state.name' --output text)
        if [ "$STATE" = "running" ]; then
            break
        fi
        echo "Instance state: $STATE. Waiting..."
        sleep 10
    done
    
    print_status "Instance is now running!"
}

# Function to get instance IP
get_instance_ip() {
    aws lightsail get-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME" --query 'instance.publicIpAddress' --output text
}

# Function to open firewall ports
configure_firewall() {
    print_status "Configuring firewall rules"
    
    # Open HTTP (80)
    aws lightsail open-instance-public-ports \
        --instance-name "$LIGHTSAIL_INSTANCE_NAME" \
        --port-info fromPort=80,toPort=80,protocol=TCP
    
    # Open HTTPS (443)
    aws lightsail open-instance-public-ports \
        --instance-name "$LIGHTSAIL_INSTANCE_NAME" \
        --port-info fromPort=443,toPort=443,protocol=TCP
    
    # Open SSH (22) - should already be open
    aws lightsail open-instance-public-ports \
        --instance-name "$LIGHTSAIL_INSTANCE_NAME" \
        --port-info fromPort=22,toPort=22,protocol=TCP
    
    print_status "Firewall configured"
}

# Function to deploy application
deploy_application() {
    INSTANCE_IP=$(get_instance_ip)
    print_status "Deploying application to $INSTANCE_IP"
    
    # Create deployment package
    print_status "Creating deployment package..."
    tar -czf handreceipt-deploy.tar.gz \
        docker-compose.yml \
        nginx.conf \
        prometheus.yml \
        production.env \
        ssl/ \
        ../../deployments/docker/
    
    # Copy files to instance
    print_status "Copying files to instance..."
    scp -o StrictHostKeyChecking=no -i $SSH_KEY_PATH \
        handreceipt-deploy.tar.gz ubuntu@${INSTANCE_IP}:/home/ubuntu/
    
    # Deploy on instance
    print_status "Deploying on instance..."
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY_PATH ubuntu@${INSTANCE_IP} << 'EOF'
        # Extract deployment package
        tar -xzf handreceipt-deploy.tar.gz
        
        # Load environment variables
        export $(cat production.env | xargs)
        
        # Start services
        docker-compose up -d
        
        # Show status
        docker-compose ps
EOF
    
    # Clean up
    rm handreceipt-deploy.tar.gz
    
    print_status "Deployment complete!"
    print_status "Application should be available at: http://$INSTANCE_IP"
    print_status "HTTPS: https://$INSTANCE_IP (with self-signed certificate)"
    print_status "Grafana: http://$INSTANCE_IP:3000 (admin/admin)"
}

# Main deployment flow
main() {
    echo "Starting deployment process..."
    
    # Create user data script
    cat > user-data.sh << 'EOF'
#!/bin/bash
# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Git
apt-get install -y git

# Create app directory
mkdir -p /home/ubuntu/handreceipt
chown ubuntu:ubuntu /home/ubuntu/handreceipt
EOF
    
    create_lightsail_instance
    configure_firewall
    
    # Wait a bit for the instance to fully initialize
    print_status "Waiting for instance to fully initialize..."
    sleep 60
    
    deploy_application
    
    # Clean up
    rm user-data.sh
    
    print_status "🎉 Deployment completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Update your DNS to point to the instance IP: $(get_instance_ip)"
    echo "2. Replace self-signed certificates with proper SSL certificates"
    echo "3. Update production.env with secure passwords"
    echo "4. Monitor the application using Grafana at http://$(get_instance_ip):3000"
}

# Check command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "status")
        if aws lightsail get-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME" &> /dev/null; then
            INSTANCE_IP=$(get_instance_ip)
            STATE=$(aws lightsail get-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME" --query 'instance.state.name' --output text)
            print_status "Instance: $LIGHTSAIL_INSTANCE_NAME"
            print_status "State: $STATE"
            print_status "IP: $INSTANCE_IP"
            print_status "URL: http://$INSTANCE_IP"
        else
            print_error "Instance $LIGHTSAIL_INSTANCE_NAME not found"
        fi
        ;;
    "destroy")
        print_warning "This will destroy the instance $LIGHTSAIL_INSTANCE_NAME"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aws lightsail delete-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME"
            print_status "Instance deletion initiated"
        fi
        ;;
    *)
        echo "Usage: $0 [deploy|status|destroy]"
        echo "  deploy  - Deploy the application (default)"
        echo "  status  - Show instance status"
        echo "  destroy - Destroy the instance"
        ;;
esac 