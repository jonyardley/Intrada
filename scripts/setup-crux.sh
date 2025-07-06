#!/bin/bash

# Crux Dependency Setup Script
# Handles local and CI/CD environments for Crux dependency

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CRUX_REPO="${CRUX_REPO:-redbadger/crux}"
CRUX_REF="${CRUX_REF:-main}"
CRUX_PATH="${CRUX_PATH:-../crux}"
CI_MODE="${CI:-false}"

echo -e "${BLUE}🦀 Setting up Crux dependency${NC}"
echo -e "${BLUE}================================${NC}"

# Function to check if Crux is already available
check_crux_available() {
    if [[ -d "$CRUX_PATH" && -f "$CRUX_PATH/Cargo.toml" ]]; then
        echo -e "${GREEN}✅ Crux found at $CRUX_PATH${NC}"
        
        # Verify it's a valid Crux repo
        if grep -q "name.*crux" "$CRUX_PATH/Cargo.toml" 2>/dev/null; then
            echo -e "${GREEN}✅ Valid Crux repository detected${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Directory exists but doesn't appear to be Crux${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}❌ Crux not found at $CRUX_PATH${NC}"
        return 1
    fi
}

# Function to clone Crux from Git
clone_crux() {
    echo -e "${YELLOW}📥 Cloning Crux from $CRUX_REPO (ref: $CRUX_REF)...${NC}"
    
    # Remove existing directory if it exists but is invalid
    if [[ -d "$CRUX_PATH" ]]; then
        echo -e "${YELLOW}🗑️  Removing existing invalid Crux directory...${NC}"
        rm -rf "$CRUX_PATH"
    fi
    
    # Clone the repository
    git clone "https://github.com/$CRUX_REPO.git" "$CRUX_PATH"
    
    # Checkout specific ref if not main
    if [[ "$CRUX_REF" != "main" ]]; then
        echo -e "${YELLOW}🔄 Checking out ref: $CRUX_REF${NC}"
        cd "$CRUX_PATH"
        git checkout "$CRUX_REF"
        cd - > /dev/null
    fi
    
    echo -e "${GREEN}✅ Crux cloned successfully${NC}"
}

# Function to verify Crux setup
verify_crux() {
    echo -e "${YELLOW}🔍 Verifying Crux setup...${NC}"
    
    # Check main workspace
    if [[ ! -f "$CRUX_PATH/Cargo.toml" ]]; then
        echo -e "${RED}❌ Crux workspace Cargo.toml not found${NC}"
        return 1
    fi
    
    # Check core crate
    if [[ ! -f "$CRUX_PATH/crux_core/Cargo.toml" ]]; then
        echo -e "${RED}❌ crux_core crate not found${NC}"
        return 1
    fi
    
    # Check http crate (used by your project)
    if [[ ! -f "$CRUX_PATH/crux_http/Cargo.toml" ]]; then
        echo -e "${RED}❌ crux_http crate not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Crux verification passed${NC}"
    
    # Show Crux version info
    echo -e "${BLUE}📋 Crux Information:${NC}"
    echo -e "  Path: $CRUX_PATH"
    
    # Try to get version from Cargo.toml
    if command -v grep &> /dev/null && command -v cut &> /dev/null; then
        CRUX_VERSION=$(grep '^version' "$CRUX_PATH/crux_core/Cargo.toml" | cut -d'"' -f2 2>/dev/null || echo "unknown")
        echo -e "  Version: $CRUX_VERSION"
    fi
    
    # Show git info if available
    if [[ -d "$CRUX_PATH/.git" ]]; then
        cd "$CRUX_PATH"
        GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        echo -e "  Git commit: $GIT_COMMIT"
        echo -e "  Git branch: $GIT_BRANCH"
        cd - > /dev/null
    fi
}

# Function to handle CI environment
setup_ci() {
    echo -e "${BLUE}🤖 CI/CD environment detected${NC}"
    
    # In CI, always clone fresh to ensure consistency
    clone_crux
    verify_crux
}

# Function to handle local development
setup_local() {
    echo -e "${BLUE}💻 Local development environment detected${NC}"
    
    # Check if Crux is already available locally
    if check_crux_available; then
        echo -e "${GREEN}✅ Using existing local Crux${NC}"
        verify_crux
    else
        echo -e "${YELLOW}❌ Local Crux not found, cloning...${NC}"
        clone_crux
        verify_crux
        
        echo -e "${BLUE}💡 Development Tip:${NC}"
        echo -e "  To use a local Crux development version:"
        echo -e "  1. Clone Crux manually: git clone https://github.com/redbadger/crux.git ../crux"
        echo -e "  2. Make your changes in ../crux"
        echo -e "  3. Your Cargo.toml path dependencies will use your local version"
    fi
}

# Main execution
echo -e "${YELLOW}🚀 Starting Crux setup...${NC}"

# Show environment info
echo -e "${BLUE}📋 Environment:${NC}"
echo -e "  CI: $CI_MODE"
echo -e "  Repository: $CRUX_REPO"
echo -e "  Reference: $CRUX_REF"
echo -e "  Target Path: $CRUX_PATH"
echo ""

# Determine setup method
if [[ "$CI_MODE" == "true" ]]; then
    setup_ci
else
    setup_local
fi

echo ""
echo -e "${GREEN}🎉 Crux setup completed successfully!${NC}"
echo -e "${BLUE}Your project can now build with the configured Crux dependency.${NC}"