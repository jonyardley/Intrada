#!/usr/bin/env bash

set -eux

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

echo "🏗️  Building Intrada project..."
echo "📁 Working from: $REPO_ROOT"

# Step 1: Generate Xcode project
echo "📱 Generating Xcode project..."
pushd "$REPO_ROOT/iOS"
xcodegen
popd

# Step 2: Build shared crate
echo "🦀 Building shared crate..."
cargo build --manifest-path "$REPO_ROOT/shared/Cargo.toml"

# Step 3: Build shared_types crate
echo "🔧 Building shared_types crate..."
cargo build --manifest-path "$REPO_ROOT/shared_types/Cargo.toml"

# Step 4: Run type generation
echo "🔄 Running type generation..."
bash "$REPO_ROOT/typegen.sh"

echo "✅ Build and type generation complete!"
echo "🎉 Ready for development!" 