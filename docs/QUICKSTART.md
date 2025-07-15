# Intrada - Quick Start Guide

Get up and running with the Intrada music practice application in minutes.

## Prerequisites

- **Rust** (1.80 or later) - [Install Rust](https://rustup.rs/)
- **Node.js** (18 or later) - [Install Node.js](https://nodejs.org/)
- **PostgreSQL** - [Install PostgreSQL](https://www.postgresql.org/download/)
- **Xcode** (for iOS development) - [Install Xcode](https://developer.apple.com/xcode/)

## Quick Setup

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd Intrada
cargo build
```

### 2. Database Setup

```bash
# Start PostgreSQL (method varies by OS)
# macOS with Homebrew:
brew services start postgresql

# Create database
createdb intrada

# Set environment variable
export DATABASE_URL="postgresql://localhost/intrada"
```

### 3. Start the Server

```bash
cd server
cargo run
```

The server will start on `http://localhost:3000`

### 4. Run the Web Application

```bash
cd web-leptos
npm install
npm run dev
```

Open `http://localhost:8080` in your browser.

### 5. Run the iOS Application

```bash
cd iOS
open Intrada.xcodeproj
```

Build and run from Xcode.

## Project Structure

```
Intrada/
├── shared/           # Core business logic (Rust)
├── server/           # Backend API (Rust + PostgreSQL)
├── web-leptos/       # Web frontend (Leptos)
├── iOS/              # iOS app (Swift + SwiftUI)
└── docs/             # Documentation
```

## Common Commands

```bash
# Run all tests
cargo test

# Generate type bindings
./typegen.sh

# Format code
cargo fmt

# Run linter
cargo clippy

# Build for production
cargo build --release
```

## Next Steps

- Read the [Local Development Guide](LOCAL_DEVELOPMENT.md) for detailed setup
- Check the [Architecture Overview](../CLAUDE.md) to understand the codebase
- See [Deployment Guide](DEPLOYMENT.md) for production setup

## Troubleshooting

### Common Issues

**Database Connection Failed**
- Ensure PostgreSQL is running
- Check `DATABASE_URL` environment variable
- Verify database exists: `createdb intrada`

**Type Generation Errors**
- Run `cargo build` in the `shared/` directory first
- Ensure all dependencies are installed

**iOS Build Issues**
- Update Xcode to latest version
- Clean build folder: Product → Clean Build Folder
- Reset simulator if needed

## Getting Help

- Review the [documentation](README.md)
- Check existing [issues](https://github.com/your-org/intrada/issues)
- Create a new issue if needed

---

*This quickstart gets you running locally. For production deployment, see the [Deployment Guide](DEPLOYMENT.md).*