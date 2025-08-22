#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${PURPLE}📋 $1${NC}"
}

# Cleanup function for graceful shutdown
cleanup() {
    print_info "Shutting down development environment..."
    if [[ ! -z "$SERVER_PID" ]]; then
        print_step "Stopping server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

print_info "🚀 Starting Intrada Development Environment"
echo "========================================"

# Function to ensure Docker is running (macOS specific)
ensure_docker_running() {
    if ! docker info > /dev/null 2>&1; then
        print_step "Docker is not running. Attempting to start Docker Desktop..."
        open -a Docker
        print_step "Waiting for Docker to start..."
        
        # Wait up to 60 seconds for Docker to start
        for i in {1..60}; do
            if docker info > /dev/null 2>&1; then
                print_success "Docker is now running"
                break
            fi
            if [ $i -eq 60 ]; then
                print_error "Docker failed to start within 60 seconds"
                print_info "Please manually start Docker Desktop and try again"
                exit 1
            fi
            sleep 1
        done
    fi
}

# Step 0: Ensure Docker is running
print_step "Checking Docker status..."
ensure_docker_running

# Step 0.5: Ensure PostgreSQL database is running
print_step "Starting PostgreSQL database..."
cd server
if docker-compose up -d; then
    print_success "PostgreSQL database started"
    print_step "Waiting for database to be ready..."
    sleep 5
else
    print_error "Failed to start PostgreSQL database"
    exit 1
fi
cd ..

# Step 1: Run type generation
print_step "Running type generation..."
if ./build-and-typegen.sh; then
    print_success "Type generation completed"
else
    print_error "Type generation failed"
    exit 1
fi

# Step 2: Start the server in background
print_step "Starting server..."

# Check if server is already running on port 3000
if lsof -ti:3000 > /dev/null 2>&1; then
    EXISTING_PID=$(lsof -ti:3000)
    print_warning "Server is already running on port 3000 (PID: $EXISTING_PID)"
    print_step "Stopping existing server..."
    kill $EXISTING_PID 2>/dev/null || true
    
    # Wait a moment for the process to stop
    sleep 2
    
    # Check if it's still running and force kill if necessary
    if kill -0 $EXISTING_PID 2>/dev/null; then
        print_step "Force stopping server..."
        kill -9 $EXISTING_PID 2>/dev/null || true
        sleep 1
    fi
    
    print_success "Existing server stopped"
fi

cd server

# Check if server binary exists
if ! cargo check --quiet; then
    print_step "Building server..."
    cargo build
fi

# Start the server in background and capture PID
cargo run > ../server.log 2>&1 &
SERVER_PID=$!

# Wait a moment for server to start
sleep 2

# Check if server is running
if kill -0 $SERVER_PID 2>/dev/null; then
    print_success "Server started (PID: $SERVER_PID)"
    print_info "Server logs: tail -f server.log"
else
    print_error "Server failed to start"
    exit 1
fi

cd ..



# Step 3: Build and run iOS app
print_step "Building and launching iOS app..."
cd iOS

if ./build-and-run.sh; then
    print_success "iOS app launched successfully"
else
    print_error "iOS app launch failed"
    cleanup
    exit 1
fi

cd ..

print_success "🎉 Development environment is ready!"
echo
print_info "Development Status:"
echo "  📱 iOS App: Running in simulator"
echo "  🖥️  Server: Running (PID: $SERVER_PID)"
echo "  📋 Server logs: tail -f server.log"
echo
print_info "Press Ctrl+C to stop all services and exit"

# Keep the script running and monitor the server
while kill -0 $SERVER_PID 2>/dev/null; do
    sleep 1
done

print_warning "Server stopped unexpectedly"
cleanup