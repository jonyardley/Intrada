#!/bin/bash

# Simple script to build and run the Intrada server
# This script starts PostgreSQL via docker-compose and then runs the server

set -e  # Exit on any error

echo "🚀 Starting Intrada Server..."

# Start PostgreSQL database
echo "📦 Starting PostgreSQL database..."
docker-compose up -d

# Wait a moment for the database to be ready
echo "⏳ Waiting for database to be ready..."
sleep 3

# Build and run the server
echo "🔨 Building and running the server..."
cargo run

echo "✅ Server startup complete!"
