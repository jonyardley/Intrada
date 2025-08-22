#!/bin/bash

# Simple script to build and run the Intrada server
# This script starts PostgreSQL via docker-compose and then runs the server

set -e  # Exit on any error

echo "🚀 Starting Intrada Server..."

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker and try again."
        echo "   You can start Docker by:"
        echo "   - Opening Docker Desktop application"
        echo "   - Or running: open -a Docker"
        exit 1
    fi
}

# Function to start Docker if it's not running (macOS specific)
ensure_docker_running() {
    if ! docker info > /dev/null 2>&1; then
        echo "🐳 Docker is not running. Attempting to start Docker Desktop..."
        open -a Docker
        echo "⏳ Waiting for Docker to start..."
        
        # Wait up to 60 seconds for Docker to start
        for i in {1..60}; do
            if docker info > /dev/null 2>&1; then
                echo "✅ Docker is now running"
                break
            fi
            if [ $i -eq 60 ]; then
                echo "❌ Docker failed to start within 60 seconds"
                echo "   Please manually start Docker Desktop and try again"
                exit 1
            fi
            sleep 1
        done
    fi
}

# Ensure Docker is running
ensure_docker_running

# Start PostgreSQL database
echo "📦 Starting PostgreSQL database..."
docker-compose up -d

# Wait a moment for the database to be ready
echo "⏳ Waiting for database to be ready..."
sleep 3

# Check if server is already running on port 3000
if lsof -ti:3000 > /dev/null 2>&1; then
    EXISTING_PID=$(lsof -ti:3000)
    echo "⚠️  Server is already running on port 3000 (PID: $EXISTING_PID)"
    echo "🔄 Stopping existing server..."
    kill $EXISTING_PID 2>/dev/null || true
    
    # Wait a moment for the process to stop
    sleep 2
    
    # Check if it's still running and force kill if necessary
    if kill -0 $EXISTING_PID 2>/dev/null; then
        echo "🔄 Force stopping server..."
        kill -9 $EXISTING_PID 2>/dev/null || true
        sleep 1
    fi
    
    echo "✅ Existing server stopped"
fi

# Build and run the server
echo "🔨 Building and running the server..."
cargo run

echo "✅ Server startup complete!"
