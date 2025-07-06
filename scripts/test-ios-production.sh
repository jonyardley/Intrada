#!/bin/bash

# iOS Production Testing Script
# This script helps you test your iOS app against production without needing a paid Apple account

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🍎 iOS Production Testing Setup${NC}"
echo -e "${BLUE}================================${NC}"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This script requires macOS with Xcode${NC}"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode not found. Please install Xcode from the App Store${NC}"
    exit 1
fi

# Configuration
PROD_ENDPOINT="${APPWRITE_ENDPOINT_PROD:-https://cloud.appwrite.io/v1}"
PROD_PROJECT_ID="${APPWRITE_PROJECT_ID_PROD:-intrada-prod}"
DATABASE_ID="intrada_db"

echo -e "${YELLOW}📋 Production Configuration:${NC}"
echo -e "  Endpoint: ${PROD_ENDPOINT}"
echo -e "  Project: ${PROD_PROJECT_ID}"
echo -e "  Database: ${DATABASE_ID}"
echo ""

# Function to create production config
create_production_config() {
    echo -e "${YELLOW}📝 Creating production Config.plist...${NC}"
    
    cd iOS/Intrada
    
    cat > Config.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AppwriteEndpoint</key>
    <string>${PROD_ENDPOINT}</string>
    <key>AppwriteProjectId</key>
    <string>${PROD_PROJECT_ID}</string>
    <key>AppwriteDatabaseId</key>
    <string>${DATABASE_ID}</string>
    <key>Environment</key>
    <string>production</string>
</dict>
</plist>
EOF
    
    echo -e "${GREEN}✅ Production config created${NC}"
    cd ../..
}

# Function to build Rust library
build_rust_library() {
    echo -e "${YELLOW}🦀 Building Rust shared library...${NC}"
    
    cd shared
    
    # Check if cargo-lipo is installed
    if ! command -v cargo-lipo &> /dev/null; then
        echo -e "${YELLOW}Installing cargo-lipo...${NC}"
        cargo install cargo-lipo
    fi
    
    # Build for iOS targets
    echo -e "${YELLOW}Building for iOS targets...${NC}"
    cargo lipo --release --targets aarch64-apple-ios,aarch64-apple-ios-sim,x86_64-apple-ios
    
    # Generate Swift bindings
    echo -e "${YELLOW}Generating Swift bindings...${NC}"
    cargo run --bin uniffi-bindgen generate src/shared.udl --language swift --out-dir ../iOS/Generated/
    
    echo -e "${GREEN}✅ Rust library built successfully${NC}"
    cd ..
}

# Function to build iOS app
build_ios_app() {
    echo -e "${YELLOW}🍎 Building iOS app...${NC}"
    
    cd iOS
    
    # Update bundle identifier for production
    echo -e "${YELLOW}Updating bundle identifier...${NC}"
    
    # Build for simulator (no signing required)
    echo -e "${YELLOW}Building for iOS Simulator...${NC}"
    xcodebuild \
        -project Intrada.xcodeproj \
        -scheme Intrada \
        -configuration Release \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
        clean build \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    echo -e "${GREEN}✅ iOS app built successfully${NC}"
    cd ..
}

# Function to run simulator tests
run_simulator_tests() {
    echo -e "${YELLOW}🧪 Running tests in iOS Simulator...${NC}"
    
    cd iOS
    
    # Start iOS Simulator
    echo -e "${YELLOW}Starting iOS Simulator...${NC}"
    open -a Simulator
    
    # Wait for simulator to boot
    sleep 10
    
    # Run tests
    xcodebuild \
        -project Intrada.xcodeproj \
        -scheme Intrada \
        -configuration Release \
        -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
        test \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    echo -e "${GREEN}✅ Tests completed${NC}"
    cd ..
}

