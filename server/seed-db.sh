#!/bin/bash
set -e

echo "🌱 Seeding database with sample data..."

# Change to server directory
cd "$(dirname "$0")"

# Function to check if PostgreSQL container is running
check_postgres() {
    if ! docker-compose ps postgres | grep -q "Up"; then
        echo "🔄 Starting PostgreSQL container..."
        docker-compose up -d postgres
        sleep 3
    fi
}

# Function to run migrations
run_migrations() {
    echo "🔄 Running database migrations..."
    
    # Check if migrations directory exists
    if [ ! -d "migrations" ]; then
        echo "⚠️  No migrations directory found"
        return
    fi
    
    # Run each migration file in order
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "🔄 Running migration: $(basename "$migration")"
            docker-compose exec -T postgres psql -U postgres -d intrada -f - < "$migration"
        fi
    done
}

# Function to seed sample data
seed_sample_data() {
    echo "🔄 Inserting sample data..."
    
    # Create sample data SQL
    cat <<EOF | docker-compose exec -T postgres psql -U postgres -d intrada
-- Sample Goals
INSERT INTO goals (id, title, description, target_date, created_at, updated_at) VALUES
('goal-1', 'Master Bach Invention No. 1', 'Learn to play Bach Invention No. 1 in C major with proper articulation and tempo', '2024-12-31', NOW(), NOW()),
('goal-2', 'Improve sight-reading', 'Practice sight-reading daily with progressive exercises', '2024-12-31', NOW(), NOW()),
('goal-3', 'Learn scales and arpeggios', 'Master all major and minor scales, plus basic arpeggios', '2024-12-31', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Sample Studies
INSERT INTO studies (id, goal_id, title, description, created_at, updated_at) VALUES
('study-1', 'goal-1', 'Bach Invention Analysis', 'Analyze the structure and harmonic progression of Bach Invention No. 1', NOW(), NOW()),
('study-2', 'goal-1', 'Hand Independence Practice', 'Practice exercises to improve hand independence for Bach Invention', NOW(), NOW()),
('study-3', 'goal-2', 'Daily Sight-Reading', 'Daily sight-reading practice with progressive difficulty', NOW(), NOW()),
('study-4', 'goal-3', 'Scale Practice Routine', 'Systematic practice of major and minor scales', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Sample Sessions
INSERT INTO sessions (id, study_id, title, duration_minutes, notes, rating, created_at, updated_at) VALUES
('session-1', 'study-1', 'Bach Analysis Session', 45, 'Analyzed measures 1-8, identified key modulations', 4, NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
('session-2', 'study-2', 'Hand Independence Exercises', 30, 'Practiced Hanon exercises 1-3 for hand coordination', 3, NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
('session-3', 'study-3', 'Sight-Reading Practice', 20, 'Worked on Grade 3 sight-reading examples', 4, NOW(), NOW()),
('session-4', 'study-4', 'C Major Scale Practice', 15, 'Practiced C major scale hands together, various rhythms', 5, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;
EOF
}

# Main execution
echo "📋 Seeding database..."

check_postgres
run_migrations
seed_sample_data

echo ""
echo "🎉 Database seeding completed!"
echo "📊 Sample data added:"
echo "   • 3 practice goals"
echo "   • 4 studies" 
echo "   • 4 practice sessions"