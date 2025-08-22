#!/bin/bash

# Database Seed Script for Intrada
# This script adds sample test data to the database

set -e

echo "🌱 Intrada Database Seed"
echo "======================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the server directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${RED}❌ Error: This script must be run from the server directory${NC}"
    echo "Please run: cd server && ./seed-db.sh"
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

echo -e "${BLUE}🌱 Adding sample data to database...${NC}"

# Check if server is running to use API, otherwise insert directly
if curl -s http://localhost:3000/api/goals > /dev/null 2>&1; then
    echo -e "${BLUE}📡 Server is running, using API endpoints...${NC}"
    
    # Create sample studies via API
    echo -e "${BLUE}📚 Creating sample studies...${NC}"
    STUDY1_ID=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"name": "Chopin Etude Op. 10 No. 1", "description": "Technical study focusing on arpeggios and finger independence"}' \
        http://localhost:3000/api/studies | jq -r '.id')
    
    STUDY2_ID=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"name": "Bach Invention No. 1", "description": "Counterpoint and two-voice independence"}' \
        http://localhost:3000/api/studies | jq -r '.id')
    
    STUDY3_ID=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"name": "Scales - C Major", "description": "Basic major scale practice, all octaves"}' \
        http://localhost:3000/api/studies | jq -r '.id')
    
    # Create sample goals via API
    echo -e "${BLUE}🎯 Creating sample goals...${NC}"
    GOAL1_ID=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"name\": \"Master Technical Studies\", \"description\": \"Improve finger technique and dexterity\", \"target_date\": \"$(date -v+3m +%Y-%m-%d)\", \"study_ids\": [\"$STUDY1_ID\", \"$STUDY3_ID\"]}" \
        http://localhost:3000/api/goals | jq -r '.id')
    
    GOAL2_ID=$(curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"name\": \"Bach Counterpoint\", \"description\": \"Develop two-voice independence\", \"target_date\": \"$(date -v+2m +%Y-%m-%d)\", \"study_ids\": [\"$STUDY2_ID\"]}" \
        http://localhost:3000/api/goals | jq -r '.id')
    
    # Create sample sessions via API
    echo -e "${BLUE}🎵 Creating sample sessions...${NC}"
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"goal_ids\": [\"$GOAL1_ID\"], \"intention\": \"Focus on slow practice and accuracy\"}" \
        http://localhost:3000/api/sessions > /dev/null
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"goal_ids\": [\"$GOAL2_ID\"], \"intention\": \"Work on hand independence\"}" \
        http://localhost:3000/api/sessions > /dev/null
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"goal_ids\": [\"$GOAL1_ID\", \"$GOAL2_ID\"], \"intention\": \"Combined technical and musical practice\"}" \
        http://localhost:3000/api/sessions > /dev/null
    
else
    echo -e "${BLUE}💾 Server not running, inserting data directly...${NC}"
    
    # Insert sample data directly into database
    docker-compose exec -T postgres psql -U intrada -d intrada -c "
    -- Insert sample studies
    INSERT INTO studies (id, name, description) VALUES 
    ('$(uuidgen | tr '[:upper:]' '[:lower:]')', 'Chopin Etude Op. 10 No. 1', 'Technical study focusing on arpeggios and finger independence'),
    ('$(uuidgen | tr '[:upper:]' '[:lower:]')', 'Bach Invention No. 1', 'Counterpoint and two-voice independence'),
    ('$(uuidgen | tr '[:upper:]' '[:lower:]')', 'Scales - C Major', 'Basic major scale practice, all octaves');

    -- Insert sample goals (with study references)
    WITH study_refs AS (
        SELECT array_agg(id::text) as study_ids FROM studies LIMIT 2
    )
    INSERT INTO goals (id, name, description, status, target_date, study_ids, tempo_target)
    SELECT 
        '$(uuidgen | tr '[:upper:]' '[:lower:]')', 
        'Master Technical Studies', 
        'Improve finger technique and dexterity',
        'NotStarted',
        '$(date -v+3m +%Y-%m-%d)',
        to_json(study_ids),
        120
    FROM study_refs;

    -- Insert sample sessions
    WITH goal_refs AS (
        SELECT id FROM goals LIMIT 1
    )
    INSERT INTO sessions (id, goal_ids, intention, notes, session_state)
    SELECT 
        '$(uuidgen | tr '[:upper:]' '[:lower:]')',
        '[\"' || id || '\"]',
        'Focus on slow practice and accuracy',
        NULL,
        'NotStarted'
    FROM goal_refs;

    INSERT INTO sessions (id, goal_ids, intention, notes, session_state) VALUES 
    ('$(uuidgen | tr '[:upper:]' '[:lower:]')', '[]', 'General practice session', NULL, 'NotStarted'),
    ('$(uuidgen | tr '[:upper:]' '[:lower:]')', '[]', 'Technique warm-up', NULL, 'NotStarted');
    "
fi

echo -e "${BLUE}📊 Verifying seeded data...${NC}"
docker-compose exec -T postgres psql -U intrada -d intrada -c "
SELECT 
    'studies' as table_name, COUNT(*) as count FROM studies
UNION ALL
SELECT 
    'goals' as table_name, COUNT(*) as count FROM goals  
UNION ALL
SELECT 
    'sessions' as table_name, COUNT(*) as count FROM sessions
ORDER BY table_name;
"

echo ""
echo -e "${GREEN}✅ Database seeded successfully!${NC}"
echo -e "${BLUE}📋 Sample data added:${NC}"
echo "  - 3 studies (Chopin, Bach, Scales)"
echo "  - 2 goals with study associations"
echo "  - 3 practice sessions"
echo ""
echo -e "${YELLOW}💡 You can now test the app with realistic sample data!${NC}"
