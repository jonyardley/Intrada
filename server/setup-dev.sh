#!/bin/bash
set -e

echo "🎵 Setting up Intrada Server for local development..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ Created .env file. You can modify it if needed."
else
    echo "✅ .env file already exists."
fi

# Start PostgreSQL with Docker Compose
echo "🐘 Starting PostgreSQL database..."
docker-compose up -d postgres

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker-compose exec postgres pg_isready -U intrada_user -d intrada_db > /dev/null 2>&1; do
    echo "⏳ Still waiting for PostgreSQL..."
    sleep 2
done

echo "✅ PostgreSQL is ready!"

# Build the project and migrator
echo "🔨 Building the project..."
cargo build --bin migrator

# Run migrations using SeaORM migrator
echo "🔄 Running database migrations..."
cargo run --bin migrator up

echo "🚀 Setup complete! You can now run:"
echo "   cargo run"
echo ""
echo "🔍 Health check will be available at: http://localhost:3000/health"
echo ""
echo "📚 Useful commands:"
echo "   cargo run --bin migrator status  # Check migration status"
echo "   cargo run --bin migrator down    # Rollback last migration"
echo "   cargo run --bin migrator reset   # Reset all migrations"