#!/bin/bash

# HandReceipt Azure OCR Integration Test Script
# Tests the POST /api/da2062/upload endpoint with Azure Computer Vision OCR

set -e

echo "🔍 HandReceipt Azure OCR Integration Test"
echo "========================================"

# Azure OCR Configuration
export AZURE_OCR_ENDPOINT="https://handreceipt-prod-vision.cognitiveservices.azure.com/"
export AZURE_OCR_KEY="8xV5rQq1XSkAoQmvDMJoGkM5OxsPz6Z4q88wE8j3VN7xhPzPaMUQJQQJ99BFACHYHv6XJ3w3AAAFACOG9Li2"

# Other required environment variables for local testing
export HANDRECEIPT_DATABASE_HOST="localhost"
export HANDRECEIPT_DATABASE_PORT="5432"
export HANDRECEIPT_DATABASE_USER="handreceipt_user"
export HANDRECEIPT_DATABASE_PASSWORD="handreceipt_password"
export HANDRECEIPT_DATABASE_NAME="handreceipt_db"
export HANDRECEIPT_JWT_SECRET_KEY="test-jwt-secret-key-for-local-testing"
export HANDRECEIPT_SERVER_PORT="8080"
export HANDRECEIPT_SERVER_ENVIRONMENT="development"

# Storage settings (can be MinIO for local testing)
export HANDRECEIPT_STORAGE_TYPE="minio"
export HANDRECEIPT_MINIO_ENABLED="true"
export MINIO_ACCESS_KEY="minioadmin"
export MINIO_SECRET_KEY="minioadmin"

echo "✅ Environment variables set:"
echo "   AZURE_OCR_ENDPOINT: ${AZURE_OCR_ENDPOINT}"
echo "   AZURE_OCR_KEY: ${AZURE_OCR_KEY:0:20}...***"

# Function to test Azure OCR directly
test_azure_ocr_direct() {
    echo ""
    echo "🧪 Testing Azure OCR directly..."
    
    # Create a simple test image URL (we'll use a sample image)
    TEST_IMAGE_URL="https://learn.microsoft.com/en-us/azure/ai-services/computer-vision/media/quickstarts/presentation.png"
    
    echo "📤 Starting OCR operation..."
    OPERATION_URL=$(curl -s -X POST \
        "${AZURE_OCR_ENDPOINT}vision/v3.2/read/analyze" \
        -H "Ocp-Apim-Subscription-Key: ${AZURE_OCR_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"url\": \"${TEST_IMAGE_URL}\"}" \
        -D /tmp/headers.txt \
        | echo "")
    
    # Extract operation URL from headers
    OPERATION_URL=$(grep -i "operation-location" /tmp/headers.txt | cut -d' ' -f2 | tr -d '\r')
    
    if [ -z "$OPERATION_URL" ]; then
        echo "❌ Failed to start OCR operation"
        return 1
    fi
    
    echo "✅ OCR operation started: ${OPERATION_URL}"
    
    # Poll for results
    echo "⏳ Polling for results..."
    for i in {1..30}; do
        RESULT=$(curl -s -X GET \
            "${OPERATION_URL}" \
            -H "Ocp-Apim-Subscription-Key: ${AZURE_OCR_KEY}")
        
        STATUS=$(echo "$RESULT" | jq -r '.status // "unknown"')
        echo "   Attempt $i: Status = $STATUS"
        
        if [ "$STATUS" = "succeeded" ]; then
            echo "✅ Azure OCR test successful!"
            echo "📄 Sample extracted text:"
            echo "$RESULT" | jq -r '.analyzeResult.readResults[0].lines[0].text // "No text found"'
            return 0
        elif [ "$STATUS" = "failed" ]; then
            echo "❌ Azure OCR operation failed"
            echo "$RESULT"
            return 1
        fi
        
        sleep 2
    done
    
    echo "⏰ OCR operation timed out"
    return 1
}

# Function to start the backend server
start_backend() {
    echo ""
    echo "🚀 Starting HandReceipt backend server..."
    
    # Check if server is already running
    if pgrep -f "handreceipt.*server" > /dev/null; then
        echo "✅ Backend server is already running"
        return 0
    fi
    
    # Build and start server
    echo "🔨 Building backend..."
    go build -o handreceipt ./cmd/server
    
    echo "🏃 Starting server in background..."
    nohup ./handreceipt > server.log 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to start
    echo "⏳ Waiting for server to start..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            echo "✅ Backend server started successfully (PID: $SERVER_PID)"
            return 0
        fi
        sleep 1
    done
    
    echo "❌ Backend server failed to start"
    return 1
}

# Function to create a test user and get auth token
setup_test_user() {
    echo ""
    echo "👤 Setting up test user..."
    
    # Create test user
    SIGNUP_RESPONSE=$(curl -s -X POST \
        http://localhost:8080/api/auth/signup \
        -H "Content-Type: application/json" \
        -d '{
            "username": "testuser",
            "email": "test@example.com",
            "password": "testpass123",
            "rank": "SGT",
            "unit": "Test Unit"
        }')
    
    echo "📝 Signup response: $SIGNUP_RESPONSE"
    
    # Login to get token
    LOGIN_RESPONSE=$(curl -s -X POST \
        http://localhost:8080/api/auth/login \
        -H "Content-Type: application/json" \
        -d '{
            "username": "testuser",
            "password": "testpass123"
        }')
    
    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')
    
    if [ -z "$TOKEN" ]; then
        echo "❌ Failed to get auth token"
        echo "Login response: $LOGIN_RESPONSE"
        return 1
    fi
    
    echo "✅ Got auth token: ${TOKEN:0:20}...***"
    export AUTH_TOKEN="$TOKEN"
    return 0
}

