# Type Generation System

Intrada uses a dual type generation system to maintain type safety across platforms while providing runtime interoperability.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  Shared Rust Core                           │
│                shared/src/app/                              │
├─────────────────────────────────────────────────────────────┤
│    FFI Bindings         │       Data Types                  │
│    (uniffi)             │       (facet)                     │
│    Runtime Interface    │       Compile-time Safety         │
└─────────────────────────────────────────────────────────────┘
```

## Two Complementary Systems

### 1. UniFFI Bindings (`shared/`)
- **Purpose**: Provides runtime FFI interface for platforms
- **Generates**: `CoreFFI` class and runtime bindings
- **Used for**: Cross-platform communication with Rust core
- **Output**: `shared/Shared/` package

### 2. Facet Type Generation (`shared_types/`)
- **Purpose**: Provides compile-time type safety for data structures
- **Generates**: Data types, events, and other shared structures
- **Used for**: Type-safe data handling in platform code
- **Output**: `shared_types/generated/swift/` package

## How They Work Together

Both systems are needed for complete cross-platform functionality:

```swift
import Shared        // FFI runtime interface (CoreFFI)
import SharedTypes   // Data types (PracticeGoal, Event, etc.)

// Use SharedTypes for type-safe data
let goal = PracticeGoal(name: "Learn scales", ...)

// Use Shared for runtime communication
let core = CoreFFI(shell: shell)
let viewModel = try ViewModel.bincodeDeserialize(input: core.view())
```

## Generation Process

Run `./typegen.sh` to generate all bindings:

1. **FFI Bindings**: `cargo swift package` generates runtime interface
2. **Data Types**: `cargo build` in `shared_types/` generates type definitions
3. **Core Bindings**: `crux_cli bindgen` generates event/effect types

## Platform Support

### iOS (Swift)
- ✅ **Supported**: FFI bindings + data types
- **Packages**: `Shared` + `SharedTypes`
- **Usage**: Import both packages in iOS code

### Android (Java)
- 🚧 **Planned**: Data types ready, FFI bindings need implementation
- **Status**: Type generation code exists but is commented out
- **Location**: `shared_types/build.rs` line 22

### Web (TypeScript)
- 🚧 **Planned**: For future TypeScript integration
- **Status**: Type generation code exists but is commented out
- **Location**: `shared_types/build.rs` line 25

## File Structure

```
shared/
├── Shared/                 # UniFFI-generated FFI bindings
│   ├── Package.swift
│   └── Sources/
├── generated/              # Crux-generated core bindings
│   ├── swift/
│   └── java/
└── src/
    ├── ffi.rs             # FFI interface definitions
    └── shared.udl         # UniFFI interface description

shared_types/
├── generated/              # Facet-generated data types
│   ├── swift/
│   │   └── SharedTypes/
│   └── java/
├── build.rs               # Type generation build script
└── src/
    └── lib.rs             # Re-exports shared types
```

## Development Workflow

### Making Changes to Data Types

1. **Edit shared types**: Modify `shared/src/app/*.rs`
2. **Regenerate types**: Run `./typegen.sh`
3. **Update platform code**: Use new types in iOS/Android/Web code

### Adding New Platforms

1. **Enable generation**: Uncomment relevant lines in `shared_types/build.rs`
2. **Add FFI support**: Implement platform-specific FFI bindings
3. **Update typegen script**: Add platform-specific steps to `typegen.sh`

## Troubleshooting

### Common Issues

**Types not updating after changes**:
```bash
# Clean and regenerate
rm -rf shared/generated shared_types/generated
./typegen.sh
```

**Build errors in platform code**:
```bash
# Check if types were generated
ls shared_types/generated/swift/SharedTypes/Sources/
ls shared/Shared/Sources/
```

**FFI binding errors**:
```bash
# Rebuild FFI bindings
cd shared
cargo swift package --name Shared --platforms ios
```

### Debug Commands

```bash
# Check what types are being generated
cargo expand --package shared_types

# Verify FFI interface
cargo check --package shared --features cli

# Test type generation
cd shared_types && cargo build --verbose
```

## Best Practices

1. **Keep systems separate**: Don't mix FFI and type generation concerns
2. **Regenerate after changes**: Always run `./typegen.sh` after modifying shared types
3. **Version control**: Commit generated files to ensure consistency
4. **Test across platforms**: Verify changes work on all target platforms
5. **Document new types**: Add comments to complex data structures

## Future Improvements

- **Automated generation**: Integrate type generation into CI/CD
- **Selective generation**: Only generate types for specific platforms
- **Documentation generation**: Auto-generate API docs from types
- **Validation**: Add runtime validation for generated types

---

*This dual-system approach ensures both runtime interoperability and compile-time safety across all platforms.*