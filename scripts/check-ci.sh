#!/bin/bash
# Run the same checks as CI/CD locally
# This helps catch issues before they reach the CI/CD pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running CI/CD equivalent checks locally...${NC}"

# Function to run cargo fmt check (same as CI/CD)
run_fmt_check() {
    echo -e "${YELLOW}🔍 Checking code formatting (cargo fmt --all -- --check)${NC}"
    
    if cargo fmt --all -- --check; then
        echo -e "${GREEN}✅ Formatting check passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Formatting check failed${NC}"
        echo -e "${RED}Fix with: cargo fmt --all${NC}"
        return 1
    fi
}

# Function to run clippy check (same as CI/CD)
run_clippy_check() {
    echo -e "${YELLOW}🔍 Running clippy (cargo clippy --all-targets --all-features -- -D warnings -D clippy::uninlined-format-args)${NC}"
    
    if cargo clippy --all-targets --all-features -- -D warnings -D clippy::uninlined-format-args; then
        echo -e "${GREEN}✅ Clippy check passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Clippy check failed${NC}"
        echo -e "${RED}These are the same errors that would appear in CI/CD${NC}"
        return 1
    fi
}

# Function to run cargo build (same as CI/CD)
run_build_check() {
    echo -e "${YELLOW}🔍 Building workspace (cargo build --release --workspace)${NC}"
    
    if cargo build --release --workspace; then
        echo -e "${GREEN}✅ Build check passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Build check failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    fmt_result=0
    clippy_result=0
    build_result=0
    
    echo "This script runs the same checks as the CI/CD pipeline:"
    echo "1. Code formatting with cargo fmt"
    echo "2. Linting with cargo clippy (strict mode)"
    echo "3. Building the workspace"
    echo ""
    
    # Run formatting check
    if ! run_fmt_check; then
        fmt_result=1
    fi
    echo ""
    
    # Run clippy check
    if ! run_clippy_check; then
        clippy_result=1
    fi
    echo ""
    
    # Run build check
    if ! run_build_check; then
        build_result=1
    fi
    echo ""
    
    # Summary
    if [ $fmt_result -eq 0 ] && [ $clippy_result -eq 0 ] && [ $build_result -eq 0 ]; then
        echo -e "${GREEN}🎉 All CI/CD equivalent checks passed! Your code should pass the pipeline.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some checks failed. Fix these issues before pushing to avoid CI/CD failures:${NC}"
        echo ""
        if [ $fmt_result -eq 1 ]; then
            echo -e "${RED}  • Formatting issues: Run 'cargo fmt --all'${NC}"
        fi
        if [ $clippy_result -eq 1 ]; then
            echo -e "${RED}  • Clippy warnings: Fix the warnings shown above${NC}"
            echo -e "${RED}    - For format strings: Use format!(\"text: {variable}\") instead of format!(\"text: {}\", variable)${NC}"
        fi
        if [ $build_result -eq 1 ]; then
            echo -e "${RED}  • Build errors: Fix compilation issues${NC}"
        fi
        exit 1
    fi
}

# Run main function
main "$@" 