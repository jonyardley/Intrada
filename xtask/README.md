# Intrada xtask

A comprehensive cargo-xtask implementation for managing the Intrada project development workflow.

## About cargo-xtask

This project uses [cargo-xtask](https://github.com/matklad/cargo-xtask), a pattern for adding custom automation to Rust projects. No installation required - just clone and run!

## Getting Started

From the project root directory:

```bash
# No installation needed! Just run:
cargo xtask --help
```

**💡 Pro Tip**: Add a shell alias for shorter commands:
```bash
# Add to your ~/.bashrc, ~/.zshrc, or equivalent:
alias xt="cargo xtask"

# Then use the shorter syntax:
xt --help
xt setup
xt start --logs
```

## Usage

### Quick Start
```bash
# Initial setup (first time only)
cargo xtask setup    # or: xt setup

# Start development environment
cargo xtask start    # or: xt start

# Start with live log streaming
cargo xtask start --logs    # or: xt start --logs

# Quick start (skip type generation)
cargo xtask quick --logs    # or: xt quick --logs

# Clean rebuild and start (when you need a fresh build)
cargo xtask rebuild --logs  # or: xt rebuild --logs
```

### Database Management
```bash
# Clean all data from database
cargo xtask db clean

# Seed database with sample data
cargo xtask db seed

# Clean and seed database (with confirmation)
cargo xtask db reset

# Force operations without confirmation
cargo xtask db clean --force
cargo xtask db reset --force

# Check database status
cargo xtask db status
```

### Build Operations
```bash
# Build all components
cargo xtask build all

# Build specific components
cargo xtask build shared
cargo xtask build server
cargo xtask build ios

# Build and test Crux core (comprehensive validation)
cargo xtask build core

# Clean and rebuild all components
cargo xtask build rebuild

# Generate type bindings
cargo xtask build types

# Full build with type generation
cargo xtask build full
```

### Server Management
```bash
# Start server
cargo xtask server start

# Rebuild and run server (clean build)
cargo xtask server rebuild

# Stop server
cargo xtask server stop

# View server logs
cargo xtask server logs

# Check server status
cargo xtask server status
```

### iOS Development
```bash
# Build and run iOS app
cargo xtask ios start

# Rebuild and run iOS app (clean build with fresh type bindings)
cargo xtask ios rebuild

# List available simulators
cargo xtask ios simulators
```

### Testing
```bash
# Test individual components
cargo xtask test core             # Test Crux core business logic
cargo xtask test server           # Test server API
cargo xtask test ios              # Test iOS app
cargo xtask test web              # Test web app

# Test all components
cargo xtask test all              # Test all (skips iOS for CI compatibility)
```

### Log Streaming
```bash
# Stream server logs
cargo xtask logs server

# Stream iOS simulator logs
cargo xtask logs ios

# Stream PostgreSQL logs
cargo xtask logs database

# Stream Docker logs
cargo xtask logs docker

# Stream all logs (multiplexed)
cargo xtask logs all
```

### Clean Operations
```bash
# Clean all build artifacts
cargo xtask clean all

# Clean specific components
cargo xtask clean shared         # Shared Rust artifacts
cargo xtask clean server         # Server build artifacts
cargo xtask clean ios            # iOS artifacts and derived data
cargo xtask clean web            # Web build artifacts
```

### Development Utilities
```bash
# Watch for changes and rebuild automatically
cargo xtask watch

# Format all code (Rust, Swift, web)
cargo xtask format

# Run linters without building
cargo xtask lint

# Dependency management
cargo xtask deps check           # Check for outdated dependencies
cargo xtask deps update          # Update all dependencies

# Performance and diagnostics
cargo xtask bench                # Run benchmarks
cargo xtask doctor               # Health check for dev environment
```

### Development Environment
```bash
# Show development status
cargo xtask dev status

# Stop all development services
cargo xtask dev stop
```

## Log Streaming Features

The CLI provides comprehensive log streaming capabilities:

- **Server logs**: Real-time server application logs from `server.log`
- **iOS logs**: iOS simulator logs filtered by bundle ID
- **Database logs**: PostgreSQL container logs
- **Docker logs**: All Docker container logs
- **Multiplexed logs**: All log sources combined with colored prefixes

Each log stream is color-coded for easy identification:
- `[SERVER]` - Green
- `[iOS]` - Blue  
- `[DB]` - Yellow
- `[DOCKER]` - Magenta
- `[DEV]` - Cyan

## Benefits of cargo-xtask

This approach replaces multiple shell scripts with a unified cargo-xtask interface:

- **Consistent**: Single command interface for all operations
- **Discoverable**: Built-in help for all commands
- **Robust**: Better error handling and validation
- **Extensible**: Easy to add new commands and features
- **Cross-platform**: Rust-based, works on any platform
- **Type-safe**: Compile-time validation of command structure
- **Zero installation**: No need to install CLI tools, just use cargo
- **Shell alias friendly**: Use `alias xt="cargo xtask"` for shorter commands

## Core Development

The `cargo xtask build core` command provides comprehensive validation of the Crux core:

- **Build**: Compiles the shared core package
- **Clippy**: Runs linting with strict warnings
- **Format**: Checks code formatting
- **Tests**: Runs all unit tests (with nextest if available)
- **Documentation**: Builds documentation
- **Feature flags**: Tests with different feature combinations

This is essential for core development and ensures the shared business logic is robust.

## Testing Components

Each test command provides comprehensive validation for its respective component:

### `cargo xtask test core`
- **Unit tests**: Runs all 30+ core business logic tests
- **Nextest**: Uses faster nextest runner when available
- **Verbose output**: Shows detailed test results

### `cargo xtask test server`
- **Build verification**: Ensures server compiles
- **Unit tests**: Runs server-specific tests
- **Clippy**: Lints server code with strict warnings
- **Smoke test**: Starts PostgreSQL and verifies server setup

### `cargo xtask test ios`
- **Xcode project**: Generates and validates Xcode project
- **Build for testing**: Compiles iOS app for testing
- **Unit tests**: Runs iOS app tests in simulator
- **Swift formatting**: Checks Swift code formatting (if swiftformat available)

### `cargo xtask test web`
- **Build verification**: Ensures web app compiles
- **Unit tests**: Runs web app tests
- **Clippy**: Lints web code
- **NPM audit**: Checks for security vulnerabilities in dependencies

### `cargo xtask test all`
- **Runs core, server, and web tests**
- **Skips iOS**: iOS tests require simulator setup, run separately
- **CI-friendly**: Perfect for continuous integration pipelines

## New Commands Explained

### Clean Commands
- **`clean all`**: Removes all build artifacts across the entire project
- **`clean shared`**: Cleans shared Rust packages (shared, shared_types)
- **`clean server`**: Cleans server build artifacts
- **`clean ios`**: Cleans iOS build directory, Xcode derived data, and generated bindings
- **`clean web`**: Cleans web build artifacts, node_modules, and dist folders

### Development Utilities
- **`watch`**: Uses cargo-watch to automatically rebuild when files change
- **`format`**: Formats Rust (cargo fmt), Swift (swiftformat), and web code (prettier)
- **`lint`**: Runs clippy, format check, and SwiftLint without building
- **`deps check`**: Shows outdated Rust and npm dependencies
- **`deps update`**: Updates all dependencies to latest versions
- **`bench`**: Runs Rust benchmarks across the workspace
- **`doctor`**: Comprehensive health check of your development environment

### Doctor Command Features
The `doctor` command checks:
- ✅ Rust and Cargo installation
- ✅ Docker and Docker Compose
- ✅ Node.js for web development
- ✅ Xcode and XcodeGen (macOS only)
- ✅ Project structure integrity
- ✅ Database connectivity
- 💡 Provides actionable fix instructions for any issues

## Architecture

The CLI is built using:
- **Clap**: For command-line argument parsing
- **Colored**: For terminal output formatting
- **Tokio**: For async operations
- **Anyhow**: For error handling

All commands validate that they're run from the project root and provide helpful error messages when things go wrong.
