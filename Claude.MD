# Claude.MD - Intrada Project Context

## 🎵 Project Vision

**Intrada empowers musicians to achieve mastery through structured, efficient, and deeply reflective practice.**

We're building intelligent tools that transform practice from routine into a deliberate pathway to virtuosity. The application provides:
- **Planning**: Structured goal-setting and session planning
- **Focused Execution**: Distraction-free practice environments with timing and tracking
- **Insightful Analysis**: Deep reflection and progress visualization

## 🏗️ Architecture Philosophy

### Core Principles
- **Rust-First**: Core business logic lives in Rust for type safety, performance, and cross-platform compatibility
- **Shared Core**: Single source of truth for business logic using Crux architecture
- **Type Safety**: Leverage Rust's type system to prevent bugs and ensure correctness
- **Infrastructure as Code**: Database schemas derived from Rust types, not the other way around

### Technology Stack
- **Core Logic**: Rust + Crux (cross-platform business logic)
- **iOS**: Swift + SwiftUI (native iOS experience)
- **Web**: Leptos (Rust-based reactive web framework)
- **Backend**: Custom Rust server with Axum
- **Styling**: Tailwind CSS for consistent, utility-first design

## 🛠️ Development Practices

### Code Organization
- **`shared/`**: Core business logic, models, and cross-platform code
- **`iOS/`**: Native iOS application
- **`web-leptos/`**: Web application
- **`server/`**: Backend server implementation
- **`docs/`**: Comprehensive documentation for all aspects

### Development Workflow
1. **Make changes** in Rust types (`shared/src/app/`)
2. **Validate changes** (see Change Validation Requirements below)
3. **Generate types** for other platforms using `./typegen.sh`
4. **Test all applications** to ensure no downstream issues
5. **Deploy** via server deployment
6. **Update frontends** to use new functionality

### Change Validation Requirements ⚠️
**CRITICAL**: Every change must pass ALL of these checks before being considered complete:

1. **Compilation**: All Rust code must compile successfully
   ```bash
   cargo build --workspace
   ```

2. **Formatting**: Code must be properly formatted
   ```bash
   cargo fmt --all --check
   ```

3. **Linting**: Code must pass Clippy checks
   ```bash
   cargo clippy --workspace --all-targets --all-features -- -D warnings
   ```

4. **Type Generation**: Must not break cross-platform type generation
   ```bash
   ./build-and-typegen.sh
   ```

5. **All Applications**: Must test all downstream applications
   ```bash
   # iOS App
   cd iOS && ./build-and-run.sh
   
   # Web-Leptos App
   cd web-leptos && npm run build:css && cargo build && cargo test
   
   # Server (if applicable)
   cd server && cargo build && cargo test
   ```

6. **Event Structure Synchronization**: When modifying events, ensure ALL platforms are updated:
   - **Shared Core**: Events defined in respective domain modules (`shared/src/app/`)
   - **iOS App**: Swift code using generated bindings
   - **Web-Leptos**: Rust code using the new event structure
   - **Tests**: All test code across all platforms

### Quick Validation Script
For convenience, you can run this comprehensive validation:
```bash
#!/bin/bash
echo "🔍 Running full validation suite..."

echo "1️⃣ Checking compilation..."
cargo build --workspace || exit 1

echo "2️⃣ Checking formatting..."
cargo fmt --all --check || exit 1

echo "3️⃣ Checking linting..."
cargo clippy --workspace --all-targets --all-features -- -D warnings || exit 1

echo "4️⃣ Running type generation..."
./build-and-typegen.sh || exit 1

echo "5️⃣ Testing web-leptos..."
cd web-leptos && npm run build:css && cargo build && cargo test || exit 1
cd ..

echo "6️⃣ Testing iOS app..."
cd iOS && ./build-and-run.sh || exit 1
cd ..

echo "✅ All validations passed!"
```

### Keeping Platforms in Sync
- **Event Changes**: When adding/modifying events, update ALL consuming platforms simultaneously
- **Type Changes**: Run `./build-and-typegen.sh` after any shared type modifications
- **Breaking Changes**: Plan migration strategy for all platforms before implementation
- **Testing**: Every change must be verified across iOS, web-leptos, and server applications