# Function to create a sample DA-2062 test image
create_test_image() {
    echo ""
    echo "📄 Creating sample DA-2062 test image..."
    
    # Create a simple text file that simulates a DA-2062 form
    cat > test_da2062.txt << 'EOF'
HAND RECEIPT
DA FORM 2062-R

UNIT: 1ST BATTALION
DODAAC: W12345

LINE  NSN              DESCRIPTION                    QTY  U/I  SERIAL
1     1005-01-123-4567 RIFLE, 5.56MM, M4A1          1    EA   12345678
                        S/N: 12345678

2     1240-01-234-5678 OPTICAL SIGHT                 1    EA   87654321
                        S/N: 87654321

3     1290-01-345-6789 MAGAZINE, 30 ROUND            6    EA   MULTIPLE
EOF
    
    # Convert to image using ImageMagick (if available) or create a simple image
    if command -v convert >/dev/null 2>&1; then
        convert -pointsize 12 -font mono label:@test_da2062.txt test_da2062.png
        echo "✅ Created test image: test_da2062.png"
    else
        echo "⚠️  ImageMagick not available, using text file directly"
        cp test_da2062.txt test_da2062.png
    fi
}

# Function to test the DA-2062 upload endpoint
test_da2062_upload() {
    echo ""
    echo "📤 Testing DA-2062 upload endpoint..."
    
    if [ ! -f "test_da2062.png" ]; then
        echo "❌ Test image not found"
        return 1
    fi
    
    # Upload the test form
    echo "🔄 Uploading DA-2062 form..."
    UPLOAD_RESPONSE=$(curl -s -X POST \
        http://localhost:8080/api/da2062/upload \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -F "file=@test_da2062.png;type=image/png")
    
    echo "📨 Upload response:"
    echo "$UPLOAD_RESPONSE" | jq '.' || echo "$UPLOAD_RESPONSE"
    
    # Check if successful
    SUCCESS=$(echo "$UPLOAD_RESPONSE" | jq -r '.success // false')
    if [ "$SUCCESS" = "true" ]; then
        echo "✅ DA-2062 upload successful!"
        
        # Display parsed items
        echo ""
        echo "📋 Parsed items:"
        echo "$UPLOAD_RESPONSE" | jq -r '.items[] | "- \(.name // .description): NSN=\(.nsn // "N/A"), Serial=\(.serial_number // "N/A"), Qty=\(.quantity // "N/A")"'
        
        # Check verification status
        VERIFICATION_NEEDED=$(echo "$UPLOAD_RESPONSE" | jq -r '.next_steps.verification_needed // false')
        echo ""
        echo "🔍 Verification needed: $VERIFICATION_NEEDED"
        
        return 0
    else
        echo "❌ DA-2062 upload failed"
        return 1
    fi
}

# Function to check server logs
check_logs() {
    echo ""
    echo "📊 Checking server logs for OCR activity..."
    
    if [ -f "server.log" ]; then
        echo "🔍 Recent log entries:"
        tail -20 server.log | grep -E "(OCR|Azure|da2062)" || echo "No OCR-related logs found"
    else
        echo "⚠️  No server log file found"
    fi
}

# Function to cleanup
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    
    # Stop server if we started it
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        echo "🛑 Stopped backend server"
    fi
    
    # Clean up test files
    rm -f test_da2062.txt test_da2062.png /tmp/headers.txt handreceipt server.log
    echo "🗑️  Cleaned up test files"
}

# Main test execution
main() {
    trap cleanup EXIT
    
    echo "🎯 Running Azure OCR Integration Tests"
    echo ""
    
    # Test 1: Direct Azure OCR test
    if test_azure_ocr_direct; then
        echo "✅ Test 1 PASSED: Direct Azure OCR"
    else
        echo "❌ Test 1 FAILED: Direct Azure OCR"
        echo "⚠️  Check your Azure credentials and endpoint"
        exit 1
    fi
    
    # Test 2: Start backend server
    if start_backend; then
        echo "✅ Test 2 PASSED: Backend server startup"
    else
        echo "❌ Test 2 FAILED: Backend server startup"
        exit 1
    fi
    
    # Test 3: Setup authentication
    if setup_test_user; then
        echo "✅ Test 3 PASSED: User authentication"
    else
        echo "❌ Test 3 FAILED: User authentication"
        echo "⚠️  Continuing without authentication (may fail)"
    fi
    
    # Test 4: Create test image
    create_test_image
    
    # Test 5: Test DA-2062 upload endpoint
    if test_da2062_upload; then
        echo "✅ Test 5 PASSED: DA-2062 upload and OCR"
    else
        echo "❌ Test 5 FAILED: DA-2062 upload and OCR"
    fi
    
    # Check logs
    check_logs
    
    echo ""
    echo "🎉 Test execution completed!"
    echo "📊 Check the results above to verify OCR integration"
}

# Show help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "HandReceipt Azure OCR Integration Test"
    echo ""
    echo "This script tests the Azure OCR integration end-to-end:"
    echo "1. Tests Azure Computer Vision directly"
    echo "2. Starts the HandReceipt backend server"
    echo "3. Creates a test user and authenticates"
    echo "4. Creates a sample DA-2062 form"
    echo "5. Tests the /api/da2062/upload endpoint"
    echo "6. Checks logs for OCR activity"
    echo ""
    echo "Usage: $0 [--help]"
    echo ""
    echo "Prerequisites:"
    echo "- Go development environment"
    echo "- jq (JSON processor)"
    echo "- curl"
    echo "- PostgreSQL running (optional for basic OCR test)"
    exit 0
fi

# Run main function
main 