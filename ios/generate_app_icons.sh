#!/bin/bash

# Generate app icons from the HR logo
# This script adds a black background and generates all required sizes

SOURCE_ICON="HandReceipt/Assets/hr_icon.png"
ICONSET_DIR="HandReceipt/Assets.xcassets/AppIcon.appiconset"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon not found at $SOURCE_ICON"
    exit 1
fi

# Create iconset directory if it doesn't exist
mkdir -p "$ICONSET_DIR"

echo "Generating app icons with black background..."

# Function to create icon with black background
create_icon() {
    SIZE=$1
    FILENAME=$2
    
    # Create a black background and composite the icon on top
    # This ensures transparency is properly handled
    convert -size ${SIZE}x${SIZE} xc:black \
            "$SOURCE_ICON" -resize ${SIZE}x${SIZE} -gravity center -composite \
            "$ICONSET_DIR/$FILENAME"
    
    echo "Created $FILENAME (${SIZE}x${SIZE})"
}

# Generate all required sizes
create_icon 40 "icon-20@2x.png"
create_icon 60 "icon-20@3x.png"
create_icon 58 "icon-29@2x.png"
create_icon 87 "icon-29@3x.png"
create_icon 80 "icon-40@2x.png"
create_icon 120 "icon-40@3x.png"
create_icon 120 "icon-60@2x.png"
create_icon 180 "icon-60@3x.png"
create_icon 1024 "icon-1024.png"

echo "App icons generated successfully!"
echo ""
echo "Next steps:"
echo "1. Open your Xcode project"
echo "2. The app icon should now appear in Assets.xcassets"
echo "3. Make sure your app target is using 'AppIcon' as its icon set"
echo "4. Build and run to see your new app icon!" 