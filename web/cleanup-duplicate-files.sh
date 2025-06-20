#!/bin/bash

# Script to clean up duplicate .jsx and .d.ts files after TypeScript migration

echo "=== TypeScript Migration Cleanup ==="
echo "This script will remove duplicate .jsx and incorrect .d.ts files"
echo ""

# Count files before cleanup
echo "Files before cleanup:"
echo "  .d.ts files: $(find src -name "*.d.ts" | wc -l)"
echo "  .jsx files: $(find src -name "*.jsx" | wc -l)"
echo "  .tsx files: $(find src -name "*.tsx" | wc -l)"
echo ""

# Create backup directory
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup .jsx files
echo "Backing up .jsx files..."
find src -name "*.jsx" -exec cp --parents {} "$BACKUP_DIR"/ \; 2>/dev/null || \
find src -name "*.jsx" | while read file; do
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    cp "$file" "$BACKUP_DIR/$file"
done

# Backup .d.ts files
echo "Backing up .d.ts files..."
find src -name "*.d.ts" -exec cp --parents {} "$BACKUP_DIR"/ \; 2>/dev/null || \
find src -name "*.d.ts" | while read file; do
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    cp "$file" "$BACKUP_DIR/$file"
done

echo ""
echo "Backup created in: $BACKUP_DIR"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with deletion? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Removing files..."
    
    # Remove .d.ts files
    echo "Removing .d.ts files..."
    find src -name "*.d.ts" -delete
    
    # Remove .jsx files
    echo "Removing .jsx files..."
    find src -name "*.jsx" -delete
    
    echo ""
    echo "Files after cleanup:"
    echo "  .d.ts files: $(find src -name "*.d.ts" | wc -l)"
    echo "  .jsx files: $(find src -name "*.jsx" | wc -l)"
    echo "  .tsx files: $(find src -name "*.tsx" | wc -l)"
    
    echo ""
    echo "Cleanup complete!"
    echo ""
    echo "Now running TypeScript check..."
    npm run check
else
    echo "Cleanup cancelled."
fi