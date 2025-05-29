#!/bin/bash
# run-transfer-tests.sh

echo "🚀 Running HandReceipt Transfer Flow Tests"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to run backend tests
run_backend_tests() {
    echo -e "\n${YELLOW}Running Backend Tests...${NC}"
    cd backend
    
    # Run unit tests
    echo "Running unit tests..."
    go test ./internal/api/handlers -v -tags=unit
    
    # Run integration tests
    echo "Running integration tests..."
    go test ./tests -v -tags=integration
    
    # Run specific QR transfer test
    echo "Running QR transfer flow test..."
    go test ./tests -run TestCompleteQRTransferFlow -v
    
    cd ..
}

# Function to run web tests
run_web_tests() {
    echo -e "\n${YELLOW}Running Web Tests...${NC}"
    cd web
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing dependencies..."
        npm install
    fi
    
    # Run unit tests
    echo "Running React component tests..."
    npm test -- --run
    
    # Run E2E tests
    echo "Running Cypress E2E tests..."
    # Start the dev server in background
    npm run dev &
    DEV_SERVER_PID=$!
    
    # Wait for server to start
    sleep 5
    
    # Run Cypress tests
    npx cypress run --spec "cypress/e2e/qr-transfer-flow.cy.ts"
    
    # Kill the dev server
    kill $DEV_SERVER_PID
    
    cd ..
}

# Function to check backend API endpoints
check_api_endpoints() {
    echo -e "\n${YELLOW}Checking API Endpoints...${NC}"
    
    # Start backend if not running
    cd backend
    go run cmd/server/main.go &
    BACKEND_PID=$!
    sleep 3
    
    # Check health endpoint
    echo "Checking health endpoint..."
    curl -s http://localhost:8000/health | jq .
    
    # Check if QR endpoints are registered
    echo -e "\nChecking QR code endpoints..."
    endpoints=(
        "POST /api/inventory/qrcode/1"
        "POST /api/transfers/qr-initiate"
        "GET /api/qrcodes"
        "POST /api/qrcodes/1/report-damaged"
        "GET /api/inventory/1/qrcodes"
    )
    
    for endpoint in "${endpoints[@]}"; do
        method=$(echo $endpoint | cut -d' ' -f1)
        path=$(echo $endpoint | cut -d' ' -f2)
        
        echo -n "Testing $endpoint... "
        
        response=$(curl -s -X $method http://localhost:8000$path \
            -H "Content-Type: application/json" \
            -H "X-User-ID: 1" \
            -w "\n%{http_code}")
        status_code=$(echo "$response" | tail -n 1)
        
        if [[ $status_code -eq 200 ]] || [[ $status_code -eq 201 ]]; then
            echo -e "${GREEN}✓${NC} Success ($status_code)"
        elif [[ $status_code -eq 401 ]] || [[ $status_code -eq 403 ]]; then
            echo -e "${YELLOW}⚠${NC} Auth required ($status_code)"
        elif [[ $status_code -eq 404 ]]; then
            echo -e "${RED}✗${NC} Not found ($status_code)"
        elif [[ $status_code -eq 400 ]]; then
            echo -e "${BLUE}i${NC} Bad request ($status_code) - endpoint exists"
        else
            echo -e "${RED}?${NC} Unexpected ($status_code)"
        fi
    done
    
    # Kill backend
    kill $BACKEND_PID
    cd ..
}

# Function to validate database schema
check_database_schema() {
    echo -e "\n${YELLOW}Checking Database Schema...${NC}"
    
    # Check if docker-compose is running
    if ! docker-compose ps | grep -q "postgres.*Up"; then
        echo "Starting database..."
        docker-compose up -d postgres
        sleep 5
    fi
    
    # Check for required tables
    tables=("qr_codes" "properties" "transfers" "users")
    
    for table in "${tables[@]}"; do
        echo -n "Checking $table table... "
        if docker-compose exec -T postgres psql -U handreceipt -d handreceipt_db -c "\dt $table" 2>/dev/null | grep -q "$table"; then
            echo -e "${GREEN}✓${NC} exists"
        else
            echo -e "${RED}✗${NC} missing"
        fi
    done
    
    # Check QR codes table structure
    echo -e "\n${BLUE}QR codes table structure:${NC}"
    docker-compose exec -T postgres psql -U handreceipt -d handreceipt_db -c "\d qr_codes" 2>/dev/null || \
        echo -e "${RED}Could not retrieve table structure${NC}"
}

# Function to run smoke tests
run_smoke_tests() {
    echo -e "\n${YELLOW}Running Smoke Tests...${NC}"
    
    # Check if backend compiles
    echo -n "Backend compilation... "
    cd backend
    if go build -o /tmp/handreceipt cmd/server/main.go; then
        echo -e "${GREEN}✓${NC}"
        rm -f /tmp/handreceipt
    else
        echo -e "${RED}✗${NC}"
    fi
    cd ..
    
    # Check if web builds
    echo -n "Web build... "
    cd web
    if npm run build > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    cd ..
    
    # Check if TypeScript compiles
    echo -n "TypeScript compilation... "
    cd web
    if npx tsc --noEmit > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    cd ..
}

