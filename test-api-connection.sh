#!/bin/bash

# API Connection Test Script
echo "🧪 Testing HandReceipt API Connection"
echo "===================================="

# Test 1: DNS Resolution
echo "🌐 Test 1: DNS Resolution"
echo -n "Testing api.handreceipt.com: "
if nslookup api.handreceipt.com > /dev/null 2>&1; then
    IP=$(nslookup api.handreceipt.com | grep "Address:" | tail -1 | awk '{print $2}')
    if [ "$IP" = "44.193.254.155" ]; then
        echo "✅ PASS - Resolves to correct IP ($IP)"
    else
        echo "⚠️  WARN - Resolves to $IP (expected 44.193.254.155)"
    fi
else
    echo "❌ FAIL - DNS not resolving"
fi

echo

# Test 2: HTTP Connection
echo "🔗 Test 2: HTTP Connection"
echo -n "Testing HTTP api endpoint: "
if curl -s -o /dev/null -w "%{http_code}" http://44.193.254.155:8080/api/auth/me | grep -q "401"; then
    echo "✅ PASS - Backend responding"
else
    echo "❌ FAIL - Backend not responding"
fi

echo

# Test 3: HTTPS Connection (if DNS works)
echo "🔒 Test 3: HTTPS Connection"
echo -n "Testing HTTPS api endpoint: "
if nslookup api.handreceipt.com > /dev/null 2>&1; then
    if curl -s -o /dev/null -w "%{http_code}" https://api.handreceipt.com/api/auth/me 2>/dev/null | grep -q "401"; then
        echo "✅ PASS - HTTPS working"
    else
        echo "❌ FAIL - HTTPS not working (SSL not configured yet?)"
    fi
else
    echo "⏭️  SKIP - DNS not configured"
fi

echo

# Test 4: Frontend Configuration
echo "🖥️  Test 4: Frontend Configuration"
if [ -f "web/.env.production" ]; then
    API_URL=$(grep VITE_API_URL web/.env.production | cut -d'=' -f2)
    echo "Frontend API URL: $API_URL"
    if [ "$API_URL" = "https://api.handreceipt.com/api" ]; then
        echo "✅ PASS - Frontend configured for HTTPS"
    elif [ "$API_URL" = "http://44.193.254.155:8080/api" ]; then
        echo "⚠️  TEMP - Frontend using direct IP (update after SSL)"
    else
        echo "❌ FAIL - Frontend misconfigured"
    fi
else
    echo "❌ FAIL - No production environment file found"
fi

echo
echo "📋 Summary:"
echo "1. Add DNS A record: api.handreceipt.com → 44.193.254.155"
echo "2. SSH to Lightsail and run: sudo certbot --nginx -d api.handreceipt.com"
echo "3. Update frontend: VITE_API_URL=https://api.handreceipt.com/api"
echo "4. Redeploy frontend: ./deploy-frontend.sh" 