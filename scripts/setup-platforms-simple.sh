#!/bin/bash

# Simple Platform Setup Script for Appwrite
# This script tries multiple methods to register platforms

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APPWRITE_PROJECT_ID="intrada-dev"
APPWRITE_ENDPOINT="http://localhost/v1"

echo -e "${BLUE}📱 Simple Platform Registration${NC}"
echo -e "${BLUE}==============================${NC}"

# Load environment variables
if [ -f ".env.local" ]; then
    source .env.local
fi

# Function to try registering platform via direct API call
try_direct_api() {
    local platform_type=$1
    local platform_name=$2
    local platform_key=$3
    local platform_hostname=$4
    
    echo -e "${YELLOW}🔧 Trying direct API: $platform_name${NC}"
    
    # Prepare JSON payload
    local json_payload='{"type":"'$platform_type'","name":"'$platform_name'"'
    if [ -n "$platform_key" ]; then
        json_payload=$json_payload',"key":"'$platform_key'"'
    fi
    if [ -n "$platform_hostname" ]; then
        json_payload=$json_payload',"hostname":"'$platform_hostname'"'
    fi
    json_payload=$json_payload'}'
    
    # Try with existing API key (if available)
    if [ -n "$APPWRITE_API_KEY" ]; then
        local response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST \
            "$APPWRITE_ENDPOINT/projects/$APPWRITE_PROJECT_ID/platforms" \
            -H "X-Appwrite-Project: $APPWRITE_PROJECT_ID" \
            -H "X-Appwrite-Key: $APPWRITE_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$json_payload" 2>/dev/null)
        
        local body=$(echo "$response" | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
        local status=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | grep -o "[0-9]*")
        
        if [ "$status" -eq 201 ] || [ "$status" -eq 200 ]; then
            echo -e "${GREEN}✅ Platform created successfully${NC}"
            return 0
        elif [ "$status" -eq 409 ]; then
            echo -e "${GREEN}✅ Platform already exists${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  API key method failed (HTTP $status)${NC}"
        fi
    fi
    
    # Try with console project
    local console_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST \
        "$APPWRITE_ENDPOINT/projects/$APPWRITE_PROJECT_ID/platforms" \
        -H "X-Appwrite-Project: console" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>/dev/null)
    
    local console_body=$(echo "$console_response" | sed -E 's/HTTPSTATUS\:[0-9]{3}$//')
    local console_status=$(echo "$console_response" | grep -o "HTTPSTATUS:[0-9]*" | grep -o "[0-9]*")
    
    if [ "$console_status" -eq 201 ] || [ "$console_status" -eq 200 ]; then
        echo -e "${GREEN}✅ Platform created via console${NC}"
        return 0
    elif [ "$console_status" -eq 409 ]; then
        echo -e "${GREEN}✅ Platform already exists${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Console method failed (HTTP $console_status)${NC}"
        return 1
    fi
}

# Function to check if platform already exists
check_platform_exists() {
    local platform_key=$1
    
    if [ -n "$APPWRITE_API_KEY" ]; then
        local response=$(curl -s \
            "$APPWRITE_ENDPOINT/projects/$APPWRITE_PROJECT_ID/platforms" \
            -H "X-Appwrite-Project: $APPWRITE_PROJECT_ID" \
            -H "X-Appwrite-Key: $APPWRITE_API_KEY" 2>/dev/null)
        
        if echo "$response" | grep -q "$platform_key"; then
            return 0
        fi
    fi
    return 1
}

# Main execution
echo -e "${YELLOW}📋 Step 1: Checking if platforms already exist...${NC}"

# Check iOS platform
if check_platform_exists "com.jonyardley.Intrada"; then
    echo -e "${GREEN}✅ iOS platform already exists${NC}"
    IOS_EXISTS=true
else
    IOS_EXISTS=false
fi

# Check Web platform
if check_platform_exists "localhost"; then
    echo -e "${GREEN}✅ Web platform already exists${NC}"
    WEB_EXISTS=true
else
    WEB_EXISTS=false
fi

# Create iOS platform if needed
if [ "$IOS_EXISTS" = false ]; then
    echo -e "${YELLOW}📋 Step 2: Creating iOS platform...${NC}"
    if try_direct_api "apple-ios" "iOS App" "com.jonyardley.Intrada" ""; then
        echo -e "${GREEN}✅ iOS platform registration completed${NC}"
    else
        echo -e "${RED}❌ iOS platform registration failed${NC}"
        IOS_FAILED=true
    fi
else
    echo -e "${YELLOW}📋 Step 2: iOS platform already exists, skipping...${NC}"
fi

# Create Web platform if needed
if [ "$WEB_EXISTS" = false ]; then
    echo -e "${YELLOW}📋 Step 3: Creating Web platform...${NC}"
    if try_direct_api "web" "Web App" "" "localhost"; then
        echo -e "${GREEN}✅ Web platform registration completed${NC}"
    else
        echo -e "${RED}❌ Web platform registration failed${NC}"
        WEB_FAILED=true
    fi
else
    echo -e "${YELLOW}📋 Step 3: Web platform already exists, skipping...${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}📋 Platform Registration Summary:${NC}"
if [ "$IOS_EXISTS" = true ] || [ "$IOS_FAILED" != true ]; then
    echo -e "  📱 iOS App (com.jonyardley.Intrada): ${GREEN}✅ READY${NC}"
else
    echo -e "  📱 iOS App (com.jonyardley.Intrada): ${RED}❌ FAILED${NC}"
fi

if [ "$WEB_EXISTS" = true ] || [ "$WEB_FAILED" != true ]; then
    echo -e "  🌐 Web App (localhost): ${GREEN}✅ READY${NC}"
else
    echo -e "  🌐 Web App (localhost): ${RED}❌ FAILED${NC}"
fi

if [ "$IOS_FAILED" = true ] || [ "$WEB_FAILED" = true ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Some platforms failed to register automatically.${NC}"
    echo -e "${BLUE}💡 Next steps:${NC}"
    echo -e "  1. Try running: ${YELLOW}./scripts/setup-platforms-docker.sh${NC}"
    echo -e "  2. Or manually add platforms in the Appwrite console:"
    echo -e "     - Go to: ${YELLOW}http://localhost/console${NC}"
    echo -e "     - Select your project: ${YELLOW}Intrada Dev${NC}"
    echo -e "     - Look for 'Platforms' in settings"
    echo -e "     - Add iOS platform with bundle ID: ${YELLOW}com.jonyardley.Intrada${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}🎉 All platforms are ready!${NC}"
    echo -e "${BLUE}🔧 Your iOS app should now work without the 'Invalid Origin' error${NC}"
fi 
