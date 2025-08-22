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

# Step 1: Type generation
echo "🔄 Running type generation..."
./build-and-typegen.sh

# Step 2: Start server in background
echo "🔄 Starting server..."
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