### Type-Driven Development
- Database schemas are generated from Rust types, not defined separately
- Changes to data models happen in Rust first, then propagate to database
- This ensures type safety and prevents schema drift

### Cross-Platform Type Generation
- **`./typegen.sh`**: Generates platform-specific types from Rust core types
- **Swift Types**: Creates Swift bindings for iOS development (`SharedTypes`)
- **Java Types**: Generates Java bindings for Android (if needed)
- **TypeScript**: Can generate TypeScript types for web (currently commented out)
- **Process**: Run after making changes to shared Rust types to keep platform bindings in sync

### Type-State State Machines
- **Critical Pattern**: Use type-state pattern for state machines to catch invalid transitions at compile time
- **Example**: `PracticeSession` enum with `NotStarted`, `Started`, and `Ended` variants
- **Benefits**: Invalid state transitions become compile-time errors rather than runtime bugs
- **iOS Safety**: The iOS app catches bad transitions at compile time, not runtime
- **Implementation**: Each state is a distinct type with state-specific methods and data
- **Pattern**: State-specific structs + enum wrapper + consuming transition methods
- **Key Insight**: Invalid transitions like "start an already started session" are impossible to express

### Event Structure Organization
- **Domain-Specific Events**: Events are organized by domain within their respective modules
  - `GoalEvent` in `shared/src/app/goal.rs`
  - `StudyEvent` in `shared/src/app/study.rs`
  - `SessionEvent` in `shared/src/app/session.rs`
  - `StudySessionEvent` in `shared/src/app/study_session.rs`
  - `DevEvent` in `shared/src/app/dev.rs`
- **Main Event Enum**: Central `Event` enum in `shared/src/app.rs` aggregates all domain events
- **Consistent Structure**: All platforms use the same nested event structure:
  ```rust
  Event::Goal(GoalEvent::AddGoal(goal))
  Event::Study(StudyEvent::AddStudy(study))
  Event::Session(SessionEvent::AddSession(session))
  Event::Dev(DevEvent::SetDevData)
  ```
- **Type Generation Compatible**: This structure works seamlessly with Crux type generation
- **Platform Synchronization**: When adding events, update ALL platforms simultaneously

## 📋 Coding Standards

### Rust Code
- **Edition**: 2021, minimum version 1.80
- **Formatting**: Use `cargo fmt` (rustfmt)
- **Linting**: Use `cargo clippy` for additional checks
- **Testing**: Use `cargo nextest` for fast, parallel testing
- **Documentation**: Document public APIs with `///` comments

### Swift Code
- Follow Swift naming conventions
- Use SwiftUI for all UI components
- Leverage Swift's type system for safety
- Keep platform-specific code minimal
- **Error Handling**: Prefer `Result<T, E>` types over complex type-state patterns for compile-time safety
- **Builder Pattern**: Use simple builder patterns with Result validation rather than verbose type-state builders

### Web Code (Leptos)
- Follow Leptos patterns and conventions
- Use Tailwind for styling
- Maintain responsive design principles
- Keep components focused and composable

## 🔧 Infrastructure Standards

### Server Management
- **Source of Truth**: Rust types in `shared/src/app/`
- **Server**: Custom Rust server with Axum
- **Deployment**: Automated via CI/CD
- **Environments**: Local, Staging, Production

### Local Development
- **One Command Setup**: `make setup` should get everything running
- **Local Server**: Local Rust server for development
- **Environment Files**: `.env.local` for local configuration
- **Hot Reload**: Development servers with live reloading

### Environment Variables
- **INTRADA_SERVER_ENDPOINT**: Server endpoint URL (default: `http://localhost:3000`)
  - Used by iOS app via `ConfigurationManager.getServerEndpoint()`
  - Used by Rust shared code via `ApiConfig::from_env()`
- **WORKSPACE_PATH**: Full path to the project workspace (for buildServer.json)
- **BUILD_ROOT**: Xcode build output directory (for buildServer.json)

### Deployment
- **Environment Parity**: Same server configuration across all environments
- **Automated**: CI/CD handles deployments
- **Rollback Capable**: Server deployment supports rollbacks
- **Validated**: Pre-deployment validation prevents errors

## 🧪 Testing Philosophy

### Test Pyramid
- **Unit Tests**: Core business logic in `shared/`
- **Integration Tests**: Cross-platform functionality
- **End-to-End**: Critical user journeys
- **Server Tests**: Server API validation

