#!/bin/bash
set -e

echo "📱 Building and running iOS app..."

# Change to iOS directory
cd "$(dirname "$0")"

# Check for build-only flag
BUILD_ONLY=false
if [ "$1" = "--build-only" ]; then
    BUILD_ONLY=true
fi

# Function to generate Xcode project
generate_project() {
    echo "🔄 Generating Xcode project..."
    xcodegen
    echo "✅ Xcode project generated"
}

# Function to build iOS app
build_app() {
    echo "🔄 Building iOS app..."
    
    # Use generic simulator destination for build-only
    if [ "$BUILD_ONLY" = true ]; then
        xcodebuild -project Intrada.xcodeproj \
                   -scheme Intrada \
                   -destination 'generic/platform=iOS Simulator' \
                   build
    else
        # Find available iPhone simulator for full build
        SIMULATOR_ID=$(xcrun simctl list devices available | grep 'iPhone.*(' | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')
        
        if [ -z "$SIMULATOR_ID" ]; then
            echo "⚠️  No iPhone simulators found, using generic destination"
            xcodebuild -project Intrada.xcodeproj \
                       -scheme Intrada \
                       -destination 'generic/platform=iOS Simulator' \
                       build
        else
            echo "📱 Building for simulator: $SIMULATOR_ID"
            xcodebuild -project Intrada.xcodeproj \
                       -scheme Intrada \
                       -destination "id=$SIMULATOR_ID" \
                       build
        fi
    fi
    
    echo "✅ iOS app built successfully"
}

# Function to run iOS app in simulator
run_app() {
    if [ "$BUILD_ONLY" = true ]; then
        echo "⚠️  Build-only mode, skipping app launch"
        return
    fi
    
    echo "🔄 Launching iOS app in simulator..."
    
    # Find available iPhone simulator
    SIMULATOR_ID=$(xcrun simctl list devices available | grep 'iPhone.*(' | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')
    
    if [ -z "$SIMULATOR_ID" ]; then
        echo "❌ No iPhone simulators found for launch"
        return
    fi
    
    # Boot simulator if needed
    xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
    sleep 2
    
    # Launch app
    BUNDLE_ID="com.jonyardley.Intrada"
    xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
    
    echo "✅ iOS app launched successfully"
}

# Main execution
generate_project
build_app
run_app

if [ "$BUILD_ONLY" = true ]; then
    echo "🎉 iOS app build completed!"
else
    echo "🎉 iOS app built and launched successfully!"
fi