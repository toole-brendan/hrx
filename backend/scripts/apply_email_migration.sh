#!/bin/bash

# Apply email migration to fix users table
echo "Applying email migration to fix users table..."

# Database connection parameters
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="handreceipt"
DB_USER="handreceipt"

# Use provided password
DB_PASSWORD="Dunlainge1"

# Test connection
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Cannot connect to database"
    exit 1
fi

# Apply the migration
echo "Running migration..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f fix_users_email_migration.sql

if [ $? -eq 0 ]; then
    echo "✅ Migration completed successfully!"
    echo ""
    echo "Current users table structure:"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\d users"
else
    echo "❌ Migration failed!"
    exit 1
fi