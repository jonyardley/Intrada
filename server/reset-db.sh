#!/bin/bash
set -e

echo "🔄 Resetting database..."

# Change to server directory
cd "$(dirname "$0")"

# Check for force flag
FORCE=false
if [ "$1" = "--force" ]; then
    FORCE=true
fi

# Function to confirm action
confirm_reset() {
    if [ "$FORCE" = false ]; then
        echo "⚠️  This will delete ALL data and reset the database!"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Database reset cancelled"
            exit 1
        fi
    fi
}

# Main execution
echo "📋 Resetting database (clean + seed)..."

confirm_reset

# Run cleanup with force flag
echo "🧹 Step 1: Cleaning database..."
bash ./cleanup-db.sh --force

# Run seeding
echo "🌱 Step 2: Seeding database..."
bash ./seed-db.sh

echo ""
echo "🎉 Database reset completed!"
echo "📊 Fresh database with sample data ready for development"