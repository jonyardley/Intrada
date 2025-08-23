#!/bin/bash

# Database Cleanup Script for Intrada
# This script cleans all data from the database while preserving table structure

set -e

echo "🧹 Intrada Database Cleanup"
echo "=========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the server directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${RED}❌ Error: This script must be run from the server directory${NC}"
    echo "Please run: cd server && ./cleanup-db.sh"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Check if PostgreSQL container is running
if ! docker-compose ps | grep -q "postgres.*Up"; then
    echo -e "${YELLOW}⚠️  PostgreSQL container is not running${NC}"
    echo -e "${BLUE}🔄 Starting PostgreSQL container...${NC}"
    docker-compose up -d postgres
    echo -e "${BLUE}⏳ Waiting for database to be ready...${NC}"
    sleep 5
fi

echo -e "${YELLOW}⚠️  WARNING: This will delete ALL data from the database!${NC}"
echo "The following tables will be cleared:"
echo "  - sessions (all practice sessions)"
echo "  - goals (all practice goals)"
echo "  - studies (all studies)"
echo ""

# Prompt for confirmation unless --force flag is provided
if [[ "$1" != "--force" ]]; then
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🚫 Database cleanup cancelled${NC}"
        exit 0
    fi
fi

echo -e "${BLUE}🔄 Cleaning up database...${NC}"

# Execute cleanup commands
echo -e "${BLUE}📊 Checking current data counts...${NC}"
docker-compose exec -T postgres psql -U intrada -d intrada -c "
SELECT 
    'sessions' as table_name, COUNT(*) as count FROM sessions
UNION ALL
SELECT 
    'goals' as table_name, COUNT(*) as count FROM goals  
UNION ALL
SELECT 
    'studies' as table_name, COUNT(*) as count FROM studies
ORDER BY table_name;
"

echo -e "${BLUE}🗑️  Deleting all data...${NC}"
docker-compose exec -T postgres psql -U intrada -d intrada -c "
-- Delete all sessions
DELETE FROM sessions;

-- Delete all goals  
DELETE FROM goals;

-- Delete all studies
DELETE FROM studies;

-- Reset sequences (if any auto-increment IDs exist)
-- Note: Our tables use UUIDs, so no sequences to reset

SELECT 'Database cleanup completed successfully!' as result;
"

echo -e "${BLUE}📊 Verifying cleanup...${NC}"
docker-compose exec -T postgres psql -U intrada -d intrada -c "
SELECT 
    'sessions' as table_name, COUNT(*) as count FROM sessions
UNION ALL
SELECT 
    'goals' as table_name, COUNT(*) as count FROM goals  
UNION ALL
SELECT 
    'studies' as table_name, COUNT(*) as count FROM studies
ORDER BY table_name;
"

echo ""
echo -e "${GREEN}✅ Database cleanup completed successfully!${NC}"
echo -e "${BLUE}📋 Summary:${NC}"
echo "  - All sessions deleted"
echo "  - All goals deleted" 
echo "  - All studies deleted"
echo "  - Table structure preserved"
echo ""
echo -e "${YELLOW}💡 Note: You may want to restart your server to clear any cached data${NC}"
echo -e "${BLUE}🔄 To restart server: pkill -f intrada-server && ./build-and-run.sh${NC}"
