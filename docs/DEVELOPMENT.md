# Development Guide

This guide covers the development workflow for the Intrada music practice application.

## Development Philosophy

Intrada follows a **Rust-first, shared-core architecture** with these principles:

1. **Single Source of Truth**: All business logic lives in Rust (`shared/`)
2. **Type-Driven Development**: Database schemas derive from Rust types
3. **Type-State Machines**: Invalid state transitions are compile-time errors
4. **Cross-Platform Consistency**: Shared core ensures identical behavior across platforms

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic (Rust)                    │
│                     shared/src/app/                         │
├─────────────────────────────────────────────────────────────┤
│  iOS App        │  Web App        │  Server API             │
│  (Swift/SwiftUI)│  (Leptos)       │  (Axum/PostgreSQL)     │
└─────────────────────────────────────────────────────────────┘
```

## Development Workflow

### 1. Making Changes to Core Logic

All changes start in the shared Rust core:

```bash
# Edit business logic
vim shared/src/app/session.rs

# Build and test
cd shared
cargo test
cargo build
```

### 2. Generate Platform Types

After changing shared types, regenerate platform bindings:

```bash
# Generate Swift/Java bindings and build all types
./build-and-typegen.sh
```

### 3. Update Platforms

Update platform-specific code to use new functionality:

```bash
# iOS - Generate Xcode project first
cd iOS
xcodegen  # Generate Xcode project from project.yml
open Intrada.xcodeproj
# Update Swift code to use new types

# Web
cd web-leptos
# Update Leptos components
```

### 4. Test Locally

```bash
# Start server
cd server && cargo run

# Start web app (CSS build required first)
cd web-leptos && npm run build:css && npm run dev

# Build iOS app - use helper script
cd iOS && ./build-and-run.sh
```

### 5. Deploy Changes

```bash
# Deploy server (if needed)
cd server && fly deploy

# Deploy web app (if needed)
cd web-leptos && npm run build:css && npm run build
```

## Code Organization

### Shared Core (`shared/`)

- **`app/model.rs`**: Core data models
- **`app/session.rs`**: Practice session logic with type-state pattern
- **`app/goal.rs`**: Goal management
- **`app/study.rs`**: Study management
- **`app/error.rs`**: Error handling types
- **`ffi.rs`**: Foreign function interface for platforms

### Server (`server/`)

- **`main.rs`**: Server entry point and routing (PostgreSQL + Axum)
- **`goals.rs`**: Goal API endpoints
- **`migrations/`**: PostgreSQL database migrations

### iOS (`iOS/`)

- **`project.yml`**: XcodeGen configuration (run `xcodegen` to generate .xcodeproj)
- **`core.swift`**: Swift wrapper around Rust core
- **`http.swift`**: HTTP client implementation
- **`*View.swift`**: SwiftUI views
- **`build-and-run.sh`**: Helper script to build and run iOS app

### Web (`web-leptos/`)

- **`main.rs`**: Web app entry point
- **`components/`**: Reusable Leptos components
- **`views/`**: Page-level components
- **`package.json`**: Contains `build:css` and `dev` scripts
- **`tailwind.config.js`**: Tailwind CSS configuration

## Type-State Pattern

Intrada uses type-state machines to prevent invalid state transitions:

```rust
pub enum PracticeSession {
    NotStarted(NotStartedSession),
    Started(StartedSession),
    Ended(EndedSession),
}

impl NotStartedSession {
    pub fn start(self, timestamp: String) -> StartedSession {
        StartedSession {
            data: self.data,
            start_time: timestamp,
        }
    }
}
```

**Benefits:**
- Invalid transitions (e.g., starting an already started session) are compile-time errors
- State-specific data is type-safe
- Impossible states are unrepresentable

## Error Handling

Use custom error types instead of strings:

```rust
#[derive(Serialize, Deserialize, Debug)]
pub enum SessionError {
    AlreadyStarted,
    NotActive,
    NotFound,
}

pub fn start_session(id: &str) -> Result<(), SessionError> {
    // ...
}
```

## Testing

### Unit Tests

```bash
# Run all tests
cargo test

# Run tests with output
cargo test -- --nocapture

# Run specific test
cargo test test_session_state_transitions
```

### Integration Tests

```bash
# Test server API
cd server
cargo test

# Test web components
cd web-leptos
cargo test
```

### iOS Testing

See [iOS Testing Guide](IOS_TESTING.md) for comprehensive iOS testing.

## Common Development Tasks

### Adding a New Data Model

1. Define struct in `shared/src/app/model.rs`
2. Add to database schema in `server/migrations/`
3. Generate types: `./typegen.sh`
4. Update platform code

### Adding a New API Endpoint

1. Add route in `server/src/main.rs`
2. Implement handler function
3. Add error handling
4. Update client code

### Adding a New View

1. Create component in appropriate platform directory
2. Connect to shared core via FFI
3. Handle state updates
4. Add navigation if needed

## Code Style

### Rust

- Use `cargo fmt` for formatting
- Use `cargo clippy` for linting
- Document public APIs with `///` comments
- Use `#[derive(Serialize, Deserialize)]` for data types

### Swift

- Follow Swift naming conventions
- Use SwiftUI for all UI
- Keep platform-specific code minimal
- Use `Result<T, E>` for error handling

### Web (Leptos)

- Use Tailwind for styling
- Keep components focused and composable
- Use server functions for API calls
- Maintain responsive design

## Debugging

### Server Issues

```bash
# Check logs
cd server && cargo run

# Database connection
psql $DATABASE_URL

# Test API endpoints
curl http://localhost:3000/goals
```

### iOS Issues

- Use Xcode debugger
- Check device logs
- Test on simulator first
- Use breakpoints in Swift code

### Web Issues

- Use browser dev tools
- Check network requests
- Use `console.log` for debugging
- Test in different browsers

## Performance Considerations

- Use `Arc<T>` for shared data to avoid cloning
- Implement lazy loading for large datasets
- Use database indexes for common queries
- Profile with appropriate tools

## Contributing

1. Create feature branch: `git checkout -b feature/new-feature`
2. Make changes following this guide
3. Add tests for new functionality
4. Update documentation
5. Create pull request

## Getting Help

- Check [CLAUDE.md](../CLAUDE.md) for project context
- Review existing code patterns
- Ask questions in issues or discussions
- Refer to [Troubleshooting](TROUBLESHOOTING.md) guide

---

*This guide evolves with the project. Please update it when adding new patterns or workflows.*