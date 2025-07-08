#!/bin/bash

# CI Optimization Validation Script
# Validates that the optimized CI workflow is properly configured

set -e

echo "🔍 CI Optimization Validation"
echo "============================"

# Check if required files exist
echo "📁 Checking required files..."

required_files=(
    ".github/actions/setup-rust/action.yml"
    ".github/workflows/main-ci-optimized.yml"
    "rust-toolchain.toml"
    "Cargo.toml"
    "Cargo.lock"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
        exit 1
    fi
done

echo ""
echo "🔧 Validating composite action..."

# Check composite action structure
if grep -q "name: 'Setup Rust Toolchain'" .github/actions/setup-rust/action.yml; then
    echo "✅ Composite action properly named"
else
    echo "❌ Composite action name issue"
    exit 1
fi

if grep -q "uses: actions/cache@v4" .github/actions/setup-rust/action.yml; then
    echo "✅ Composite action uses proper cache version"
else
    echo "❌ Composite action cache version issue"
    exit 1
fi

echo ""
echo "🏗️  Validating workflow structure..."

# Check workflow structure
if grep -q "build-artifacts:" .github/workflows/main-ci-optimized.yml; then
    echo "✅ Unified build job exists"
else
    echo "❌ Unified build job missing"
    exit 1
fi

if grep -q "uses: ./.github/actions/setup-rust" .github/workflows/main-ci-optimized.yml; then
    echo "✅ Workflow uses composite action"
else
    echo "❌ Workflow doesn't use composite action"
    exit 1
fi

if grep -q "upload-artifact@v4" .github/workflows/main-ci-optimized.yml; then
    echo "✅ Artifact upload configured"
else
    echo "❌ Artifact upload missing"
    exit 1
fi

if grep -q "download-artifact@v4" .github/workflows/main-ci-optimized.yml; then
    echo "✅ Artifact download configured"
else
    echo "❌ Artifact download missing"
    exit 1
fi

echo ""
echo "📊 Analyzing cache strategy..."

# Count cache actions in old vs new workflow
old_caches=$(grep -c "uses: actions/cache@v4" .github/workflows/main-ci.yml 2>/dev/null || echo "0")
new_caches=$(grep -c "uses: actions/cache@v4" .github/workflows/main-ci-optimized.yml 2>/dev/null || echo "0")

echo "📈 Cache usage comparison:"
echo "   Old workflow: $old_caches cache actions"
echo "   New workflow: $new_caches cache actions"

if [[ $new_caches -gt 0 ]]; then
    echo "✅ Caching strategy implemented"
else
    echo "❌ No caching found in new workflow"
    exit 1
fi

echo ""
echo "🎯 Performance improvements to expect:"
echo "   - Unified build job eliminates redundant compilation"
echo "   - Shared cache keys improve cache hit rates"
echo "   - Pre-built CLI binary reduces appwrite job time"
echo "   - Composite action reduces workflow duplication"

echo ""
echo "✅ Validation complete - optimized CI workflow is properly configured!"
echo ""
echo "🚀 Ready to deploy optimized CI workflow"
echo "   Run: ./scripts/ci-migration.sh"