#!/usr/bin/env bash

set -eux

echo "🔄 Generating type bindings for iOS..."

# Generate FFI bindings (uniffi) - provides CoreFFI interface for iOS
echo "📦 Generating FFI bindings (Shared package)..."
pushd shared
cargo swift package --name Shared --platforms ios
pushd generated
rm -rf headers sources *.swift *.h *.modulemap
popd
popd

# Generate data types (facet) - provides SharedTypes for iOS
echo "🏗️  Generating data types (SharedTypes package)..."
pushd shared_types
cargo build
popd

# Generate core app bindings (crux_cli) - provides event/effect types
echo "⚙️  Generating core bindings..."
cargo run --package shared --bin crux_cli --features cli -- \
    bindgen \
        --crate-name shared

echo "✅ Type generation complete!"
echo "📁 Generated files:"
echo "   - shared/Shared/ (FFI bindings)"
echo "   - shared_types/generated/swift/ (Data types)"  
echo "   - shared/generated/ (Core bindings)"