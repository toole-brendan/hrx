#!/bin/bash

# Complete Property Migration Script
# This script runs the entire inventory-to-property migration process

set -e  # Exit on error

echo "=== Starting Complete Property Migration Process ==="
echo ""

# Check if we're in the right directory
if [ ! -d "backend" ] || [ ! -d "web" ] || [ ! -d "ios" ]; then
    echo "Error: This script must be run from the hrx repository root"
    exit 1
fi

# Check if the migration scripts exist
if [ ! -f "property-rename-files.sh" ] || [ ! -f "property-search-replace.sh" ]; then
    echo "Error: Migration scripts not found. Please ensure both scripts exist:"
    echo "  - property-rename-files.sh"
    echo "  - property-search-replace.sh"
    exit 1
fi

# First, create a new branch
echo "Creating migration branch..."
git checkout -b inventory-to-property-migration

# Make the scripts executable
echo ""
echo "Making scripts executable..."
chmod +x property-rename-files.sh
chmod +x property-search-replace.sh

# Run the file rename script
echo ""
echo "Running file rename script..."
./property-rename-files.sh

# Check if file renames were successful
if [ $? -ne 0 ]; then
    echo "Error: File rename script failed"
    exit 1
fi

# Run the search and replace script
echo ""
echo "Running search and replace script..."
./property-search-replace.sh

# Check if search/replace was successful
if [ $? -ne 0 ]; then
    echo "Error: Search and replace script failed"
    exit 1
fi

echo ""
echo "=== Migration Process Complete ==="
echo ""
echo "Summary of changes:"
echo "- Files have been renamed from inventory/item to property"
echo "- Code references have been updated"
echo "- SQL migration has been created"
echo ""
echo "Next steps:"
echo "1. Review all changes: git diff"
echo "2. Check for any missed references: grep -r 'inventory' web/src backend/internal ios/HandReceipt"
echo "3. Update JSON response keys in backend handlers"
echo "4. Run all tests to ensure nothing is broken"
echo "5. Commit when ready: git add . && git commit -m 'Migrate inventory/item terminology to property'"
echo ""
echo "To see the status: git status"
echo "To see what changed: git diff --name-status" 