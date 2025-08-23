#!/bin/bash
set -e

echo "🚀 Starting Intrada development environment"

# Change to project root
cd "$(dirname "$0")"

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ] || [ ! -d "shared" ]; then
    echo "❌ Error: Must be run from the Intrada project root directory"
    exit 1
fi

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Error: Docker is not running. Please start Docker Desktop and try again."
        exit 1
    fi
}

# Function to stop existing services
stop_existing_services() {
    echo "🛑 Stopping existing services..."
    
    # Kill any existing server processes
    pkill -f "server" 2>/dev/null || true
    
    # Stop Docker containers
    cd server && docker-compose down 2>/dev/null || true
    cd ..
    
    sleep 2
}

# Function to start PostgreSQL
start_postgres() {
    echo "🔄 Starting PostgreSQL database..."
    cd server
    docker-compose up -d
    cd ..
    sleep 3
}

# Function to build and run server
start_server() {
    echo "🔄 Building and starting server..."
    cd server
    
    # Start server in background
    nohup cargo run --package server > ../server.log 2>&1 &
    SERVER_PID=$!
    
    cd ..
    
    # Give server time to start and check if it's running
    sleep 3
    
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "❌ Error: Server failed to start. Check server.log for details."
        exit 1
    fi
    
    echo "✅ Server started successfully (PID: $SERVER_PID)"
}

# Function to build and run iOS app (if on macOS)
start_ios() {
    if [ "$(uname)" != "Darwin" ]; then
        echo "⚠️  Skipping iOS app (not on macOS)"
        return
    fi
    
    if [ ! -d "iOS" ]; then
        echo "⚠️  Skipping iOS app (iOS directory not found)"
        return
    fi
    
    echo "🔄 Building and launching iOS app..."
    cd iOS
    
    # Generate Xcode project
    echo "📱 Generating Xcode project..."
    xcodegen
    
    # Find available iOS simulator
    SIMULATOR_ID=$(xcrun simctl list devices available | grep 'iPhone.*(' | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*/\1/p')
    
    if [ -z "$SIMULATOR_ID" ]; then
        echo "⚠️  No iPhone simulators found, using 'booted' simulator"
        SIMULATOR_ID="booted"
    fi
    
    # Boot simulator if needed and open Simulator app
    if [ "$SIMULATOR_ID" != "booted" ]; then
        echo "📱 Booting simulator: $SIMULATOR_ID"
        xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || true
        sleep 3
    else
        echo "📱 Using currently booted simulator"
    fi
    
    # Ensure Simulator app is open and visible
    echo "📱 Opening Simulator app..."
    open -a Simulator
    sleep 2
    
    # Build the app with proper configuration
    echo "🔨 Building iOS app..."
    xcodebuild \
        -project Intrada.xcodeproj \
        -scheme Intrada \
        -destination "id=$SIMULATOR_ID" \
        -configuration Debug \
        build \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        ONLY_ACTIVE_ARCH=YES
    
    # Find the built app bundle
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Intrada.app" -path "*/Build/Products/Debug-iphonesimulator/*" | head -1)
    
    if [ -z "$APP_PATH" ]; then
        echo "❌ Could not find built Intrada.app bundle"
        cd ..
        return 1
    fi
    
    echo "📦 Found app at: $APP_PATH"
    
    # Install the app on the simulator
    echo "📥 Installing app on simulator..."
    xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
    
    # Give the installation a moment
    sleep 2
    
    # Launch app
    echo "🚀 Launching app..."
    xcrun simctl launch "$SIMULATOR_ID" com.jonyardley.Intrada || {
        echo "⚠️  App launch failed, but app should be installed"
        echo "📱 You can manually tap the Intrada app icon in the Simulator"
        cd ..
        return 0
    }
    
    # Bring Simulator to front
    osascript -e 'tell application "Simulator" to activate' 2>/dev/null || true
    
    cd ..
    echo "✅ iOS app launched successfully"
}

# Main execution
echo "📋 Starting Intrada development environment..."

check_docker
stop_existing_services
start_postgres
start_server
start_ios

echo ""
echo "🎉 Development environment started successfully!"
echo ""
echo "📋 Services:"
echo "   🐘 PostgreSQL: Running in Docker"
echo "   🖥️  Server: Running on http://localhost:3000"
echo "   📱 iOS App: Running in simulator"
echo ""
echo "📋 Useful commands:"
echo "   xt logs server   # View server logs"
echo "   xt logs all      # View all logs"
echo "   xt dev stop      # Stop all services"
echo ""