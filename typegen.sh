#!/bin/bash
set -e

echo "🔄 Generating type bindings for cross-platform development..."

# Change to project root
cd "$(dirname "$0")"

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ] || [ ! -d "shared" ]; then
    echo "❌ Error: Must be run from the Intrada project root directory"
    exit 1
fi

# Function to generate FFI bindings (uniffi)
generate_ffi_bindings() {
    echo "📦 Step 1: Generating FFI bindings (Shared package)..."
    cd shared
    
    # Generate Swift bindings for iOS
    cargo swift package --name Shared --platforms ios
    
    cd ..
    
    # Clean up any conflicting generated files
    if [ -d "shared/generated" ]; then
        rm -f shared/generated/headers 2>/dev/null || true
        rm -f shared/generated/sources 2>/dev/null || true
        rm -rf shared/generated 2>/dev/null || true
    fi
    
    echo "✅ FFI bindings generated"
}

# Function to generate data types (facet/serde)
generate_data_types() {
    echo "🏗️  Step 2: Generating data types (SharedTypes package)..."
    cd shared_types
    
    # Build the shared_types crate to trigger type generation
    cargo build
    
    cd ..
    echo "✅ Data types generated"
}

# Function to generate core app bindings (crux_cli)
generate_core_bindings() {
    echo "⚙️  Step 3: Generating core application bindings..."
    
    # Generate core bindings using crux_cli
    cargo run --package shared \
              --bin crux_cli \
              --features cli \
              -- bindgen \
              --crate-name shared
    
    echo "✅ Core bindings generated"
}

# Function to validate generated files
validate_generation() {
    echo "🔍 Step 4: Validating generated files..."
    
    local validation_passed=true
    
    # Check FFI bindings
    if [ ! -d "shared/Shared" ]; then
        echo "❌ FFI bindings missing: shared/Shared/"
        validation_passed=false
    else
        echo "✅ FFI bindings: shared/Shared/"
    fi
    
    # Check Swift data types
    if [ ! -d "shared_types/generated/swift" ]; then
        echo "❌ Swift types missing: shared_types/generated/swift/"
        validation_passed=false
    else
        echo "✅ Swift types: shared_types/generated/swift/"
    fi
    
    # Check core bindings
    if [ ! -d "shared/generated" ]; then
        echo "❌ Core bindings missing: shared/generated/"
        validation_passed=false
    else
        echo "✅ Core bindings: shared/generated/"
    fi
    
    # Check specific important files
    if [ ! -f "shared/Shared/Sources/Shared/shared.swift" ]; then
        echo "⚠️  Warning: shared.swift not found in expected location"
    fi
    
    if [ ! -f "shared_types/generated/swift/SharedTypes/Sources/SharedTypes/SharedTypes.swift" ]; then
        echo "⚠️  Warning: SharedTypes.swift not found in expected location"
    fi
    
    if [ "$validation_passed" = false ]; then
        echo "❌ Type generation validation failed"
        exit 1
    fi
    
    echo "✅ All type generation validation passed"
}

# Function to show summary
show_summary() {
    echo ""
    echo "🎉 Type generation completed successfully!"
    echo ""
    echo "📁 Generated files:"
    echo "   • shared/Shared/ (FFI bindings for iOS)"
    echo "   • shared_types/generated/swift/ (Data type bindings)"
    echo "   • shared/generated/ (Core application bindings)"
    echo ""
    echo "💡 These files provide cross-platform type safety between:"
    echo "   • Rust core (shared business logic)"
    echo "   • Swift iOS app"
    echo "   • Other platform integrations"
}

# Main execution
echo "📋 Starting cross-platform type generation..."

generate_ffi_bindings
generate_data_types  
generate_core_bindings
validate_generation
show_summary

echo ""
echo "🚀 Ready for cross-platform development!"