# Function to check dependencies
check_dependencies() {
    echo -e "\n${YELLOW}Checking Dependencies...${NC}"
    
    # Check Go
    echo -n "Go... "
    if command -v go &> /dev/null; then
        echo -e "${GREEN}✓${NC} $(go version | cut -d' ' -f3)"
    else
        echo -e "${RED}✗${NC} Not installed"
    fi
    
    # Check Node.js
    echo -n "Node.js... "
    if command -v node &> /dev/null; then
        echo -e "${GREEN}✓${NC} $(node --version)"
    else
        echo -e "${RED}✗${NC} Not installed"
    fi
    
    # Check Docker
    echo -n "Docker... "
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓${NC} $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
    else
        echo -e "${RED}✗${NC} Not installed"
    fi
    
    # Check jq
    echo -n "jq... "
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC} Not installed (optional)"
    fi
    
    # Check curl
    echo -n "curl... "
    if command -v curl &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC} Not installed"
    fi
}

# Function to show test coverage
show_test_coverage() {
    echo -e "\n${YELLOW}Test Coverage Report...${NC}"
    
    # Backend coverage
    echo "Backend test coverage:"
    cd backend
    go test -cover ./internal/api/handlers ./tests 2>/dev/null | grep "coverage:" || echo "No coverage data available"
    cd ..
    
    # Web coverage (if available)
    echo -e "\nWeb test coverage:"
    cd web
    if [ -f "coverage/lcov-report/index.html" ]; then
        echo "Coverage report available in web/coverage/lcov-report/index.html"
    else
        echo "No coverage report found"
    fi
    cd ..
}

# Function to generate test report
generate_test_report() {
    echo -e "\n${YELLOW}Generating Test Report...${NC}"
    
    REPORT_FILE="test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "HandReceipt Transfer Flow Test Report"
        echo "====================================="
        echo "Generated: $(date)"
        echo ""
        
        echo "Environment:"
        echo "- Go: $(go version 2>/dev/null || echo 'Not available')"
        echo "- Node: $(node --version 2>/dev/null || echo 'Not available')"
        echo "- Docker: $(docker --version 2>/dev/null || echo 'Not available')"
        echo ""
        
        echo "Test Results:"
        echo "- Backend tests: Run with './run-transfer-tests.sh 1'"
        echo "- Web tests: Run with './run-transfer-tests.sh 2'"
        echo "- API endpoints: Run with './run-transfer-tests.sh 3'"
        echo "- Database schema: Run with './run-transfer-tests.sh 4'"
        echo ""
        
        echo "QR Transfer Flow Features:"
        echo "✓ QR code generation with cryptographic verification"
        echo "✓ QR-based transfer initiation"
        echo "✓ Transfer approval/rejection workflow"
        echo "✓ Security validations (hash integrity, self-transfer prevention)"
        echo "✓ QR code management (damage reporting, replacement)"
        echo "✓ Immutable ledger logging"
        
    } > "$REPORT_FILE"
    
    echo "Test report generated: $REPORT_FILE"
}

# Function to show help
show_help() {
    echo "HandReceipt Transfer Flow Test Runner"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  1, backend      Run backend tests only"
    echo "  2, web          Run web tests only"
    echo "  3, api          Check API endpoints"
    echo "  4, db           Check database schema"
    echo "  5, all          Run all tests"
    echo "  6, smoke        Run smoke tests"
    echo "  7, deps         Check dependencies"
    echo "  8, coverage     Show test coverage"
    echo "  9, report       Generate test report"
    echo "  help, -h        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 1                    # Run backend tests"
    echo "  $0 all                  # Run all tests"
    echo "  $0 smoke                # Quick smoke tests"
}

# Main execution
main() {
    # Check if argument provided
    if [ $# -eq 1 ]; then
        choice=$1
    else
        echo "Select tests to run:"
        echo "1) Backend tests only"
        echo "2) Web tests only"
        echo "3) API endpoint check"
        echo "4) Database schema check"
        echo "5) All tests"
        echo "6) Smoke tests"
        echo "7) Check dependencies"
        echo "8) Test coverage"
        echo "9) Generate test report"
        echo "h) Help"
        
        read -p "Enter your choice (1-9, h): " choice
    fi
    
    case $choice in
        1|backend)
            run_backend_tests
            ;;
        2|web)
            run_web_tests
            ;;
        3|api)
            check_api_endpoints
            ;;
        4|db)
            check_database_schema
            ;;
        5|all)
            check_dependencies
            check_database_schema
            run_smoke_tests
            check_api_endpoints
            run_backend_tests
            run_web_tests
            show_test_coverage
            generate_test_report
            ;;
        6|smoke)
            run_smoke_tests
            ;;
        7|deps)
            check_dependencies
            ;;
        8|coverage)
            show_test_coverage
            ;;
        9|report)
            generate_test_report
            ;;
        help|-h|h)
            show_help
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            show_help
            exit 1
            ;;
    esac
    
    echo -e "\n${GREEN}🎉 Test execution completed!${NC}"
}

# Trap to cleanup background processes
trap 'kill $(jobs -p) 2>/dev/null' EXIT

# Run main function
main "$@" 