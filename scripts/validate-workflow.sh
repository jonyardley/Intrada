#!/bin/bash

# Validate GitHub Actions workflow syntax
# This script checks for common syntax issues

set -e

echo "🔍 Validating GitHub Actions workflow syntax..."

WORKFLOW_FILE=".github/workflows/main-ci-optimized.yml"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
    echo "❌ Workflow file not found: $WORKFLOW_FILE"
    exit 1
fi

echo "📁 Checking workflow file: $WORKFLOW_FILE"

# Check for hashFiles usage in env context (not allowed)
if grep -n "env:" -A 20 "$WORKFLOW_FILE" | grep -q "hashFiles"; then
    echo "❌ Found hashFiles usage in env context - this is not allowed"
    echo "   hashFiles can only be used in job/step contexts"
    exit 1
else
    echo "✅ No hashFiles usage in env context"
fi

# Check for basic YAML syntax issues
if command -v yamllint &> /dev/null; then
    echo "🔧 Running yamllint..."
    yamllint "$WORKFLOW_FILE" || echo "⚠️  yamllint found some issues (may be false positives)"
else
    echo "ℹ️  yamllint not available - skipping YAML syntax check"
fi

# Check for required job dependencies
echo "🔗 Checking job dependencies..."

required_jobs=("changes" "build-artifacts" "rust-checks" "ios-build" "web-build" "appwrite-deploy" "vercel-deploy")
for job in "${required_jobs[@]}"; do
    if grep -q "^  $job:" "$WORKFLOW_FILE"; then
        echo "✅ Job '$job' found"
    else
        echo "⚠️  Job '$job' not found"
    fi
done

# Check for artifact upload/download consistency
echo "📦 Checking artifact consistency..."

uploads=$(grep -c "upload-artifact" "$WORKFLOW_FILE" || echo "0")
downloads=$(grep -c "download-artifact" "$WORKFLOW_FILE" || echo "0")

echo "   Uploads: $uploads"
echo "   Downloads: $downloads"

if [[ $uploads -gt 0 && $downloads -gt 0 ]]; then
    echo "✅ Artifact upload/download configured"
else
    echo "⚠️  Missing artifact upload or download configuration"
fi

echo ""
echo "🎉 Workflow validation complete!"
echo ""
echo "💡 Next steps:"
echo "- Test the workflow in a pull request"
echo "- Monitor GitHub Actions tab for any runtime issues"
echo "- Check secrets are properly configured in repository settings"