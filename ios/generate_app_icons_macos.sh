#!/bin/bash

# Generate app icons using macOS native tools
# This script creates all required icon sizes

SOURCE_ICON="HandReceipt/Assets/hr_icon.png"
ICONSET_DIR="HandReceipt/Assets.xcassets/AppIcon.appiconset"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon not found at $SOURCE_ICON"
    exit 1
fi

# Create iconset directory if it doesn't exist
mkdir -p "$ICONSET_DIR"

echo "Generating app icons..."

# Function to resize icon using sips
create_icon() {
    SIZE=$1
    FILENAME=$2
    
    # Copy the original and resize it
    cp "$SOURCE_ICON" "$ICONSET_DIR/$FILENAME"
    sips -z $SIZE $SIZE "$ICONSET_DIR/$FILENAME" --out "$ICONSET_DIR/$FILENAME"
    
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
echo "Note: These icons will maintain transparency. If you want a black background:"
echo "1. Open each icon in Preview"
echo "2. Select all (Cmd+A)"
echo "3. Copy (Cmd+C)"
echo "4. File > New from Clipboard"
echo "5. Tools > Adjust Color > Set background to black"
echo "6. Save over the original file"
echo ""
echo "Or use an online tool like:"
echo "- https://www.appicon.co (can add background colors)"
echo "- https://makeappicon.com" 