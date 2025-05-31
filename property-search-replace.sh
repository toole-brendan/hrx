#!/bin/bash

# Search and Replace Script for inventory/item -> property
# Run this AFTER the file rename script

set -e

echo "=== Property Search and Replace Script ==="
echo "This will update references within files"
echo ""

# Function to perform search and replace in a directory
search_replace() {
    local search="$1"
    local replace="$2"
    local file_pattern="$3"
    local directory="$4"
    
    echo "Replacing '$search' with '$replace' in $directory ($file_pattern files)..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        find "$directory" -type f -name "$file_pattern" -exec sed -i '' "s|$search|$replace|g" {} +
    else
        # Linux
        find "$directory" -type f -name "$file_pattern" -exec sed -i "s|$search|$replace|g" {} +
    fi
}

# Backend Updates
echo "=== Updating Backend Files ==="

# Go files - struct and function names
search_replace "InventoryHandler" "PropertyHandler" "*.go" "backend"
search_replace "NewInventoryHandler" "NewPropertyHandler" "*.go" "backend"
search_replace "GetAllInventoryItems" "GetAllProperties" "*.go" "backend"
search_replace "GetInventoryItem" "GetProperty" "*.go" "backend"
search_replace "CreateInventoryItem" "CreateProperty" "*.go" "backend"
search_replace "UpdateInventoryItemStatus" "UpdatePropertyStatus" "*.go" "backend"
search_replace "GetInventoryItemsByUser" "GetPropertiesByUser" "*.go" "backend"
search_replace "GetInventoryItemHistory" "GetPropertyHistory" "*.go" "backend"
search_replace "VerifyInventoryItem" "VerifyProperty" "*.go" "backend"

# API routes
search_replace '"/inventory"' '"/property"' "*.go" "backend"
search_replace '"/inventory/' '"/property/' "*.go" "backend"

# Log messages and errors
search_replace "inventory item" "property" "*.go" "backend"
search_replace "Inventory item" "Property" "*.go" "backend"

# Ledger event types
search_replace "ITEM_CREATE" "PROPERTY_CREATE" "*.go" "backend"
search_replace "LogItemCreation" "LogPropertyCreation" "*.go" "backend"
search_replace "GetItemHistory" "GetPropertyHistory" "*.go" "backend"

# Frontend Updates
echo ""
echo "=== Updating Frontend Files ==="

# TypeScript/JavaScript files - service functions
search_replace "fetchInventoryItems" "fetchProperties" "*.ts" "web/src"
search_replace "fetchUserInventoryItems" "fetchUserProperties" "*.ts" "web/src"
search_replace "fetchInventoryItem" "fetchProperty" "*.ts" "web/src"
search_replace "createInventoryItem" "createProperty" "*.ts" "web/src"
search_replace "updateInventoryItemStatus" "updatePropertyStatus" "*.ts" "web/src"
search_replace "fetchInventoryItemHistory" "fetchPropertyHistory" "*.ts" "web/src"
search_replace "verifyInventoryItem" "verifyProperty" "*.ts" "web/src"

# Hook names
search_replace "useInventoryItems" "useProperties" "*.ts" "web/src"
search_replace "useUserInventoryItems" "useUserProperties" "*.ts" "web/src"
search_replace "useInventoryItem" "useProperty" "*.ts" "web/src"
search_replace "useInventoryItemHistory" "usePropertyHistory" "*.ts" "web/src"
search_replace "useCreateInventoryItem" "useCreateProperty" "*.ts" "web/src"
search_replace "useUpdateInventoryItemStatus" "useUpdatePropertyStatus" "*.ts" "web/src"
search_replace "useUpdateInventoryItemComponents" "useUpdatePropertyComponents" "*.ts" "web/src"
search_replace "useVerifyInventoryItem" "useVerifyProperty" "*.ts" "web/src"

# Query keys
search_replace "inventoryKeys" "propertyKeys" "*.ts" "web/src"
search_replace "'inventory'" "'property'" "*.ts" "web/src"

# API endpoints
search_replace "/inventory" "/property" "*.ts" "web/src"

# Type names
search_replace "InventoryItem" "Property" "*.ts" "web/src"
search_replace "InventoryItem" "Property" "*.tsx" "web/src"

# Import statements (be careful with these)
search_replace "from '@/services/inventoryService'" "from '@/services/propertyService'" "*.ts" "web/src"
search_replace "from '@/services/inventoryService'" "from '@/services/propertyService'" "*.tsx" "web/src"
search_replace "from '@/hooks/useInventory'" "from '@/hooks/useProperty'" "*.ts" "web/src"
search_replace "from '@/hooks/useInventory'" "from '@/hooks/useProperty'" "*.tsx" "web/src"
search_replace "from '@/lib/inventoryUtils'" "from '@/lib/propertyUtils'" "*.ts" "web/src"
search_replace "from '@/lib/inventoryUtils'" "from '@/lib/propertyUtils'" "*.tsx" "web/src"

# Component imports
search_replace "components/inventory/" "components/property/" "*.ts" "web/src"
search_replace "components/inventory/" "components/property/" "*.tsx" "web/src"
search_replace "CreateItemDialog" "CreatePropertyDialog" "*.ts" "web/src"
search_replace "CreateItemDialog" "CreatePropertyDialog" "*.tsx" "web/src"
search_replace "InventoryItem from" "PropertyCard from" "*.ts" "web/src"
search_replace "InventoryItem from" "PropertyCard from" "*.tsx" "web/src"
search_replace "MyInventory" "MyProperties" "*.ts" "web/src"
search_replace "MyInventory" "MyProperties" "*.tsx" "web/src"

# UI Strings
search_replace '"My Inventory"' '"My Properties"' "*.tsx" "web/src"
search_replace "'My Inventory'" "'My Properties'" "*.tsx" "web/src"
search_replace '"inventory"' '"property"' "*.tsx" "web/src"
search_replace "'inventory'" "'property'" "*.tsx" "web/src"

# iOS Updates
echo ""
echo "=== Updating iOS Files ==="

# Swift files - API endpoints
search_replace '"/inventory"' '"/property"' "*.swift" "ios"
search_replace '"/inventory/' '"/property/' "*.swift" "ios"

# UI Strings
search_replace '"Inventory"' '"Properties"' "*.swift" "ios"
search_replace '"My Inventory"' '"My Properties"' "*.swift" "ios"

# Class/struct names (if any)
search_replace "ReferenceItem" "ReferenceProperty" "*.swift" "ios"

# SQL Updates
echo ""
echo "=== Creating SQL Migration ==="

cat > sql/migrations/006_rename_transfer_items.sql << 'EOF'
-- Migration: Rename transfer_items to transfer_properties
-- Date: $(date +%Y-%m-%d)

BEGIN;

-- Rename the table
ALTER TABLE transfer_items RENAME TO transfer_properties;

-- Update any foreign key constraints if they exist
-- Note: You may need to adjust these based on your actual constraints

-- Add comments
COMMENT ON TABLE transfer_properties IS 'Properties included in transfer requests';

COMMIT;
EOF

echo ""
echo "=== Search and Replace Complete ==="
echo ""
echo "Manual steps still needed:"
echo "1. Review all changes with: git diff"
echo "2. Fix any edge cases or context-specific replacements"
echo "3. Update JSON response keys in handlers (items -> properties)"
echo "4. Update test descriptions and assertions"
echo "5. Run tests to ensure nothing is broken"
echo ""
echo "Common issues to check:"
echo "- Variable names that should remain unchanged"
echo "- Comments that need context-specific updates"
echo "- UI text that needs proper capitalization"
echo "- Import paths that might be broken" 