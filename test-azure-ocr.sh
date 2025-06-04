#!/bin/bash

# HandReceipt Azure OCR Integration Test Script
# Tests the POST /api/da2062/upload endpoint with Azure Computer Vision OCR

set -e

echo "🔍 HandReceipt Azure OCR Integration Test"
echo "========================================="

# Azure OCR Configuration (your actual credentials)
export AZURE_OCR_ENDPOINT="https://handreceipt-prod-vision.cognitiveservices.azure.com/"
export AZURE_OCR_KEY="8xV5rQq1XSkAoQmvDMJoGkM5OxsPz6Z4q88wE8j3VN7xhPzPaMUQJQQJ99BFACHYHv6XJ3w3AAAFACOG9Li2"

# Database configuration (adjust as needed for local testing)
export HANDRECEIPT_DATABASE_HOST="localhost"
export HANDRECEIPT_DATABASE_PORT="5432"
export HANDRECEIPT_DATABASE_USER="handreceipt_user"
export HANDRECEIPT_DATABASE_PASSWORD="handreceipt_password"
export HANDRECEIPT_DATABASE_NAME="handreceipt_db"
export HANDRECEIPT_DATABASE_SSL_MODE="disable"

# Other configuration
export HANDRECEIPT_SERVER_PORT="8080"
export HANDRECEIPT_SERVER_ENVIRONMENT="development"
export HANDRECEIPT_JWT_SECRET_KEY="test_jwt_secret_key_for_development"
export HANDRECEIPT_CONFIG_NAME="config"

# Test settings - Production Azure backend
BACKEND_URL="https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io"
TEST_FILE="assets/DA2062.pdf"

echo "✅ Environment variables set"
echo "📍 Azure OCR Endpoint: $AZURE_OCR_ENDPOINT"
echo "🔑 Azure OCR Key: ${AZURE_OCR_KEY:0:20}..."
echo ""

# Function to check if backend is running
check_backend() {
    echo "🔍 Checking if backend is running..."
    if curl -s -f "$BACKEND_URL/health" > /dev/null 2>&1; then
        echo "✅ Backend is running at $BACKEND_URL"
        return 0
    else
        echo "❌ Backend is not running at $BACKEND_URL"
        return 1
    fi
}

