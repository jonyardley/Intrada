#!/bin/bash
set -e

echo "🧹 Cleaning database..."

# Change to server directory
cd "$(dirname "$0")"

# Check for force flag
FORCE=false
if [ "$1" = "--force" ]; then
    FORCE=true
fi

# Function to confirm action
confirm_cleanup() {
    if [ "$FORCE" = false ]; then
        echo "⚠️  This will delete ALL data from the database!"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Database cleanup cancelled"
            exit 1
        fi
    fi
}

# Function to check if PostgreSQL container is running
check_postgres() {
    if ! docker-compose ps postgres | grep -q "Up"; then
        echo "🔄 Starting PostgreSQL container..."
        docker-compose up -d postgres
        sleep 3
    fi
}

# Function to clean database
cleanup_database() {
    echo "🔄 Dropping and recreating database..."
    
    # Connect to PostgreSQL and drop/create database
    docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS intrada;"
    docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE intrada;"
    
    echo "✅ Database cleaned successfully"
}

# Main execution
confirm_cleanup
check_postgres
cleanup_database

echo ""
echo "🎉 Database cleanup completed!"
echo "💡 Run 'cargo xtask db seed' to add sample data"