### Test Data
- Use realistic but anonymized data
- Avoid hardcoded values where possible
- Use snapshot testing for complex data structures
- Test edge cases and error conditions

## 📚 Documentation Standards

### Code Documentation
- **Public APIs**: Always documented with examples
- **Complex Logic**: Inline comments explaining "why" not "what"
- **Examples**: Real-world usage examples in docs
- **Architecture Decisions**: Captured in docs/ folder

### User Documentation
- **Quick Start**: Get users running in minutes
- **Development Guide**: Comprehensive development workflow
- **Infrastructure Guide**: Backend and deployment details
- **Troubleshooting**: Common issues and solutions

## 🤝 Collaboration Practices

### Code Reviews
- Focus on architecture and design decisions
- Ensure tests are included with changes
- Check for documentation updates
- Verify schema changes are handled properly

### Pull Requests
- Include context about the change
- Link to related issues or discussions
- Include testing instructions
- Update documentation if needed

## 🎯 When Working with Claude

### Preferred Approaches
- **Understand Context**: Always review existing patterns before suggesting changes
- **Type Safety First**: Prefer solutions that leverage Rust's type system
- **Follow Architecture**: Respect the Crux architecture and shared core principle
- **Type-State Machines**: Maintain and extend type-state patterns for state management
- **Server Aware**: Remember that data model changes need server updates
- **Documentation**: Include or update documentation with code changes

### Code Changes - MANDATORY VALIDATION ⚠️
**EVERY CHANGE MUST**:
1. **Compile successfully** across all workspace crates
2. **Pass `cargo fmt --all --check`** (proper formatting)
3. **Pass `cargo clippy --workspace --all-targets --all-features -- -D warnings`** (no linting errors)
4. **Pass `./build-and-typegen.sh`** (type generation must work)
5. **Test all applications** (iOS, web-leptos, server) to ensure no downstream breakage

### Platform Synchronization Requirements
- **Event Changes**: When modifying events, ALL platforms must be updated simultaneously:
  - Update shared core events in domain modules (`shared/src/app/`)
  - Update iOS app Swift code to use new event structure
  - Update web-leptos Rust code to use new event structure
  - Update all test code across all platforms
- **Never leave platforms out of sync** - this causes hard-to-debug issues
- **Always run full validation suite** before considering a change complete

### Code Changes
- **Shared Core First**: Business logic changes start in `shared/`
- **Server Evolution**: Server changes follow the API-first pattern
- **Test Coverage**: Include tests for new functionality
- **Platform Consistency**: Ensure changes work across iOS and web
- **Full Validation**: Every change must pass compilation, formatting, linting, typegen, and app testing

### Problem Solving
- **Investigate First**: Look at existing code patterns and solutions
- **Minimal Changes**: Prefer small, focused changes over large refactors
- **Consider Impact**: Think about how changes affect all platforms
- **Performance Aware**: Consider the performance implications of changes
- **Validation First**: Always validate changes before considering them complete

## 🔄 Common Workflows

### Adding New Data Model
1. Define Rust type in `shared/src/app/`
2. Update server API to handle new model
3. Deploy server changes
4. Update frontend code to use new model

### Updating Existing Model
1. Modify Rust type in `shared/src/app/`
2. Update server API if needed
3. Plan migration (if breaking changes)
4. Deploy server changes
5. Update frontend code

### Bug Fixes
1. Write failing test that reproduces the bug
2. Fix the bug in shared core
3. Ensure test passes
4. Update documentation if needed
5. Deploy fix

### Adding State Machines
1. Define state variants as separate structs (e.g., `NotStartedSession`, `StartedSession`)
2. Create main enum with variants wrapping the state structs
3. Implement state-specific methods on each state struct
4. Add transition methods that consume `self` and return next state
5. Handle transitions in the main enum with `Result<(), &'static str>`
6. Write tests covering all valid and invalid transitions

## 🚀 Project Goals

### Short Term
- Stable core functionality for practice sessions
- Polished iOS and web experiences
- Reliable local development environment
- Comprehensive documentation

### Long Term
- Advanced practice analytics and insights
- Social features for shared practice
- Integration with music notation software
- Cross-platform desktop applications

---

*This document should be updated as the project evolves and new conventions are established.* 