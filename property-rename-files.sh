#!/bin/bash

# Property Rename Automation Script for hrx repository
# This script helps automate the renaming of inventory/item to property

set -e  # Exit on error

echo "=== HandReceipt Property Rename Script ==="
echo "This script will help rename inventory/item references to property"
echo ""

# Check if we're in the right directory
if [ ! -d "backend" ] || [ ! -d "web" ] || [ ! -d "ios" ]; then
    echo "Error: This script must be run from the hrx repository root"
    exit 1
fi

# Create backup branch
echo "Creating backup branch..."
git checkout -b property-rename-backup-$(date +%Y%m%d-%H%M%S)
git checkout -

# Function to perform git mv with error handling
safe_git_mv() {
    if [ -e "$1" ]; then
        echo "Renaming: $1 -> $2"
        git mv "$1" "$2"
    else
        echo "Warning: $1 not found, skipping..."
    fi
}

# Phase 1: Backend file renames
echo ""
echo "=== Phase 1: Backend File Renames ==="

safe_git_mv "backend/internal/api/handlers/inventory_handler.go" \
            "backend/internal/api/handlers/property_handler.go"

# Phase 2: Frontend file renames
echo ""
echo "=== Phase 2: Frontend File Renames ==="

# Service files
safe_git_mv "web/src/services/inventoryService.ts" \
            "web/src/services/propertyService.ts"

safe_git_mv "web/src/hooks/useInventory.ts" \
            "web/src/hooks/useProperty.ts"

safe_git_mv "web/src/lib/inventoryUtils.ts" \
            "web/src/lib/propertyUtils.ts"

# Component directory
safe_git_mv "web/src/components/inventory" \
            "web/src/components/property"

# Individual component renames
safe_git_mv "web/src/components/property/CreateItemDialog.tsx" \
            "web/src/components/property/CreatePropertyDialog.tsx"

safe_git_mv "web/src/components/common/InventoryItem.tsx" \
            "web/src/components/common/PropertyCard.tsx"

safe_git_mv "web/src/components/dashboard/MyInventory.tsx" \
            "web/src/components/dashboard/MyProperties.tsx"

safe_git_mv "web/src/components/maintenance/MaintenanceItemRow.tsx" \
            "web/src/components/maintenance/MaintenancePropertyRow.tsx"

safe_git_mv "web/src/pages/SensitiveItems.tsx" \
            "web/src/pages/SensitiveProperties.tsx"

safe_git_mv "web/src/lib/sensitiveItemsData.ts" \
            "web/src/lib/sensitivePropertiesData.ts"

# Test files
safe_git_mv "web/cypress/e2e/inventory-transfers.cy.ts" \
            "web/cypress/e2e/property-transfers.cy.ts"

# Phase 3: iOS file renames (if applicable)
echo ""
echo "=== Phase 3: iOS File Renames ==="

safe_git_mv "ios/HandReceipt/Models/ReferenceItem.swift" \
            "ios/HandReceipt/Models/ReferenceProperty.swift"

safe_git_mv "ios/HandReceipt/Views/ReferenceItemDetailView.swift" \
            "ios/HandReceipt/Views/ReferencePropertyDetailView.swift"

safe_git_mv "ios/HandReceipt/ViewModels/ReferenceItemDetailViewModel.swift" \
            "ios/HandReceipt/ViewModels/ReferencePropertyDetailViewModel.swift"

safe_git_mv "ios/HandReceipt/Views/SensitiveItemsView.swift" \
            "ios/HandReceipt/Views/SensitivePropertiesView.swift"

echo ""
echo "=== File renames complete ==="
echo ""
echo "Next steps:"
echo "1. Run the search-replace script (property-search-replace.sh)"
echo "2. Manually update the content of renamed files"
echo "3. Update import statements"
echo "4. Test thoroughly"
echo ""
echo "To see what was changed: git status"
echo "To commit: git add . && git commit -m 'Rename inventory/item files to property'" 