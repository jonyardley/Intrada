#!/bin/bash

# Database Reset Script for Intrada
# This script cleans the database and adds fresh sample data

set -e

echo "🔄 Intrada Database Reset"
echo "========================"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the server directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${RED}❌ Error: This script must be run from the server directory${NC}"
    echo "Please run: cd server && ./reset-db.sh"
    exit 1
fi

echo -e "${BLUE}🧹 Step 1: Cleaning database...${NC}"
./cleanup-db.sh --force

echo ""
echo -e "${BLUE}🌱 Step 2: Adding sample data...${NC}"
./seed-db.sh

echo ""
echo -e "${GREEN}✅ Database reset complete!${NC}"
echo -e "${BLUE}📋 Your database now has fresh sample data and is ready for testing.${NC}"
