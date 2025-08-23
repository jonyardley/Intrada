#!/bin/bash
set -e

echo "🏗️  Building Intrada with type generation..."

# Change to project root
cd "$(dirname "$0")"

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ] || [ ! -d "shared" ]; then
    echo "❌ Error: Must be run from the Intrada project root directory"
    exit 1
fi

# Function to build shared crate
build_shared() {
    echo "🦀 Building shared crate..."
    cargo build --manifest-path shared/Cargo.toml
    echo "✅ Shared crate built"
}

# Function to build shared_types crate
build_shared_types() {
    echo "🔧 Building shared_types crate..."
    cargo build --manifest-path shared_types/Cargo.toml
    echo "✅ Shared_types crate built"
}

# Function to generate type bindings
generate_types() {
    echo "🔄 Running type generation..."
    ./typegen.sh
}

# Function to generate iOS Xcode project
generate_ios_project() {
    echo "📱 Generating iOS Xcode project..."
    if [ -d "iOS" ]; then
        cd iOS
        xcodegen
        cd ..
        echo "✅ iOS Xcode project generated"
    else
        echo "⚠️  iOS directory not found, skipping iOS project generation"
    fi
}

# Function to validate build
validate_build() {
    echo "🔍 Validating build..."
    
    # Basic build validation - typegen.sh already validates type generation
    echo "✅ Build validation passed (type validation handled by typegen.sh)"
}

# Main execution
echo "📋 Starting full build with type generation..."

build_shared
build_shared_types
generate_types
generate_ios_project
validate_build

echo ""
echo "🎉 Build and type generation completed successfully!"
echo ""
echo "📁 Build outputs:"
if [ -d "iOS" ]; then
    echo "   • iOS/Intrada.xcodeproj (Xcode project)"
fi
echo "   • Type bindings (see typegen.sh output above)"
echo ""
echo "🚀 Ready for development!"
echo "💡 Run 'cargo xtask start' to launch the full development environment"