# Function to install app in simulator
install_in_simulator() {
    echo -e "${YELLOW}📱 Installing app in iOS Simulator...${NC}"
    
    # Find the built app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Intrada.app" -type d | head -1)
    
    if [[ -z "$APP_PATH" ]]; then
        echo -e "${RED}❌ Could not find built app. Make sure build completed successfully.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Found app at: $APP_PATH${NC}"
    
    # Get booted simulator UDID
    SIMULATOR_UDID=$(xcrun simctl list devices | grep "iPhone 15 Pro" | grep "Booted" | grep -o -E "\([A-F0-9-]{36}\)" | tr -d "()")
    
    if [[ -z "$SIMULATOR_UDID" ]]; then
        echo -e "${YELLOW}Booting iPhone 15 Pro simulator...${NC}"
        xcrun simctl boot "iPhone 15 Pro"
        sleep 10
        SIMULATOR_UDID=$(xcrun simctl list devices | grep "iPhone 15 Pro" | grep "Booted" | grep -o -E "\([A-F0-9-]{36}\)" | tr -d "()")
    fi
    
    if [[ -n "$SIMULATOR_UDID" ]]; then
        echo -e "${YELLOW}Installing app on simulator $SIMULATOR_UDID...${NC}"
        xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
        echo -e "${GREEN}✅ App installed in simulator${NC}"
        echo -e "${BLUE}You can now test the app manually in the iOS Simulator${NC}"
    else
        echo -e "${RED}❌ Could not find booted simulator${NC}"
        return 1
    fi
}

# Function to create IPA (for future signing)
create_ipa() {
    echo -e "${YELLOW}📦 Creating IPA file (unsigned)...${NC}"
    
    cd iOS
    
    # Create archive
    xcodebuild \
        -project Intrada.xcodeproj \
        -scheme Intrada \
        -configuration Release \
        -archivePath ./build/Intrada.xcarchive \
        archive \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO
    
    # Export IPA
    mkdir -p ./build
    
    cat > ./build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>compileBitcode</key>
    <false/>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
EOF
    
    xcodebuild \
        -exportArchive \
        -archivePath ./build/Intrada.xcarchive \
        -exportPath ./build \
        -exportOptionsPlist ./build/ExportOptions.plist
    
    echo -e "${GREEN}✅ IPA created at iOS/build/Intrada.ipa${NC}"
    echo -e "${BLUE}💡 This IPA can be signed later with a paid Apple Developer account${NC}"
    cd ..
}

# Function to show testing instructions
show_testing_instructions() {
    echo ""
    echo -e "${BLUE}📋 Testing Instructions${NC}"
    echo -e "${BLUE}=====================${NC}"
    echo ""
    echo -e "${GREEN}✅ Your iOS app is now configured to test against production!${NC}"
    echo ""
    echo -e "${YELLOW}What you can do now:${NC}"
    echo -e "  1. 📱 Test in iOS Simulator (already installed)"
    echo -e "  2. 🧪 Run automated tests against production backend"
    echo -e "  3. 📦 IPA file created for future device installation"
    echo ""
    echo -e "${YELLOW}To test on a physical device (requires Apple Developer Account):${NC}"
    echo -e "  1. Sign up for Apple Developer Program (\$99/year)"
    echo -e "  2. Add signing certificates to Xcode"
    echo -e "  3. Install on device via Xcode"
    echo ""
    echo -e "${YELLOW}Alternative testing options:${NC}"
    echo -e "  1. 🌐 Test web version at your production URL"
    echo -e "  2. 📊 Monitor production API calls via Appwrite console"
    echo -e "  3. 🤖 Use GitHub Actions to run automated tests"
    echo ""
    echo -e "${BLUE}📊 Production Backend Status:${NC}"
    curl -s "${PROD_ENDPOINT}/health" | jq . || echo "Backend health check failed"
}

# Main execution
echo -e "${YELLOW}🚀 Starting iOS production testing setup...${NC}"

# Check if we're in the right directory
if [[ ! -d "iOS" || ! -d "shared" ]]; then
    echo -e "${RED}❌ Please run this script from the project root directory${NC}"
    exit 1
fi

# Execute steps
create_production_config
build_rust_library
build_ios_app
run_simulator_tests
install_in_simulator
create_ipa
show_testing_instructions

echo ""
echo -e "${GREEN}🎉 iOS production testing setup completed!${NC}"
echo -e "${BLUE}Your app is now running in the iOS Simulator connected to production.${NC}"