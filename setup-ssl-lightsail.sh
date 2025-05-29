#!/bin/bash

# SSL Setup Script for HandReceipt API
echo "🔒 Setting up SSL certificate for api.handreceipt.com"

# Configuration
DOMAIN="api.handreceipt.com"
INSTANCE_NAME="handreceipt-primary"
REGION="us-east-1"

echo "📋 Configuration:"
echo "  Domain: $DOMAIN"
echo "  Instance: $INSTANCE_NAME"
echo "  Region: $REGION"
echo

# Step 1: Create SSL certificate in AWS Certificate Manager
echo "🏗️ Step 1: Creating SSL certificate in ACM..."
echo "Run this command:"
echo
echo "aws acm request-certificate \\"
echo "  --domain-name $DOMAIN \\"
echo "  --validation-method DNS \\"
echo "  --region $REGION"
echo
echo "📝 Note the Certificate ARN from the output!"
echo
read -p "Press Enter after you've run the command and noted the ARN..."

echo
echo "🔍 Step 2: Get DNS validation records"
echo "Run this command (replace CERTIFICATE_ARN with your actual ARN):"
echo
echo "aws acm describe-certificate \\"
echo "  --certificate-arn YOUR_CERTIFICATE_ARN \\"
echo "  --region $REGION"
echo
echo "📝 Add the CNAME record shown in DomainValidationOptions to your DNS!"
echo
read -p "Press Enter after you've added the DNS validation record..."

echo
echo "⏳ Step 3: Wait for certificate validation"
echo "Run this command to check status:"
echo
echo "aws acm describe-certificate \\"
echo "  --certificate-arn YOUR_CERTIFICATE_ARN \\"
echo "  --region $REGION \\"
echo "  --query 'Certificate.Status'"
echo
echo "✅ Wait until status shows 'ISSUED'"
echo
read -p "Press Enter when certificate is ISSUED..."

echo
echo "🌐 Step 4: Attach certificate to Lightsail load balancer"
echo "You'll need to:"
echo "1. Create a Lightsail Load Balancer"
echo "2. Attach your instance to it"
echo "3. Import the ACM certificate"

echo
echo "🎯 Alternative: Let's Encrypt (Recommended)"
echo "SSH to your Lightsail instance and run:"
echo
echo "sudo apt update"
echo "sudo apt install certbot python3-certbot-nginx"
echo "sudo certbot --nginx -d $DOMAIN"
echo
echo "This will automatically configure nginx with SSL!"

echo
echo "✅ SSL setup guide complete!"
echo "Choose either ACM + Load Balancer OR Let's Encrypt + nginx" 