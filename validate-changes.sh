#!/bin/bash

# Intrada Project - Comprehensive Change Validation Script
# This script ensures all changes meet the project's quality standards

set -e  # Exit on any error

echo "🔍 Running full validation suite for Intrada project..."
echo "📋 This script validates: compilation, formatting, linting, typegen, and all apps"
echo ""

# Store the original directory
ORIGINAL_DIR=$(pwd)

# Function to return to original directory on exit
cleanup() {
    cd "$ORIGINAL_DIR"
}
trap cleanup EXIT

echo "1️⃣ Checking compilation..."
echo "   Building all workspace crates..."
cargo build --workspace
echo "   ✅ Compilation successful"
echo ""

echo "2️⃣ Checking formatting..."
echo "   Verifying code formatting..."
cargo fmt --all --check
echo "   ✅ Formatting check passed"
echo ""

echo "3️⃣ Checking linting..."
echo "   Running Clippy on all targets..."
cargo clippy --workspace --all-targets --all-features -- -D warnings
echo "   ✅ Linting check passed"
echo ""

echo "4️⃣ Running type generation..."
echo "   Building and generating types for all platforms..."
./build-and-typegen.sh
echo "   ✅ Type generation successful"
echo ""

echo "5️⃣ Testing web-leptos..."
echo "   Building and testing web application..."
cd web-leptos
cargo build
cargo test
cd ..
echo "   ✅ Web-leptos validation passed"
echo ""

echo "6️⃣ Testing iOS app..."
echo "   Building and running iOS application..."
cd iOS
./build-and-run.sh
cd ..
echo "   ✅ iOS app validation passed"
echo ""

echo "7️⃣ Testing server (if applicable)..."
echo "   Building and testing server..."
cd server
cargo build
cargo test
cd ..
echo "   ✅ Server validation passed"
echo ""

echo "🎉 ALL VALIDATIONS PASSED! 🎉"
echo ""
echo "Your changes have been validated and are ready for:"
echo "  - Compilation ✅"
echo "  - Formatting ✅" 
echo "  - Linting ✅"
echo "  - Type Generation ✅"
echo "  - Web-Leptos App ✅"
echo "  - iOS App ✅"
echo "  - Server ✅"
echo ""
echo "🚀 Changes are ready for deployment!" 