#!/bin/bash

# Test script for PUB LOG integration with NSN service

set -e

echo "=== PUB LOG Integration Test Script ==="
echo ""

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8080/api}"
AUTH_TOKEN="${AUTH_TOKEN:-}"  # Set this or script will try to login

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to make authenticated API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -z "$AUTH_TOKEN" ]; then
        echo -e "${RED}Error: No authentication token. Please set AUTH_TOKEN environment variable${NC}"
        exit 1
    fi
    
    if [ -z "$data" ]; then
        curl -s -X "$method" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -H "Content-Type: application/json" \
            "$API_BASE_URL$endpoint"
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_BASE_URL$endpoint"
    fi
}

# Function to pretty print JSON
pretty_json() {
    echo "$1" | jq '.' 2>/dev/null || echo "$1"
}

# Function to test an endpoint
test_endpoint() {
    local test_name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected_field=$5
    
    echo -n "Testing $test_name... "
    
    response=$(api_call "$method" "$endpoint" "$data")
    
    if echo "$response" | jq -e "$expected_field" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        if [ "$VERBOSE" = "true" ]; then
            echo "Response:"
            pretty_json "$response"
            echo ""
        fi
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "Response:"
        pretty_json "$response"
        echo ""
        return 1
    fi
}

# Login if no token provided
if [ -z "$AUTH_TOKEN" ]; then
    echo "No AUTH_TOKEN provided. Attempting to login..."
    echo -n "Username: "
    read username
    echo -n "Password: "
    read -s password
    echo ""
    
    login_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$username\",\"password\":\"$password\"}" \
        "$API_BASE_URL/auth/login")
    
    AUTH_TOKEN=$(echo "$login_response" | jq -r '.access_token // empty')
    
    if [ -z "$AUTH_TOKEN" ]; then
        echo -e "${RED}Login failed${NC}"
        pretty_json "$login_response"
        exit 1
    fi
    
    echo -e "${GREEN}Login successful${NC}"
    echo ""
fi

# Run tests
echo "Running PUB LOG Integration Tests..."
echo "================================="
echo ""

# Test 1: NSN Lookup with known NSN from publog data
test_endpoint \
    "NSN Lookup (5820-01-546-5288)" \
    "GET" \
    "/nsn/5820-01-546-5288" \
    "" \
    '.success == true and .data.nsn != null'

# Test 2: Universal Search - NSN format
test_endpoint \
    "Universal Search - NSN format" \
    "GET" \
    "/nsn/universal-search?q=5820-01-546-5288" \
    "" \
    '.success == true and .count > 0'

# Test 3: Universal Search - Part Number
test_endpoint \
    "Universal Search - Part Number (12003100)" \
    "GET" \
    "/nsn/universal-search?q=12003100" \
    "" \
    '.success == true'

# Test 4: Universal Search - Item Name
test_endpoint \
    "Universal Search - Item Name (camera television)" \
    "GET" \
    "/nsn/universal-search?q=camera+television" \
    "" \
    '.success == true and .count > 0'

# Test 5: Regular NSN Search
test_endpoint \
    "Regular NSN Search (camera)" \
    "GET" \
    "/nsn/search?q=camera&limit=10" \
    "" \
    '.success == true'

# Test 6: Bulk NSN Lookup
test_endpoint \
    "Bulk NSN Lookup" \
    "POST" \
    "/nsn/bulk" \
    '{"nsns":["5820-01-546-5288","5820-01-234-5678"]}' \
    '.success == true and .data != null'

# Test 7: NSN Statistics
test_endpoint \
    "NSN Statistics" \
    "GET" \
    "/nsn/stats" \
    "" \
    '.success == true and .data != null'

# Test 8: Cache Statistics
test_endpoint \
    "Cache Statistics" \
    "GET" \
    "/nsn/cache/stats" \
    "" \
    '.success == true and .data != null'

echo ""
echo "================================="
echo "Test Summary:"
echo ""

# Performance test
echo "Performance Test - Universal Search:"
echo -n "Searching for 'radio'... "
start_time=$(date +%s%N)
response=$(api_call "GET" "/nsn/universal-search?q=radio&limit=50" "")
end_time=$(date +%s%N)
elapsed=$((($end_time - $start_time) / 1000000))

if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
    count=$(echo "$response" | jq -r '.count // 0')
    echo -e "${GREEN}Found $count results in ${elapsed}ms${NC}"
else
    echo -e "${RED}Failed${NC}"
fi

echo ""
echo "Testing complete!"
echo ""

# Optional: Show sample data
if [ "$SHOW_SAMPLE" = "true" ]; then
    echo "Sample NSN Data:"
    echo "================"
    response=$(api_call "GET" "/nsn/5820-01-546-5288" "")
    pretty_json "$response"
fi 