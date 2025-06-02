#!/bin/bash

# Generate app icons from hr_logo6.png
# This script generates all required sizes for iOS app icons

SOURCE_ICON="HandReceipt/hr_logo6.png"
ICONSET_DIR="HandReceipt/Assets.xcassets/AppIcon.appiconset"

# Check if source icon exists
if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon not found at $SOURCE_ICON"
    exit 1
fi

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed. Please install it using:"
    echo "  brew install imagemagick"
    exit 1
fi

# Create iconset directory if it doesn't exist
mkdir -p "$ICONSET_DIR"

echo "Generating app icons from hr_logo6..."

# Function to create icon
create_icon() {
    SIZE=$1
    FILENAME=$2
    
    # Resize the icon to the required size
    # Since hr_logo6 already has a black background, we just resize it
    convert "$SOURCE_ICON" -resize ${SIZE}x${SIZE} "$ICONSET_DIR/$FILENAME"
    
    echo "Created $FILENAME (${SIZE}x${SIZE})"
}

# Generate all required sizes for iPhone
create_icon 40 "icon-20@2x.png"
create_icon 60 "icon-20@3x.png"
create_icon 58 "icon-29@2x.png"
create_icon 87 "icon-29@3x.png"
create_icon 80 "icon-40@2x.png"
create_icon 120 "icon-40@3x.png"
create_icon 120 "icon-60@2x.png"
create_icon 180 "icon-60@3x.png"

# Generate all required sizes for iPad
create_icon 20 "icon-20.png"
create_icon 40 "icon-20@2x-ipad.png"
create_icon 29 "icon-29.png"
create_icon 58 "icon-29@2x-ipad.png"
create_icon 40 "icon-40.png"
create_icon 80 "icon-40@2x-ipad.png"
create_icon 76 "icon-76.png"
create_icon 152 "icon-76@2x.png"
create_icon 167 "icon-83.5@2x.png"

# Generate App Store icon
create_icon 1024 "icon-1024.png"

echo ""
echo "✅ App icons generated successfully!"
echo ""
echo "Next steps:"
echo "1. Open Terminal and navigate to the ios directory"
echo "2. Run: chmod +x generate_hr_logo6_icons.sh"
echo "3. Run: ./generate_hr_logo6_icons.sh"
echo "4. Open your Xcode project and clean build (Cmd+Shift+K)"
echo "5. Build and run to see your new app icon!" 