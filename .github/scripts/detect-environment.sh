#!/bin/bash

# Environment Detection Script for GitHub Actions
# Determines deployment environment based on branch and event type

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Input parameters
GITHUB_REF="${1:-}"
GITHUB_EVENT_NAME="${2:-}"
GITHUB_REF_NAME="${3:-}"
MANUAL_ENVIRONMENT="${4:-}"

if [[ -z "$GITHUB_REF" || -z "$GITHUB_EVENT_NAME" || -z "$GITHUB_REF_NAME" ]]; then
    echo -e "${RED}❌ Usage: $0 <github_ref> <github_event_name> <github_ref_name> [manual_environment]${NC}"
    echo "Example: $0 refs/heads/main push main"
    exit 1
fi

echo -e "${BLUE}🌍 Environment Detection${NC}"
echo -e "${BLUE}========================${NC}"

# Determine environment
if [[ "$GITHUB_REF" == "refs/heads/main" ]]; then
    ENVIRONMENT="production"
    PROJECT_ID_VAR="APPWRITE_PROJECT_ID_PROD"
    ENDPOINT_VAR="APPWRITE_ENDPOINT_PROD"
    API_KEY_VAR="APPWRITE_API_KEY_PROD"
    BUNDLE_ID="com.jonyardley.Intrada"
    HOSTNAME="intrada.app"
    CONFIG_SUFFIX="prod"
else
    ENVIRONMENT="development"
    PROJECT_ID_VAR="APPWRITE_PROJECT_ID_DEV"
    ENDPOINT_VAR="APPWRITE_ENDPOINT_DEV"
    API_KEY_VAR="APPWRITE_API_KEY_DEV"
    BUNDLE_ID="com.jonyardley.Intrada.dev"
    HOSTNAME="localhost"
    CONFIG_SUFFIX="dev"
fi

# Manual override from workflow_dispatch
if [[ -n "$MANUAL_ENVIRONMENT" ]]; then
    echo -e "${YELLOW}🔄 Manual environment override: $MANUAL_ENVIRONMENT${NC}"
    ENVIRONMENT="$MANUAL_ENVIRONMENT"
    
    if [[ "$MANUAL_ENVIRONMENT" == "production" ]]; then
        PROJECT_ID_VAR="APPWRITE_PROJECT_ID_PROD"
        ENDPOINT_VAR="APPWRITE_ENDPOINT_PROD"
        API_KEY_VAR="APPWRITE_API_KEY_PROD"
        BUNDLE_ID="com.jonyardley.Intrada"
        HOSTNAME="intrada.app"
        CONFIG_SUFFIX="prod"
    else
        PROJECT_ID_VAR="APPWRITE_PROJECT_ID_DEV"
        ENDPOINT_VAR="APPWRITE_ENDPOINT_DEV"
        API_KEY_VAR="APPWRITE_API_KEY_DEV"
        BUNDLE_ID="com.jonyardley.Intrada.dev"
        HOSTNAME="localhost"
        CONFIG_SUFFIX="dev"
    fi
fi

# Determine if this should actually deploy
if [[ "$GITHUB_EVENT_NAME" == "push" ]]; then
    DEPLOY_REAL="true"
    DEPLOY_ACTION="DEPLOY"
else
    DEPLOY_REAL="false"
    DEPLOY_ACTION="DRY-RUN"
fi

# Output environment information
echo -e "${GREEN}📋 Environment Configuration:${NC}"
echo -e "  Environment: ${ENVIRONMENT}"
echo -e "  Branch: ${GITHUB_REF_NAME}"
echo -e "  Event: ${GITHUB_EVENT_NAME}"
echo -e "  Action: ${DEPLOY_ACTION}"
echo -e "  Bundle ID: ${BUNDLE_ID}"
echo -e "  Hostname: ${HOSTNAME}"
echo ""

# Set GitHub environment variables for subsequent steps
{
    echo "environment=${ENVIRONMENT}"
    echo "project_id_var=${PROJECT_ID_VAR}"
    echo "endpoint_var=${ENDPOINT_VAR}"
    echo "api_key_var=${API_KEY_VAR}"
    echo "bundle_id=${BUNDLE_ID}"
    echo "hostname=${HOSTNAME}"
    echo "config_suffix=${CONFIG_SUFFIX}"
    echo "deploy_real=${DEPLOY_REAL}"
    echo "deploy_action=${DEPLOY_ACTION}"
} >> "$GITHUB_OUTPUT"

# Output status for workflow summary
echo -e "${BLUE}🌍 Environment: $(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')${NC}"
echo -e "${BLUE}📋 Branch: ${GITHUB_REF_NAME}${NC}"
echo -e "${BLUE}🚀 Will ${DEPLOY_ACTION}: $([ "$DEPLOY_REAL" == "true" ] && echo "YES" || echo "NO")${NC}"