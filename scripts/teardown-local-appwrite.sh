#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Tearing down local Appwrite environment...${NC}"

# Stop and remove all containers
echo -e "${YELLOW}📦 Stopping and removing containers...${NC}"
docker compose down -v

# Remove all appwrite volumes
echo -e "${YELLOW}🗑️  Removing volumes...${NC}"
docker volume rm $(docker volume ls -q | grep appwrite) 2>/dev/null || echo "No appwrite volumes found"

# Remove all appwrite networks
echo -e "${YELLOW}🌐 Removing networks...${NC}"
docker network rm $(docker network ls -q | grep appwrite) 2>/dev/null || echo "No appwrite networks found"

# Remove any dangling images
echo -e "${YELLOW}🖼️  Cleaning up images...${NC}"
docker image prune -f

# Remove local environment files
echo -e "${YELLOW}📝 Removing local environment files...${NC}"
rm -f .env.local
rm -f iOS/Intrada/Config.plist

# Reset CLI configuration
echo -e "${YELLOW}🔧 Resetting CLI configuration...${NC}"
rm -rf ~/.appwrite

echo -e "${GREEN}✅ Local Appwrite environment completely torn down!${NC}"
echo ""
echo -e "${BLUE}To start fresh, run:${NC}"
echo -e "  ${YELLOW}./scripts/setup-local-appwrite.sh${NC}" 