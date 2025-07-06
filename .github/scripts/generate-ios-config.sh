#!/bin/bash

# iOS Configuration Generator for CI/CD
# Creates iOS Config.plist based on environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Input parameters
ENVIRONMENT="${1:-}"
ENDPOINT="${2:-}"
PROJECT_ID="${3:-}"
OUTPUT_PATH="${4:-iOS/Intrada/Config.plist}"

if [[ -z "$ENVIRONMENT" || -z "$ENDPOINT" || -z "$PROJECT_ID" ]]; then
    echo -e "${RED}❌ Usage: $0 <environment> <endpoint> <project_id> [output_path]${NC}"
    echo "Example: $0 production https://cloud.appwrite.io/v1 intrada-prod"
    exit 1
fi

echo -e "${BLUE}📱 Generating iOS configuration${NC}"
echo -e "${BLUE}===============================${NC}"
echo -e "  Environment: $ENVIRONMENT"
echo -e "  Endpoint: $ENDPOINT"
echo -e "  Project ID: $PROJECT_ID"
echo -e "  Output: $OUTPUT_PATH"
echo ""

# Ensure the directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
mkdir -p "$OUTPUT_DIR"

# Generate Config.plist
echo -e "${YELLOW}📝 Creating Config.plist...${NC}"

cat > "$OUTPUT_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AppwriteEndpoint</key>
    <string>$ENDPOINT</string>
    <key>AppwriteProjectId</key>
    <string>$PROJECT_ID</string>
    <key>AppwriteDatabaseId</key>
    <string>intrada_db</string>
    <key>Environment</key>
    <string>$ENVIRONMENT</string>
</dict>
</plist>
EOF

echo -e "${GREEN}✅ Config.plist created successfully${NC}"

# Validate the plist file
if command -v plutil >/dev/null 2>&1; then
    if plutil -lint "$OUTPUT_PATH" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Config.plist validation passed${NC}"
    else
        echo -e "${RED}❌ Config.plist validation failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️ plutil not available, skipping validation${NC}"
fi

# Show the generated configuration (for debugging)
echo -e "${BLUE}📋 Generated configuration:${NC}"
cat "$OUTPUT_PATH"

echo -e "${GREEN}🎉 iOS configuration generated successfully!${NC}"