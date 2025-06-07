#!/bin/bash

# Fix DA 2062 PDF Generation Error - Documents Table
# This script ensures the documents table exists with the correct schema
# to fix the "Failed to create document record" error

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DA 2062 Documents Table Fix Script ===${NC}"
echo -e "${BLUE}This script will fix the 'Failed to create document record' error${NC}"
echo ""

# Function to check if we're in the right directory
check_directory() {
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}Error: docker-compose.yml not found!${NC}"
        echo "Please run this script from the backend directory"
        exit 1
    fi
}

# Function to check if PostgreSQL container is running
check_postgres() {
    echo -e "${YELLOW}Checking PostgreSQL container...${NC}"
    if ! docker-compose ps postgres | grep -q "Up"; then
        echo -e "${RED}PostgreSQL container is not running!${NC}"
        echo "Starting PostgreSQL..."
        docker-compose up -d postgres
        sleep 5
    fi
    echo -e "${GREEN}PostgreSQL container is running${NC}"
}

# Function to check if documents table exists
check_documents_table() {
    echo -e "${YELLOW}Checking if documents table exists...${NC}"
    
    TABLE_EXISTS=$(docker-compose exec -T postgres psql -U handreceipt -d handreceipt -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'documents');")
    
    if [ "$TABLE_EXISTS" = "t" ]; then
        echo -e "${GREEN}Documents table already exists${NC}"
        return 0
    else
        echo -e "${RED}Documents table does not exist${NC}"
        return 1
    fi
}

# Function to create documents table
create_documents_table() {
    echo -e "${YELLOW}Creating documents table...${NC}"
    
    # Use the migration SQL
    docker-compose exec -T postgres psql -U handreceipt -d handreceipt << 'EOF'
-- Create documents table for DA2062 and maintenance forms
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    type VARCHAR(50) NOT NULL,
    subtype VARCHAR(50),
    title VARCHAR(255) NOT NULL,
    sender_user_id INTEGER NOT NULL,
    recipient_user_id INTEGER NOT NULL,
    property_id INTEGER,
    form_data TEXT,
    description TEXT,
    attachments JSONB DEFAULT '[]'::jsonb,
    status VARCHAR(50) NOT NULL DEFAULT 'unread',
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_documents_sender FOREIGN KEY (sender_user_id) REFERENCES users(id),
    CONSTRAINT fk_documents_recipient FOREIGN KEY (recipient_user_id) REFERENCES users(id),
    CONSTRAINT fk_documents_property FOREIGN KEY (property_id) REFERENCES properties(id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_documents_sender_user_id ON documents(sender_user_id);
CREATE INDEX IF NOT EXISTS idx_documents_recipient_user_id ON documents(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_documents_property_id ON documents(property_id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(type);
CREATE INDEX IF NOT EXISTS idx_documents_sent_at ON documents(sent_at);
CREATE INDEX IF NOT EXISTS idx_documents_deleted_at ON documents(deleted_at);

-- Add comment to table
COMMENT ON TABLE documents IS 'Stores various document types including DA2062 forms and maintenance forms';
EOF
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Documents table created successfully${NC}"
    else
        echo -e "${RED}Failed to create documents table${NC}"
        exit 1
    fi
}

# Function to verify the table schema
verify_table_schema() {
    echo -e "${YELLOW}Verifying documents table schema...${NC}"
    
    docker-compose exec -T postgres psql -U handreceipt -d handreceipt -c "\d documents"
    
    # Check for JSONB attachments column
    JSONB_CHECK=$(docker-compose exec -T postgres psql -U handreceipt -d handreceipt -tAc "SELECT data_type FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'attachments';")
    
    if [ "$JSONB_CHECK" = "jsonb" ]; then
        echo -e "${GREEN}Attachments column is correctly set as JSONB${NC}"
    else
        echo -e "${YELLOW}Warning: Attachments column type is: $JSONB_CHECK${NC}"
    fi
}

# Function to test the fix
test_fix() {
    echo -e "${YELLOW}Testing the fix...${NC}"
    
    # Test by checking the table check endpoint
    if command -v curl &> /dev/null; then
        echo "Testing DA2062 table check endpoint..."
        RESPONSE=$(curl -s http://localhost:8080/api/da2062/table-check || echo "Failed to connect")
        echo "Response: $RESPONSE"
        
        if echo "$RESPONSE" | grep -q '"documents_table_exists":true'; then
            echo -e "${GREEN}Table check endpoint confirms table exists!${NC}"
        fi
    fi
}

# Function to restart backend
restart_backend() {
    echo -e "${YELLOW}Restarting backend to ensure it picks up the changes...${NC}"
    docker-compose restart app
    echo -e "${GREEN}Backend restarted${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting fix process...${NC}"
    echo ""
    
    # Navigate to backend directory if needed
    if [ -d "backend" ] && [ ! -f "docker-compose.yml" ]; then
        cd backend
    fi
    
    check_directory
    check_postgres
    
    if check_documents_table; then
        echo -e "${GREEN}Documents table already exists. Verifying schema...${NC}"
        verify_table_schema
    else
        create_documents_table
        verify_table_schema
    fi
    
    # Ask if user wants to restart backend
    read -p "Do you want to restart the backend container? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        restart_backend
    fi
    
    echo ""
    echo -e "${GREEN}=== Fix Complete ===${NC}"
    echo -e "${GREEN}The documents table has been created/verified.${NC}"
    echo -e "${GREEN}You should now be able to generate DA 2062 PDFs without errors.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Test DA 2062 PDF generation in the app"
    echo "2. Check backend logs: docker-compose logs -f app"
    echo "3. If issues persist, check the full error details in the logs"
    
    # Optional: test the fix
    echo ""
    read -p "Do you want to test the fix now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_fix
    fi
}

# Run main function
main 