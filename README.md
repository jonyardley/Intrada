# Intrada 🎵

> **Intrada empowers musicians to achieve mastery through structured, efficient, and deeply reflective practice.**

By providing intelligent tools for planning, focused execution, and insightful analysis, Intrada transforms practice from a routine into a deliberate pathway to virtuosity.

## 🏗️ Architecture

Intrada is built with a **Rust-first, cross-platform architecture** using the [Crux](https://redbadger.github.io/crux/) framework:

- **🦀 Shared Core**: All business logic lives in Rust for type safety, performance, and cross-platform compatibility
- **📱 Native iOS**: SwiftUI application with generated Rust bindings
- **🌐 Web Application**: [Leptos](https://leptos.dev/) (Rust-based reactive web framework)
- **⚙️ Backend Server**: Custom Rust server with [Axum](https://github.com/tokio-rs/axum)

### Technology Stack

| Component | Technology | Purpose |
|-----------|------------|----------|
| **Core Logic** | Rust + Crux | Cross-platform business logic and state management |
| **iOS App** | Swift + SwiftUI | Native iOS experience with generated bindings |
| **Web App** | Leptos + WASM | Reactive web interface compiled to WebAssembly |
| **Backend** | Rust + Axum + PostgreSQL | API server and data persistence |
| **Styling** | Tailwind CSS | Consistent, utility-first design system |
| **Type Generation** | UniFFI + Custom tooling | Automated platform-specific type bindings |

## 🚀 Quick Start

**Prerequisites**: Rust 1.80+, Node.js 18+, Docker, Xcode (for iOS)

### Using cargo-xtask (Recommended) ✨

```bash
# Clone the repository
git clone https://github.com/jonyardley/intrada.git
cd intrada

# Initial setup (one-time)
cargo xtask setup

# Start development environment with live logs
cargo xtask start --logs

# Or for a clean rebuild and start
cargo xtask rebuild --logs
```

**💡 Pro Tip**: Add a shell alias for shorter commands:
```bash
# Add to your shell config (~/.bashrc, ~/.zshrc, ~/.config/fish/config.fish):
alias xt="cargo xtask"

# Then use the shorter syntax:
xt setup                      # instead of: cargo xtask setup
xt start --logs               # instead of: cargo xtask start --logs
xt rebuild --logs             # instead of: cargo xtask rebuild --logs
xt doctor                     # instead of: cargo xtask doctor
xt clean all                  # instead of: cargo xtask clean all
```

**🚀 Quick Setup with Alias:**
```bash
# Clone and setup with alias
git clone https://github.com/jonyardley/intrada.git
cd intrada
alias xt="cargo xtask"       # Add this to your shell config for persistence
xt setup                     # One-time setup
xt start --logs              # Start development with live logs
```

### Option 2: Manual Setup

```bash
# Clone and build
git clone https://github.com/jonyardley/intrada.git
cd intrada
./build-and-typegen.sh

# Start server
cd server && cargo run &

# Start web app (in another terminal)
cd web-leptos && npm install && npm run dev
```

For detailed setup instructions, see **[docs/QUICKSTART.md](docs/QUICKSTART.md)**.

## 📁 Project Structure

```
intrada/
├── shared/           # 🦀 Core Rust business logic (Crux)
├── iOS/             # 📱 Native iOS application (SwiftUI)
├── web-leptos/      # 🌐 Web application (Leptos + WASM)
├── server/          # ⚙️ Backend API server (Axum)
├── shared_types/    # 🔄 Cross-platform type generation
├── xtask/           # 🔧 Project management CLI tool (cargo-xtask)
├── docs/            # 📚 Comprehensive documentation
└── .cargo/          # 🔧 Cargo configuration for xtask
```

## 🛠️ Development Workflow

### Using cargo-xtask (Recommended)

The Intrada project uses cargo-xtask for unified development operations:

```bash
# Database management
cargo xtask db clean --force      # Clean all data
cargo xtask db seed               # Add sample data
cargo xtask db reset --force      # Clean and seed

# Build operations
cargo xtask build all             # Build all components
cargo xtask build core            # Build and test Crux core
cargo xtask build rebuild         # Clean and rebuild all components
cargo xtask build types           # Generate type bindings
cargo xtask build full            # Build with type generation

# Development environment
cargo xtask start --logs          # Start with live log streaming
cargo xtask quick --logs          # Quick start (skip type gen)
cargo xtask rebuild --logs        # Clean rebuild and start with logs
cargo xtask dev status            # Check what's running
cargo xtask dev stop              # Stop all services

# Testing
cargo xtask test core             # Test Crux core business logic
cargo xtask test server           # Test server API
cargo xtask test ios              # Test iOS app
cargo xtask test web              # Test web app
cargo xtask test all              # Test all components

# Log streaming
cargo xtask logs server           # Server logs only
cargo xtask logs ios              # iOS simulator logs
cargo xtask logs database         # PostgreSQL logs
cargo xtask logs all              # All logs multiplexed

# Component-specific operations
cargo xtask server start          # Start server only
cargo xtask server rebuild        # Rebuild and run server
cargo xtask ios start             # Build and run iOS app
cargo xtask ios rebuild           # Rebuild and run iOS app

# Clean operations
cargo xtask clean all             # Clean all build artifacts
cargo xtask clean shared          # Clean shared Rust artifacts
cargo xtask clean server          # Clean server build artifacts
cargo xtask clean ios             # Clean iOS artifacts and derived data
cargo xtask clean web             # Clean web build artifacts

# Development utilities
cargo xtask watch                 # Watch for changes and rebuild
cargo xtask format                # Format all code (Rust, Swift, etc.)
cargo xtask lint                  # Run linters without building
cargo xtask deps check            # Check for outdated dependencies
cargo xtask deps update           # Update dependencies
cargo xtask bench                 # Run benchmarks
cargo xtask doctor                # Health check for development environment
```

### Manual Development (Legacy)

> **Note**: All development shell scripts have been replaced by cargo-xtask. No installation required!

#### Making Changes

1. **Modify Rust types** in `shared/src/app/`
2. **Validate changes** (see validation requirements below)
3. **Generate types**: `cargo xtask build types`
4. **Update frontends** to use new functionality
5. **Test all applications** to ensure no downstream issues

#### Validation Requirements ⚠️

**Every change must pass ALL of these checks:**

```bash
# Using cargo-xtask (recommended)
cargo xtask build all

# Or manually
cargo build --workspace
cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo xtask build full
```

#### Running Applications Manually

```bash
# Web Development
cd web-leptos && npm run dev

# iOS Development  
cargo xtask ios start

# Server Development
cargo xtask server start

# Core Tests
cargo nextest run --release -p shared
```

## 📚 Documentation

- **[📖 Quick Start Guide](docs/QUICKSTART.md)** - Get your development environment running
- **[🔧 Development Guide](docs/DEVELOPMENT.md)** - Development workflow and best practices
- **[📱 iOS Testing](docs/IOS_TESTING.md)** - iOS-specific development and testing
- **[🔄 Type Generation](docs/TYPE_GENERATION.md)** - Cross-platform type generation system
- **[🚀 Deployment](docs/DEPLOYMENT.md)** - Production deployment guide
- **[💻 Local Development](docs/LOCAL_DEVELOPMENT.md)** - Local development environment setup

## 🎯 Key Features

- **📋 Practice Planning**: Structured goal-setting and session planning
- **⏱️ Focused Execution**: Distraction-free practice environments with timing
- **📊 Insightful Analysis**: Deep reflection and progress visualization
- **🔄 Cross-Platform**: Consistent experience across iOS and web
- **🔒 Type Safety**: Rust's type system prevents bugs at compile time
- **⚡ Performance**: WASM for web, native compilation for iOS

## 🤝 Contributing

We welcome contributions! Please see our development workflow above and ensure all validation checks pass before submitting a PR.

### Architecture Principles

- **Rust-First**: Core business logic lives in Rust
- **Shared Core**: Single source of truth using Crux architecture
- **Type Safety**: Leverage Rust's type system to prevent bugs
- **Infrastructure as Code**: Database schemas derived from Rust types

---

*Built with ❤️ for musicians who want to practice smarter, not just harder.*
