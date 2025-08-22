#!/bin/bash
# Quick development startup script for Intrada
set -e

echo "🚀 Intrada Quick Dev Start"
echo "========================="

# Function to ensure Docker is running (macOS specific)
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

# Step 0: Ensure Docker is running
echo "🔄 Checking Docker status..."
ensure_docker_running

# Step 0.5: Ensure PostgreSQL database is running
echo "🔄 Starting PostgreSQL database..."
cd server
if docker-compose up -d; then
    echo "✅ PostgreSQL database started"
    echo "⏳ Waiting for database to be ready..."
    sleep 5
else
    echo "❌ Failed to start PostgreSQL database"
    exit 1
fi
cd ..

# Step 1: Type generation
echo "🔄 Running type generation..."
./build-and-typegen.sh

# Step 2: Start server in background
echo "🔄 Starting server..."

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

cd server
cargo run > ../server.log 2>&1 &
SERVER_PID=$!
echo "✅ Server started (PID: $SERVER_PID)"
cd ..

# Wait for server to initialize
sleep 3

# Step 3: Build and run iOS app
echo "🔄 Building and launching iOS app..."
cd iOS
./build-and-run.sh
cd ..

echo "✅ Development environment ready!"
echo "📋 Server PID: $SERVER_PID (logs: tail -f server.log)"
echo "📋 To stop server: kill $SERVER_PID"