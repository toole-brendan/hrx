#!/bin/bash

# HandReceipt Azure Deployment Script
# This script automates the deployment of HandReceipt application to Azure

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-handreceipt-prod-rg}"
LOCATION="${LOCATION:-eastus2}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
BASE_NAME="${BASE_NAME:-handreceipt}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-98b9185a-60b8-4df4-b8a4-73e6d35b176f}"
POSTGRES_ADMIN_PASSWORD="${POSTGRES_ADMIN_PASSWORD}"

# Derived variables
RESOURCE_PREFIX="${BASE_NAME}-${ENVIRONMENT}"
CONTAINER_REGISTRY_NAME="${BASE_NAME}${ENVIRONMENT}acr"
KEY_VAULT_NAME="${RESOURCE_PREFIX}-kv"
POSTGRES_SERVER_NAME="${RESOURCE_PREFIX}-postgres"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check required environment variables
    if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
        print_error "SUBSCRIPTION_ID environment variable is required."
        exit 1
    fi
    
    if [[ -z "${POSTGRES_ADMIN_PASSWORD:-}" ]]; then
        print_error "POSTGRES_ADMIN_PASSWORD environment variable is required."
        exit 1
    fi
    
    print_success "Prerequisites check passed."
}

# Function to set Azure subscription
set_subscription() {
    print_status "Setting Azure subscription to $SUBSCRIPTION_ID..."
    az account set --subscription "$SUBSCRIPTION_ID"
    
    # Verify the subscription is set correctly
    CURRENT_SUB=$(az account show --query id --output tsv)
    if [ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]; then
        print_error "Failed to set subscription. Current: $CURRENT_SUB, Expected: $SUBSCRIPTION_ID"
        exit 1
    fi
    print_success "Subscription set successfully."
}

# Function to create resource group
create_resource_group() {
    print_status "Creating resource group $RESOURCE_GROUP in $LOCATION..."
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group $RESOURCE_GROUP already exists."
        # Check if it's in the right location
        EXISTING_LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location --output tsv)
        if [ "$EXISTING_LOCATION" != "$LOCATION" ]; then
            print_warning "Resource group is in $EXISTING_LOCATION, but deployment expects $LOCATION"
            print_status "Continuing with existing resource group location: $EXISTING_LOCATION"
            LOCATION="$EXISTING_LOCATION"
        fi
    else
        az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --tags Environment="$ENVIRONMENT" Application="$BASE_NAME" Owner="toole.brendan@gmail.com"
        print_success "Resource group created successfully."
    fi
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying Azure infrastructure..."
    
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file "infrastructure.bicep" \
        --parameters environment="$ENVIRONMENT" \
                    baseName="$BASE_NAME" \
                    location="$LOCATION" \
                    postgresAdminPassword="$POSTGRES_ADMIN_PASSWORD" \
        --mode Complete \
        --verbose
    
    print_success "Infrastructure deployed successfully."
}

# Function to get deployment outputs
get_deployment_outputs() {
    print_status "Retrieving deployment outputs..."
    
    OUTPUTS=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "infrastructure" \
        --query "properties.outputs" \
        --output json)
    
    CONTAINER_REGISTRY_LOGIN_SERVER=$(echo "$OUTPUTS" | jq -r '.containerRegistryLoginServer.value')
    POSTGRES_SERVER_FQDN=$(echo "$OUTPUTS" | jq -r '.postgresServerFqdn.value')
    STORAGE_ACCOUNT_NAME=$(echo "$OUTPUTS" | jq -r '.storageAccountName.value')
    CONTAINER_APPS_ENVIRONMENT_ID=$(echo "$OUTPUTS" | jq -r '.containerAppsEnvironmentId.value')
    
    print_success "Deployment outputs retrieved."
}

# Function to configure Key Vault access policies
configure_key_vault_access() {
    print_status "Configuring Key Vault access policies..."
    
    # Get current user object ID
    USER_OBJECT_ID=$(az ad signed-in-user show --query "id" --output tsv)
    
    # Grant current user access to Key Vault
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --object-id "$USER_OBJECT_ID" \
        --secret-permissions get list set delete backup restore recover purge
    
    print_success "Key Vault access policies configured."
}

# Function to build and push Docker images
build_and_push_images() {
    print_status "Building and pushing Docker images..."
    
    # Log in to Azure Container Registry
    az acr login --name "$CONTAINER_REGISTRY_NAME"
    
    # Build and push main application image
    print_status "Building main application image..."
    docker build -t "$CONTAINER_REGISTRY_LOGIN_SERVER/handreceipt-backend:latest" \
        -f ../../Dockerfile ../../
    docker push "$CONTAINER_REGISTRY_LOGIN_SERVER/handreceipt-backend:latest"
    
    # Build and push worker image
    print_status "Building worker image..."
    docker build -t "$CONTAINER_REGISTRY_LOGIN_SERVER/handreceipt-worker:latest" \
        -f ../../Dockerfile.worker ../../
    docker push "$CONTAINER_REGISTRY_LOGIN_SERVER/handreceipt-worker:latest"
    
    print_success "Docker images built and pushed successfully."
}

