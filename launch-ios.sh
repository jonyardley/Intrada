#!/bin/bash
set -e

echo "🔧 iOS App Launch Helper"

# Find booted simulator
SIMULATOR_ID=$(xcrun simctl list devices | grep "(Booted)" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ No booted simulator found"
    echo "💡 Run 'xt start' or 'xt quick' to start the development environment"
    exit 1
fi

echo "📱 Found booted simulator: $SIMULATOR_ID"

# Check if app is installed
if xcrun simctl listapps "$SIMULATOR_ID" | grep -q "com.jonyardley.Intrada"; then
    echo "✅ Intrada app is installed"
else
    echo "❌ Intrada app is not installed"
    echo "💡 Run 'xt start' or 'xt quick' to build and install the app"
    exit 1
fi

# Open Simulator app
echo "📱 Opening Simulator..."
open -a Simulator
sleep 2

# Try to launch the app
echo "🚀 Launching Intrada app..."
if xcrun simctl launch "$SIMULATOR_ID" com.jonyardley.Intrada; then
    echo "✅ App launched successfully!"
    osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
else
    echo "⚠️  App launch failed via command line"
    echo "📱 The Simulator should now be open - manually tap the Intrada app icon"
fi