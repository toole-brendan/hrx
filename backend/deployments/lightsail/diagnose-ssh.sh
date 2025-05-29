#!/bin/bash

# SSH Diagnostic Script for HandReceipt Lightsail Instance

echo "🔍 HandReceipt Lightsail SSH Diagnostics"
echo "========================================"
echo ""

# Configuration
INSTANCE_NAME="handreceipt-primary"
REGION="us-east-1"
STATIC_IP="44.193.254.155"

# Check AWS CLI
echo "1. Checking AWS CLI configuration..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo "✅ AWS CLI is configured"
    aws sts get-caller-identity --query '{Account:Account, User:Arn}' --output table
else
    echo "❌ AWS CLI is not configured. Run: aws configure"
    exit 1
fi
echo ""

# Check instance status
echo "2. Checking instance status..."
INSTANCE_STATUS=$(aws lightsail get-instances \
    --region $REGION \
    --query "instances[?name=='$INSTANCE_NAME'].state.name" \
    --output text 2>/dev/null)

if [ -z "$INSTANCE_STATUS" ]; then
    echo "❌ Instance $INSTANCE_NAME not found in region $REGION"
    exit 1
else
    echo "✅ Instance status: $INSTANCE_STATUS"
fi
echo ""

# Check static IP
echo "3. Checking static IP..."
ACTUAL_STATIC_IP=$(aws lightsail get-static-ips \
    --region $REGION \
    --query "staticIps[?name=='${INSTANCE_NAME}-ip'].ipAddress" \
    --output text 2>/dev/null)

if [ -z "$ACTUAL_STATIC_IP" ]; then
    echo "⚠️  No static IP found"
    INSTANCE_IP=$(aws lightsail get-instances \
        --region $REGION \
        --query "instances[?name=='$INSTANCE_NAME'].publicIpAddress" \
        --output text)
    echo "Using instance public IP: $INSTANCE_IP"
    TARGET_IP=$INSTANCE_IP
else
    echo "✅ Static IP: $ACTUAL_STATIC_IP"
    TARGET_IP=$ACTUAL_STATIC_IP
fi
echo ""

# Check key pairs
echo "4. Checking SSH key pairs..."
KEY_PAIRS=$(aws lightsail get-key-pairs \
    --region $REGION \
    --query "keyPairs[*].name" \
    --output text)

echo "Available key pairs in $REGION: $KEY_PAIRS"

# Check for specific key
INSTANCE_KEY=$(aws lightsail get-instances \
    --region $REGION \
    --query "instances[?name=='$INSTANCE_NAME'].sshKeyName" \
    --output text)

echo "Instance is using key: $INSTANCE_KEY"

# Check local keys
echo ""
echo "5. Checking local SSH keys..."
for key in handreceipt-key "handreceipt-key-${REGION}" "${INSTANCE_KEY}"; do
    KEY_PATH="$HOME/.ssh/$key"
    if [ -f "$KEY_PATH" ]; then
        echo "✅ Found key: $KEY_PATH"
        PERMS=$(stat -c %a "$KEY_PATH" 2>/dev/null || stat -f %p "$KEY_PATH" 2>/dev/null | cut -c 4-6)
        if [ "$PERMS" = "600" ]; then
            echo "   ✅ Permissions correct (600)"
        else
            echo "   ❌ Wrong permissions: $PERMS (should be 600)"
            echo "   Run: chmod 600 $KEY_PATH"
        fi
    else
        echo "❌ Missing key: $KEY_PATH"
    fi
done
echo ""

# Check network connectivity
echo "6. Testing network connectivity..."
if ping -c 1 -W 2 $TARGET_IP > /dev/null 2>&1; then
    echo "✅ Can ping $TARGET_IP"
else
    echo "⚠️  Cannot ping $TARGET_IP (this might be normal if ICMP is blocked)"
fi

# Check SSH port
echo ""
echo "7. Testing SSH port (22)..."
if nc -z -w2 $TARGET_IP 22 2>/dev/null; then
    echo "✅ Port 22 is open"
else
    echo "❌ Port 22 appears closed or filtered"
fi

# Check firewall rules
echo ""
echo "8. Checking Lightsail firewall rules..."
PORTS=$(aws lightsail get-instance-port-states \
    --instance-name $INSTANCE_NAME \
    --region $REGION \
    --query "portStates[?protocol=='tcp' && fromPort==22].state" \
    --output text 2>/dev/null)

if [ "$PORTS" = "open" ]; then
    echo "✅ SSH port is open in Lightsail firewall"
else
    echo "❌ SSH port might not be open in firewall"
fi

# Try SSH connections
echo ""
echo "9. Testing SSH connections..."
for key in handreceipt-key "handreceipt-key-${REGION}" "${INSTANCE_KEY}"; do
    KEY_PATH="$HOME/.ssh/$key"
    if [ -f "$KEY_PATH" ]; then
        echo ""
        echo "Trying with key: $KEY_PATH"
        if ssh -o ConnectTimeout=5 \
             -o StrictHostKeyChecking=no \
             -o PasswordAuthentication=no \
             -o BatchMode=yes \
             -i "$KEY_PATH" \
             ubuntu@$TARGET_IP \
             "echo 'SSH SUCCESS with $key'" 2>&1 | grep -q "SUCCESS"; then
            echo "✅ SSH connection successful with $key!"
            echo ""
            echo "Use this command to connect:"
            echo "ssh -i $KEY_PATH ubuntu@$TARGET_IP"
            exit 0
        else
            echo "❌ SSH failed with $key"
            # Show the actual error
            ssh -o ConnectTimeout=5 \
                -o StrictHostKeyChecking=no \
                -o PasswordAuthentication=no \
                -o BatchMode=yes \
                -vv \
                -i "$KEY_PATH" \
                ubuntu@$TARGET_IP \
                "exit" 2>&1 | grep -E "(Permission denied|Connection refused|No route|timeout|authentication)" | head -5
        fi
    fi
done

echo ""
echo "📋 Summary and Recommendations:"
echo "================================"
echo ""

if [ -z "$INSTANCE_KEY" ]; then
    echo "❌ No SSH key associated with the instance"
else
    echo "The instance expects key: $INSTANCE_KEY"
    
    KEY_PATH="$HOME/.ssh/$INSTANCE_KEY"
    if [ ! -f "$KEY_PATH" ]; then
        echo ""
        echo "🔧 To fix SSH access:"
        echo ""
        echo "Option 1: Download the key from Lightsail console"
        echo "   1. Go to https://lightsail.aws.amazon.com/"
        echo "   2. Click on 'Account' → 'SSH keys'"
        echo "   3. Download '$INSTANCE_KEY'"
        echo "   4. Save to: $KEY_PATH"
        echo "   5. chmod 600 $KEY_PATH"
        echo ""
        echo "Option 2: Use browser-based SSH"
        echo "   1. Go to Lightsail console"
        echo "   2. Click on instance '$INSTANCE_NAME'"
        echo "   3. Click 'Connect using SSH'"
        echo ""
        echo "Option 3: Create new key and add to instance"
        echo "   Run: ./fix-ssh-access.sh"
    fi
fi

echo ""
echo "Instance details:"
echo "  Name: $INSTANCE_NAME"
echo "  IP: $TARGET_IP"
echo "  Region: $REGION"
echo "  Key: $INSTANCE_KEY" 