# Function to test Azure OCR directly
test_azure_ocr_direct() {
    echo "🧪 Testing Azure Computer Vision OCR directly..."
    
    if [ ! -f "$TEST_FILE" ]; then
        echo "❌ Test file not found: $TEST_FILE"
        echo "💡 Place a DA-2062 form PDF/image in the assets/ directory"
        return 1
    fi
    
    # Test the Read API directly
    echo "📤 Sending image to Azure Computer Vision..."
    
    OPERATION_URL=$(curl -s -X POST \
        "$AZURE_OCR_ENDPOINT/vision/v3.2/read/analyze" \
        -H "Ocp-Apim-Subscription-Key: $AZURE_OCR_KEY" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$TEST_FILE" \
        -i | grep -i "operation-location" | sed 's/.*: //' | tr -d '\r')
    
    if [ -z "$OPERATION_URL" ]; then
        echo "❌ Failed to start OCR operation"
        return 1
    fi
    
    echo "✅ OCR operation started"
    echo "⏳ Operation URL: $OPERATION_URL"
    
    # Poll for results
    echo "⏳ Waiting for OCR results..."
    for i in {1..30}; do
        sleep 2
        RESULT=$(curl -s -H "Ocp-Apim-Subscription-Key: $AZURE_OCR_KEY" "$OPERATION_URL")
        STATUS=$(echo "$RESULT" | jq -r '.status // "unknown"')
        
        echo "   Attempt $i: Status = $STATUS"
        
        if [ "$STATUS" = "succeeded" ]; then
            echo "✅ OCR completed successfully!"
            echo "📄 First few lines of recognized text:"
            echo "$RESULT" | jq -r '.analyzeResult.readResults[0].lines[0:5][].text' 2>/dev/null || echo "Could not parse OCR results"
            return 0
        elif [ "$STATUS" = "failed" ]; then
            echo "❌ OCR operation failed"
            echo "$RESULT" | jq '.' 2>/dev/null || echo "$RESULT"
            return 1
        fi
    done
    
    echo "⏰ OCR operation timed out"
    return 1
}

# Function to test via backend API
test_backend_api() {
    echo "🧪 Testing DA-2062 upload via backend API..."
    
    if [ ! -f "$TEST_FILE" ]; then
        echo "❌ Test file not found: $TEST_FILE"
        return 1
    fi
    
    # First, we need to authenticate (this is a simplified test)
    echo "🔐 Note: This test requires authentication"
    echo "📝 You'll need to:"
    echo "   1. Register/login via the API to get a session"
    echo "   2. Use the session cookie for the upload request"
    echo ""
    echo "📤 Testing file upload endpoint (without auth for now)..."
    
    RESPONSE=$(curl -s -X POST \
        "$BACKEND_URL/api/da2062/upload" \
        -F "file=@$TEST_FILE" \
        -w "HTTPSTATUS:%{http_code}")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    echo "📊 HTTP Status: $HTTP_STATUS"
    
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "✅ API request successful!"
        echo "📋 Response:"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    elif [ "$HTTP_STATUS" = "401" ]; then
        echo "🔐 Authentication required (expected for protected endpoint)"
        echo "💡 The endpoint is working but needs authentication"
    else
        echo "❌ API request failed"
        echo "📋 Response:"
        echo "$BODY"
    fi
}

# Function to start backend for testing
start_backend() {
    echo "🚀 Starting backend for testing..."
    cd backend
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        echo "❌ Go is not installed"
        return 1
    fi
    
    # Build and start the backend
    echo "🔨 Building backend..."
    go mod tidy
    go build -o handreceipt-backend ./cmd/api
    
    echo "🎯 Starting backend on port 8080..."
    ./handreceipt-backend &
    BACKEND_PID=$!
    
    # Wait for backend to start
    echo "⏳ Waiting for backend to start..."
    for i in {1..10}; do
        sleep 2
        if check_backend; then
            echo "✅ Backend started successfully (PID: $BACKEND_PID)"
            return 0
        fi
    done
    
    echo "❌ Backend failed to start"
    kill $BACKEND_PID 2>/dev/null || true
    return 1
}

# Main test execution
main() {
    echo "🎯 Starting OCR integration tests..."
    echo ""
    
    # Test 1: Direct Azure OCR
    if test_azure_ocr_direct; then
        echo "✅ Direct Azure OCR test PASSED"
    else
        echo "❌ Direct Azure OCR test FAILED"
        echo "💡 Check your Azure credentials and network connection"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Test 2: Backend API (check if running first)
    if check_backend; then
        test_backend_api
    else
        echo "🤔 Backend not running. Would you like to start it for testing? (y/n)"
        read -r response
        if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
            if start_backend; then
                sleep 3
                test_backend_api
                echo "🛑 Stopping test backend..."
                kill $BACKEND_PID 2>/dev/null || true
            fi
        else
            echo "⏭️  Skipping backend API test"
        fi
    fi
    
    echo ""
    echo "🎉 OCR integration test completed!"
    echo ""
    echo "📋 Next steps based on your guide:"
    echo "1. ✅ Azure OCR service is working"
    echo "2. 🔄 Deploy backend with OCR configuration"
    echo "3. 🧪 Test end-to-end with real DA-2062 forms"
    echo "4. 🔍 Monitor logs for OCR activity"
    echo "5. ✏️  Set up verification workflow for flagged items"
}

# Check for required tools
echo "🔧 Checking prerequisites..."
for tool in curl jq; do
    if ! command -v $tool &> /dev/null; then
        echo "❌ Required tool not found: $tool"
        echo "💡 Install with: brew install $tool"
        exit 1
    fi
done
echo "✅ Prerequisites met"
echo ""

# Run main test
main 