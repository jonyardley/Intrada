#!/bin/bash
# Helper script to manually run the same checks as the pre-commit hook
# Usage: ./scripts/check-code.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running code quality checks...${NC}"

# Function to run cargo fmt check
run_fmt_check() {
    echo -e "${YELLOW}Checking code formatting with cargo fmt...${NC}"
    
    if ! cargo fmt --all --check; then
        echo -e "${RED}❌ Code formatting check failed!${NC}"
        echo -e "${RED}Run 'cargo fmt --all' to fix formatting issues.${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Code formatting check passed${NC}"
        return 0
    fi
}

# Function to run clippy check
run_clippy_check() {
    echo -e "${YELLOW}Running clippy lints...${NC}"
    
    if ! cargo clippy --all-targets --all-features -- -D warnings; then
        echo -e "${RED}❌ Clippy check failed!${NC}"
        echo -e "${RED}Please fix the clippy warnings above.${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Clippy check passed${NC}"
        return 0
    fi
}

# Function to run tests
run_tests() {
    echo -e "${YELLOW}Running tests...${NC}"
    
    if ! cargo test --all; then
        echo -e "${RED}❌ Tests failed!${NC}"
        return 1
    else
        echo -e "${GREEN}✅ All tests passed${NC}"
        return 0
    fi
}

# Main execution
main() {
    if [ ! -f "Cargo.toml" ]; then
        echo -e "${RED}❌ No Cargo.toml found. Please run this script from the project root.${NC}"
        exit 1
    fi
    
    fmt_result=0
    clippy_result=0
    test_result=0
    
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
    
    # Run tests
    if ! run_tests; then
        test_result=1
    fi
    
    echo ""
    
    # Summary
    if [ $fmt_result -eq 0 ] && [ $clippy_result -eq 0 ] && [ $test_result -eq 0 ]; then
        echo -e "${GREEN}✅ All checks passed! Your code is ready to commit.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some checks failed. Please fix the issues above.${NC}"
        echo ""
        echo "Quick fixes:"
        if [ $fmt_result -eq 1 ]; then
            echo "  - Run: cargo fmt --all"
        fi
        if [ $clippy_result -eq 1 ]; then
            echo "  - Fix clippy warnings shown above"
        fi
        if [ $test_result -eq 1 ]; then
            echo "  - Fix failing tests"
        fi
        exit 1
    fi
}

# Run main function
main "$@" 