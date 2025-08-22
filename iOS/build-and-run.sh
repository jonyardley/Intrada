#!/bin/bash
set -e

# Auto-detect the iPhone 16 simulator device ID (prefer iOS 26)
DEVICE_ID=$(xcrun simctl list devices | grep -A 20 "iOS 26" | grep "iPhone 16 (" | grep -v Plus | grep -v Pro | head -1 | grep -o '([A-F0-9-]*)' | tr -d '()')
BUNDLE_ID="com.jonyardley.Intrada"

if [ -z "$DEVICE_ID" ]; then
    echo "❌ Could not find iPhone 16 simulator"
    exit 1
fi

echo "📱 Using device: $DEVICE_ID"

echo "🏗️  Building app..."
xcodebuild -project Intrada.xcodeproj \
           -scheme Intrada \
           -configuration Debug \
           -destination "id=$DEVICE_ID" \
           -sdk iphonesimulator \
           build -quiet

echo "📱 Booting simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
sleep 2

echo "📲 Installing app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name 'Intrada.app' -path '*/Build/Products/Debug-iphonesimulator/*' | head -1)

# Uninstall any existing version first
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

# Install the app
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
sleep 2

echo "🚀 Launching app..."
open -a Simulator
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "✅ App launched successfully!"
sleep 3

if xcrun simctl spawn booted launchctl list | grep -i intrada >/dev/null 2>&1; then
    echo "📱 App is running"
else
    echo "⚠️  App may have crashed - run 'iOS Crash Logs' task for details"
fi