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

**Prerequisites**: Rust 1.80+, Node.js 18+, PostgreSQL, Xcode (for iOS)

```bash
# Clone and build
git clone https://github.com/jonyardley/intrada.git
cd intrada
cargo build --workspace

# Setup database
createdb intrada
export DATABASE_URL="postgresql://localhost/intrada"

# Start server
cd server && cargo run &

# Start web app
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
├── docs/            # 📚 Comprehensive documentation
└── build-and-typegen.sh  # 🛠️ Development tooling
```

## 🛠️ Development Workflow

### Making Changes

1. **Modify Rust types** in `shared/src/app/`
2. **Validate changes** (see validation requirements below)
3. **Generate types** for other platforms: `./build-and-typegen.sh`
4. **Update frontends** to use new functionality
5. **Test all applications** to ensure no downstream issues

### Validation Requirements ⚠️

**Every change must pass ALL of these checks:**

```bash
# 1. Compilation
cargo build --workspace

# 2. Formatting
cargo fmt --all --check

# 3. Linting
cargo clippy --workspace --all-targets --all-features -- -D warnings

# 4. Type generation
./build-and-typegen.sh

# 5. Platform testing
cd web-leptos && cargo build && cargo test
cd ../iOS && ./build-and-run.sh
```

### Running Applications

#### Web Development
```bash
cd web-leptos
npm run dev  # Starts Tailwind watcher + Trunk dev server
```

#### iOS Development
```bash
cd iOS
./build-and-run.sh  # Builds Rust core + opens Xcode
```

#### Server Development
```bash
cd server
cargo run  # Starts on http://localhost:3000
```

#### Core Tests
```bash
# Install cargo-nextest for faster testing
cargo binstall cargo-nextest --secure

# Run core logic tests
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
