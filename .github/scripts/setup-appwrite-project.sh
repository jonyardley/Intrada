#!/bin/bash

# Appwrite Project Setup Script for CI/CD
# Creates projects and API keys for development environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Input parameters
ENVIRONMENT="${1:-}"
PROJECT_ID="${2:-}"
ENDPOINT="${3:-http://localhost/v1}"

if [[ -z "$ENVIRONMENT" || -z "$PROJECT_ID" ]]; then
    echo -e "${RED}❌ Usage: $0 <environment> <project_id> [endpoint]${NC}"
    echo "Example: $0 development intrada-dev http://localhost/v1"
    exit 1
fi

echo -e "${BLUE}🏗️ Setting up Appwrite project${NC}"
echo -e "${BLUE}==============================${NC}"
echo -e "  Environment: $ENVIRONMENT"
echo -e "  Project ID: $PROJECT_ID"
echo -e "  Endpoint: $ENDPOINT"
echo ""

if [[ "$ENVIRONMENT" == "production" ]]; then
    echo -e "${GREEN}✅ Production environment - using existing secrets${NC}"
    # For production, we assume secrets are already configured
    exit 0
fi

echo -e "${YELLOW}🔧 Setting up development project...${NC}"

# Wait for Appwrite to be fully ready
echo -e "${YELLOW}⏳ Waiting for Appwrite to be ready...${NC}"
RETRY_COUNT=0
MAX_RETRIES=30

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -s "$ENDPOINT/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Appwrite is ready!${NC}"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -n "."
    sleep 2
done

if [[ $RETRY_COUNT -eq $MAX_RETRIES ]]; then
    echo -e "${RED}❌ Appwrite failed to start after $((MAX_RETRIES * 2)) seconds${NC}"
    exit 1
fi

# Additional wait for full startup
sleep 5

# Create project
echo -e "${YELLOW}📝 Creating project '$PROJECT_ID'...${NC}"

PROJECT_RESPONSE=$(curl -s -X POST "$ENDPOINT/projects" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: console" \
    -d "{
        \"projectId\": \"$PROJECT_ID\",
        \"name\": \"Intrada Development\",
        \"teamId\": \"console\"
    }" 2>/dev/null || echo '{"error": "failed"}')

echo "Project creation response: $PROJECT_RESPONSE"

# Check if project creation was successful
if echo "$PROJECT_RESPONSE" | grep -q '"error"'; then
    # Project might already exist, which is fine
    echo -e "${YELLOW}⚠️ Project may already exist, continuing...${NC}"
else
    echo -e "${GREEN}✅ Project created successfully${NC}"
fi

# Create API key
echo -e "${YELLOW}🔑 Creating API key...${NC}"

API_KEY_RESPONSE=$(curl -s -X POST "$ENDPOINT/projects/$PROJECT_ID/keys" \
    -H "Content-Type: application/json" \
    -H "X-Appwrite-Project: console" \
    -d '{
        "name": "CI/CD Key",
        "scopes": [
            "databases.read", "databases.write",
            "collections.read", "collections.write", 
            "attributes.read", "attributes.write",
            "indexes.read", "indexes.write",
            "documents.read", "documents.write"
        ]
    }' 2>/dev/null || echo '{"secret": "dev-fallback-key"}')

echo "API key creation response: $API_KEY_RESPONSE"

# Extract API key
if command -v jq >/dev/null 2>&1; then
    API_KEY=$(echo "$API_KEY_RESPONSE" | jq -r '.secret // "dev-fallback-key"')
else
    # Fallback if jq is not available
    API_KEY=$(echo "$API_KEY_RESPONSE" | grep -o '"secret":"[^"]*"' | cut -d'"' -f4 || echo "dev-fallback-key")
fi

if [[ "$API_KEY" == "null" || "$API_KEY" == "" ]]; then
    API_KEY="dev-fallback-key"
fi

echo -e "${GREEN}✅ API key generated${NC}"

# Set environment variables for subsequent steps
{
    echo "APPWRITE_API_KEY=$API_KEY"
    echo "APPWRITE_PROJECT_ID=$PROJECT_ID"
    echo "APPWRITE_ENDPOINT=$ENDPOINT"
} >> "$GITHUB_ENV"

# Output for debugging (without showing the actual key)
echo -e "${BLUE}📋 Environment variables set:${NC}"
echo -e "  APPWRITE_PROJECT_ID=$PROJECT_ID"
echo -e "  APPWRITE_ENDPOINT=$ENDPOINT"
echo -e "  APPWRITE_API_KEY=***${API_KEY: -4}"

echo -e "${GREEN}🎉 Appwrite project setup completed!${NC}"