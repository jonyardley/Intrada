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
- **Infrastructure**: Rust-based server deployment
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
2. **Generate types** for other platforms using `./typegen.sh`
3. **Test locally** against local server
4. **Deploy** via server deployment
5. **Update frontends** to use new functionality

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

### Code Changes
- **Shared Core First**: Business logic changes start in `shared/`
- **Server Evolution**: Server changes follow the API-first pattern
- **Test Coverage**: Include tests for new functionality
- **Platform Consistency**: Ensure changes work across iOS and web

### Problem Solving
- **Investigate First**: Look at existing code patterns and solutions
- **Minimal Changes**: Prefer small, focused changes over large refactors
- **Consider Impact**: Think about how changes affect all platforms
- **Performance Aware**: Consider the performance implications of changes

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