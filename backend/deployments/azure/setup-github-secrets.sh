#!/bin/bash

# HandReceipt Azure GitHub Secrets Setup Script
# This script helps you configure GitHub secrets for Azure deployment

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Please install it first:"
    echo "  macOS: brew install gh"
    echo "  Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first:"
    echo "  macOS: brew install azure-cli"
    echo "  Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    print_error "Not logged in to GitHub CLI. Please run: gh auth login"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run: az login"
    exit 1
fi

print_status "Setting up GitHub secrets for Azure deployment..."

# Get repository information
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
print_status "Repository: $REPO"

# Get Azure subscription information
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
print_status "Azure Subscription ID: $SUBSCRIPTION_ID"
print_status "Azure Tenant ID: $TENANT_ID"

# Create service principal for GitHub Actions
print_status "Creating Azure service principal for GitHub Actions..."
SP_NAME="github-actions-handreceipt-$(date +%s)"

# Create service principal with contributor role
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role contributor \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --sdk-auth)

# Extract client ID from the output
CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r .clientId)

print_success "Service principal created: $CLIENT_ID"

# Set GitHub secrets
print_status "Setting GitHub secrets..."

# Azure credentials
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"

# PostgreSQL admin password
print_status "Enter PostgreSQL admin password (will be hidden):"
read -s POSTGRES_PASSWORD
echo
gh secret set POSTGRES_ADMIN_PASSWORD --body "$POSTGRES_PASSWORD"

# Optional: Set additional secrets
print_status "Do you want to set AWS credentials for frontend deployment? (y/n)"
read -r SET_AWS
if [[ "$SET_AWS" == "y" ]]; then
    print_status "Enter AWS Access Key ID:"
    read -r AWS_ACCESS_KEY_ID
    gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
    
    print_status "Enter AWS Secret Access Key (will be hidden):"
    read -s AWS_SECRET_ACCESS_KEY
    echo
    gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
fi

# List all secrets
print_status "GitHub secrets configured:"
gh secret list

print_success "GitHub secrets setup complete!"
print_status "You can now run the Azure deployment workflow from GitHub Actions."
print_status "Go to: https://github.com/$REPO/actions/workflows/deploy-azure.yml"

# Save service principal information
print_warning "IMPORTANT: Save the following service principal information:"
echo "$SP_OUTPUT" > azure-sp-credentials.json
print_status "Service principal credentials saved to: azure-sp-credentials.json"
print_warning "Keep this file secure and do not commit it to git!"

# Add to .gitignore
if ! grep -q "azure-sp-credentials.json" .gitignore 2>/dev/null; then
    echo "azure-sp-credentials.json" >> .gitignore
    print_status "Added azure-sp-credentials.json to .gitignore"
fi 