# Function to update Container Apps configurations
update_container_apps_configs() {
    print_status "Updating Container Apps configurations..."
    
    # Update the YAML files with actual values
    sed -i "s/{subscription-id}/$SUBSCRIPTION_ID/g" container-apps/*.yml
    sed -i "s/{resource-group}/$RESOURCE_GROUP/g" container-apps/*.yml
    
    print_success "Container Apps configurations updated."
}

# Function to deploy Container Apps
deploy_container_apps() {
    print_status "Deploying Container Apps..."
    
    # No need to deploy ImmuDB - using Azure SQL Database ledger tables instead
    
    # Deploy backend API
    print_status "Deploying backend API..."
    az containerapp create \
        --resource-group "$RESOURCE_GROUP" \
        --yaml container-apps/backend-api.yml
    
    # Deploy worker
    print_status "Deploying worker..."
    az containerapp create \
        --resource-group "$RESOURCE_GROUP" \
        --yaml container-apps/worker.yml
    
    print_success "Container Apps deployed successfully."
}

# Function to configure custom domain (optional)
configure_custom_domain() {
    if [[ -n "${CUSTOM_DOMAIN:-}" ]]; then
        print_status "Configuring custom domain: $CUSTOM_DOMAIN"
        
        # Add custom domain to backend API
        az containerapp hostname add \
            --resource-group "$RESOURCE_GROUP" \
            --name "handreceipt-backend-api" \
            --hostname "$CUSTOM_DOMAIN"
        
        print_success "Custom domain configured successfully."
        print_warning "Please ensure your DNS is pointing to the Container App's FQDN."
    else
        print_warning "No custom domain specified. Skipping custom domain configuration."
    fi
}

# Function to test deployment
test_deployment() {
    print_status "Testing deployment..."
    
    # Get the backend API URL
    BACKEND_URL=$(az containerapp show \
        --resource-group "$RESOURCE_GROUP" \
        --name "handreceipt-backend-api" \
        --query "properties.configuration.ingress.fqdn" \
        --output tsv)
    
    # Test health endpoint
    if curl -f "https://$BACKEND_URL/health" &> /dev/null; then
        print_success "Health check passed. Application is running at: https://$BACKEND_URL"
    else
        print_warning "Health check failed. Please check application logs."
    fi
}

# Function to display deployment information
display_deployment_info() {
    print_status "Deployment Summary:"
    echo "=================================================="
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Location: $LOCATION"
    echo "Environment: $ENVIRONMENT"
    echo "Container Registry: $CONTAINER_REGISTRY_LOGIN_SERVER"
    echo "PostgreSQL Server: $POSTGRES_SERVER_FQDN"
    echo "Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "Key Vault: $KEY_VAULT_NAME"
    
    if [[ -n "${BACKEND_URL:-}" ]]; then
        echo "Backend API URL: https://$BACKEND_URL"
    fi
    
    echo "=================================================="
    
    print_success "Deployment completed successfully!"
    print_status "Next steps:"
    echo "1. Update your DNS records to point to the new endpoints"
    echo "2. Migrate your data using the migration scripts"
    echo "3. Test all application functionality"
    echo "4. Update your frontend configurations"
}

# Main execution flow
main() {
    print_status "Starting HandReceipt Azure deployment..."
    
    check_prerequisites
    set_subscription
    create_resource_group
    deploy_infrastructure
    get_deployment_outputs
    configure_key_vault_access
    build_and_push_images
    update_container_apps_configs
    deploy_container_apps
    configure_custom_domain
    test_deployment
    display_deployment_info
    
    print_success "Deployment script completed successfully!"
}

# Script help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help                   Show this help message"
    echo "  --resource-group NAME        Resource group name (default: handreceipt-prod-rg)"
    echo "  --location LOCATION          Azure region (default: eastus2)"
    echo "  --environment ENV            Environment name (default: prod)"
    echo "  --base-name NAME             Base name for resources (default: handreceipt)"
    echo ""
    echo "Required Environment Variables:"
    echo "  SUBSCRIPTION_ID              Azure subscription ID"
    echo "  POSTGRES_ADMIN_PASSWORD      PostgreSQL administrator password"
    echo ""
    echo "Optional Environment Variables:"
    echo "  CUSTOM_DOMAIN               Custom domain for the application"
    echo ""
    echo "Example:"
    echo "  export SUBSCRIPTION_ID=\"your-subscription-id\""
    echo "  export POSTGRES_ADMIN_PASSWORD=\"YourSecurePassword123!\""
    echo "  export CUSTOM_DOMAIN=\"handreceipt.yourdomain.com\""
    echo "  $0 --resource-group my-rg --location westus2"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --base-name)
            BASE_NAME="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main 