#!/bin/bash

# Fix DA 2062 PDF Generation Error for Azure Deployment
# This script connects to Azure PostgreSQL and ensures the documents table exists

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Azure DA 2062 Documents Table Fix Script ===${NC}"
echo -e "${BLUE}This script will fix the 'Failed to create document record' error in Azure${NC}"
echo ""

# Azure PostgreSQL connection details
# These should be set as environment variables or passed as arguments
DB_HOST="${AZURE_DB_HOST:-}"
DB_NAME="${AZURE_DB_NAME:-handreceipt}"
DB_USER="${AZURE_DB_USER:-}"
DB_PASSWORD="${AZURE_DB_PASSWORD:-}"

# Function to check environment variables
check_env_vars() {
    if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
        echo -e "${RED}Error: Missing required environment variables${NC}"
        echo "Please set the following environment variables:"
        echo "  AZURE_DB_HOST - Your Azure PostgreSQL server hostname"
        echo "  AZURE_DB_USER - Database username"
        echo "  AZURE_DB_PASSWORD - Database password"
        echo "  AZURE_DB_NAME - Database name (optional, defaults to 'handreceipt')"
        echo ""
        echo "Example:"
        echo "  export AZURE_DB_HOST=your-server.postgres.database.azure.com"
        echo "  export AZURE_DB_USER=your-username@your-server"
        echo "  export AZURE_DB_PASSWORD=your-password"
        exit 1
    fi
}

# Function to run SQL command
run_sql() {
    local sql="$1"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "$sql"
}

# Function to run SQL command and capture output
run_sql_output() {
    local sql="$1"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -tAc "$sql"
}

# Function to check if documents table exists
check_documents_table() {
    echo -e "${YELLOW}Checking if documents table exists...${NC}"
    
    TABLE_EXISTS=$(run_sql_output "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'documents');")
    
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
    
    # Create the table using the migration SQL
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" << 'EOF'
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
    
    # Show table structure
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "\d documents"
    
    # Check for JSONB attachments column
    JSONB_CHECK=$(run_sql_output "SELECT data_type FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'attachments';")
    
    if [ "$JSONB_CHECK" = "jsonb" ]; then
        echo -e "${GREEN}Attachments column is correctly set as JSONB${NC}"
    else
        echo -e "${YELLOW}Warning: Attachments column type is: $JSONB_CHECK${NC}"
    fi
    
    # Count existing documents
    DOC_COUNT=$(run_sql_output "SELECT COUNT(*) FROM documents;")
    echo -e "${BLUE}Current document count: $DOC_COUNT${NC}"
}

# Function to apply all missing migrations
apply_all_migrations() {
    echo -e "${YELLOW}Checking for other missing migrations...${NC}"
    
    # Check if we have a migrations tracking table
    MIGRATIONS_TABLE=$(run_sql_output "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'schema_migrations');")
    
    if [ "$MIGRATIONS_TABLE" != "t" ]; then
        echo -e "${YELLOW}No migrations tracking table found. Creating one...${NC}"
        run_sql "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255) PRIMARY KEY, applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
    fi
    
    # Record this migration
    run_sql "INSERT INTO schema_migrations (version) VALUES ('013_add_documents_table') ON CONFLICT (version) DO NOTHING;"
    
    echo -e "${GREEN}Migration recorded${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Azure fix process...${NC}"
    echo ""
    
    check_env_vars
    
    echo -e "${YELLOW}Connecting to Azure PostgreSQL...${NC}"
    echo "Host: $DB_HOST"
    echo "Database: $DB_NAME"
    echo "User: $DB_USER"
    echo ""
    
    # Test connection
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        echo -e "${RED}Failed to connect to Azure PostgreSQL${NC}"
        echo "Please check your connection details and try again"
        exit 1
    fi
    
    echo -e "${GREEN}Successfully connected to Azure PostgreSQL${NC}"
    
    if check_documents_table; then
        echo -e "${GREEN}Documents table already exists. Verifying schema...${NC}"
        verify_table_schema
    else
        create_documents_table
        verify_table_schema
        apply_all_migrations
    fi
    
    echo ""
    echo -e "${GREEN}=== Fix Complete ===${NC}"
    echo -e "${GREEN}The documents table has been created/verified in Azure PostgreSQL.${NC}"
    echo -e "${GREEN}You should now be able to generate DA 2062 PDFs without errors.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Restart your Azure Container App to ensure it picks up the changes"
    echo "2. Test DA 2062 PDF generation in the app"
    echo "3. Monitor the container logs for any issues"
    echo ""
    echo -e "${YELLOW}To restart the Azure Container App:${NC}"
    echo "  az containerapp revision restart --name handreceipt-backend --resource-group <your-rg>"
    echo "  OR use the Azure Portal to restart the container"
}

# Run main function
main 