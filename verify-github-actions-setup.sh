#!/bin/bash

# GitHub Actions Setup Verification Script
echo "🔍 HandReceipt GitHub Actions Setup Verification"
echo "==============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LIGHTSAIL_IP="44.193.254.155"
API_DOMAIN="api.handreceipt.com"
FRONTEND_DOMAIN="handreceipt.com"

echo
echo "📋 Checking prerequisites for GitHub Actions deployment..."
echo

# Check 1: AWS CLI Configuration
echo "1️⃣ AWS CLI Configuration"
if command -v aws &> /dev/null; then
    if aws configure list | grep -q "access_key"; then
        echo -e "   ${GREEN}✅ AWS CLI is configured${NC}"
        echo "   Access Key: $(aws configure get aws_access_key_id | cut -c1-8)..."
        echo "   Region: $(aws configure get region)"
    else
        echo -e "   ${RED}❌ AWS CLI not configured${NC}"
        echo "   Run: aws configure"
    fi
else
    echo -e "   ${RED}❌ AWS CLI not installed${NC}"
    echo "   Install: https://aws.amazon.com/cli/"
fi

echo

# Check 2: Lightsail Instance Status
echo "2️⃣ Lightsail Instance Status"
if command -v aws &> /dev/null && aws configure list | grep -q "access_key"; then
    INSTANCE_STATUS=$(aws lightsail get-instance --instance-name handreceipt-primary --query 'instance.state.name' --output text 2>/dev/null)
    if [ "$INSTANCE_STATUS" = "running" ]; then
        echo -e "   ${GREEN}✅ Lightsail instance is running${NC}"
        INSTANCE_IP=$(aws lightsail get-instance --instance-name handreceipt-primary --query 'instance.publicIpAddress' --output text 2>/dev/null)
        echo "   Instance IP: $INSTANCE_IP"
    else
        echo -e "   ${YELLOW}⚠️  Lightsail instance status: $INSTANCE_STATUS${NC}"
    fi
else
    echo -e "   ${YELLOW}⏭️  Skipped (AWS CLI not configured)${NC}"
fi

echo

# Check 3: Backend Connectivity
echo "3️⃣ Backend API Connectivity"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$LIGHTSAIL_IP:8080/api/auth/me" 2>/dev/null)
if [ "$HTTP_CODE" = "401" ]; then
    echo -e "   ${GREEN}✅ Backend API is responding${NC}"
    echo "   Direct IP test: HTTP $HTTP_CODE (expected)"
else
    echo -e "   ${RED}❌ Backend API not responding${NC}"
    echo "   Direct IP test: HTTP $HTTP_CODE"
fi

echo

# Check 4: DNS Resolution
echo "4️⃣ DNS Resolution"
if nslookup $API_DOMAIN 2>/dev/null | grep -q "$LIGHTSAIL_IP"; then
    echo -e "   ${GREEN}✅ DNS is working for $API_DOMAIN${NC}"
    echo "   Resolves to: $LIGHTSAIL_IP"
    
    # Test HTTPS if DNS works
    HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$API_DOMAIN/api/auth/me" 2>/dev/null)
    if [ "$HTTPS_CODE" = "401" ]; then
        echo -e "   ${GREEN}✅ HTTPS is working${NC}"
    else
        echo -e "   ${YELLOW}⚠️  HTTPS not working yet (will be set up automatically)${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  DNS not working yet for $API_DOMAIN${NC}"
    echo "   This is okay - GitHub Actions will use direct IP until DNS works"
fi

echo

# Check 5: Frontend Status
echo "5️⃣ Frontend Status"
FRONTEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$FRONTEND_DOMAIN" 2>/dev/null)
if [ "$FRONTEND_CODE" = "200" ]; then
    echo -e "   ${GREEN}✅ Frontend is accessible${NC}"
    echo "   URL: https://$FRONTEND_DOMAIN"
else
    echo -e "   ${RED}❌ Frontend not accessible${NC}"
    echo "   HTTP code: $FRONTEND_CODE"
fi

echo

# Check 6: Required Files
echo "6️⃣ Required Files"
if [ -f ".github/workflows/deploy-production.yml" ]; then
    echo -e "   ${GREEN}✅ GitHub Actions workflow file exists${NC}"
else
    echo -e "   ${RED}❌ GitHub Actions workflow file missing${NC}"
    echo "   Expected: .github/workflows/deploy-production.yml"
fi

if [ -f "deploy-frontend.sh" ]; then
    echo -e "   ${GREEN}✅ Frontend deployment script exists${NC}"
else
    echo -e "   ${YELLOW}⚠️  Frontend deployment script missing${NC}"
    echo "   Expected: deploy-frontend.sh"
fi

echo

# Check 7: SSH Key Preparation
echo "7️⃣ SSH Key for Lightsail"
SSH_KEYS=$(find ~/.ssh -name "*.pem" -o -name "*lightsail*" -o -name "*handreceipt*" 2>/dev/null | head -3)
if [ -n "$SSH_KEYS" ]; then
    echo -e "   ${GREEN}✅ Found potential SSH keys:${NC}"
    echo "$SSH_KEYS" | while read key; do
        echo "   - $key"
    done
    echo "   💡 You'll need to add one of these to GitHub Secrets as LIGHTSAIL_SSH_PRIVATE_KEY"
else
    echo -e "   ${YELLOW}⚠️  No obvious SSH keys found${NC}"
    echo "   💡 You may need to generate a new SSH key for Lightsail access"
fi

echo

# Summary and Recommendations
echo "📋 SETUP SUMMARY"
echo "=================="

echo
echo "🔑 GitHub Secrets You Need to Add:"
echo "   AWS_ACCESS_KEY_ID: $(aws configure get aws_access_key_id 2>/dev/null | cut -c1-8)... (from AWS CLI)"
echo "   AWS_SECRET_ACCESS_KEY: [Your AWS secret key]"
echo "   LIGHTSAIL_SSH_PRIVATE_KEY: [Contents of your SSH private key]"
echo "   ADMIN_EMAIL: [Your email for SSL certificates]"

echo
echo "🎯 Recommended Next Steps:"

if [ "$HTTP_CODE" != "401" ]; then
    echo "   1. ❗ Fix backend connectivity first"
    echo "      - Check if your Lightsail instance is running"
    echo "      - Verify backend is deployed and running on port 8080"
fi

if ! aws configure list | grep -q "access_key"; then
    echo "   2. ❗ Configure AWS CLI: aws configure"
fi

echo "   3. 📤 Push your code to GitHub repository"
echo "   4. 🔑 Add the GitHub Secrets listed above"
echo "   5. 🚀 Run the GitHub Actions workflow"

echo
echo "🔍 Test Commands:"
echo "   # Test current setup locally:"
echo "   ./test-api-connection.sh"
echo
echo "   # Test manual deployment:"
echo "   ./deploy-frontend.sh"

echo
echo "🌐 Expected Workflow Behavior:"
if nslookup $API_DOMAIN 2>/dev/null | grep -q "$LIGHTSAIL_IP"; then
    if [ "$HTTPS_CODE" = "401" ]; then
        echo "   - Will use: https://$API_DOMAIN/api (DNS + SSL working)"
    else
        echo "   - Will use: http://$API_DOMAIN/api (DNS working, will set up SSL)"
    fi
else
    echo "   - Will use: http://$LIGHTSAIL_IP:8080/api (DNS not ready yet)"
    echo "   - Will automatically switch to DNS when it's ready"
fi

echo
echo "✅ Verification complete! Check the items above before running GitHub Actions." 