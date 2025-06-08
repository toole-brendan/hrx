#!/bin/bash

echo "🧹 Cleaning iOS build..."

# Clean build folder
echo "📁 Cleaning build folder..."
xcodebuild clean -project HandReceipt/HandReceipt.xcodeproj -scheme HandReceipt

# Delete derived data
echo "🗑️  Deleting derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/HandReceipt-*

# Clean simulator
echo "📱 Resetting simulator..."
xcrun simctl shutdown all
xcrun simctl erase all

echo "✅ Clean complete!"
echo ""
echo "To rebuild the project:"
echo "1. Open Xcode"
echo "2. Select your target device/simulator"
echo "3. Press ⌘R to build and run"
echo ""
echo "Or run: xcodebuild -project HandReceipt/HandReceipt.xcodeproj -scheme HandReceipt -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build"
echo ""
echo "To suppress system logs during debugging:"
echo "1. Edit Scheme → Run → Arguments → Environment Variables"
echo "2. Add: OS_ACTIVITY_MODE = disable"
echo "3. Add: IDEPreferLogStreaming = NO" 