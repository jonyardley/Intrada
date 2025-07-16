# Local Development Setup

This document explains how to catch CI/CD errors locally before pushing to the repository.

## Problem

Sometimes code passes local checks but fails in CI/CD due to different linting configurations. The CI/CD pipeline uses stricter settings than the default local Rust toolchain.

## Solution

We've configured local tooling to match CI/CD exactly, so you can catch issues before pushing.

## Configured Tools

### 1. Rust Analyzer (IDE Integration)

**Cursor/VS Code** is configured to show the same clippy warnings as CI/CD:

- **File**: `.cursor/settings.json`
- **Configuration**: Uses `clippy` with strict warnings, including `uninlined-format-args`
- **Benefit**: See errors directly in your editor as red squiggly lines

**To see warnings in your editor:**
1. Restart Cursor/VS Code after the configuration update
2. Open any `.rs` file
3. You should see clippy warnings highlighted inline

### 2. Pre-commit Hook

**Git pre-commit hook** automatically runs CI/CD checks before each commit:

- **File**: `.git/hooks/pre-commit`
- **Checks**: Format + Clippy with same settings as CI/CD
- **Benefit**: Prevents committing code that will fail CI/CD

**Example output:**
```bash
$ git commit -m "my changes"
Running pre-commit checks...
❌ Clippy check failed!
Please fix the following clippy warnings:
# Shows the same errors as CI/CD
```

### 3. Manual CI/CD Check Script

**Script**: `./scripts/check-ci.sh`

Run the exact same checks as CI/CD manually:

```bash
./scripts/check-ci.sh
```

**What it checks:**
1. Code formatting (`cargo fmt`)
2. Clippy lints (strict mode matching CI/CD)
3. Build (release mode)

**Example output:**
```bash
🔍 Checking code formatting (cargo fmt --all -- --check)
✅ Formatting check passed

🔍 Running clippy (cargo clippy --all-targets --all-features -- -D warnings -D clippy::uninlined-format-args)
❌ Clippy check failed
error: variables can be used directly in the format! string
  --> server/src/goals.rs:36:30
   |
36 |     message: format!("Failed to parse study IDs: {}", e),
   |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
help: change this to
   |
36 +     message: format!("Failed to parse study IDs: {e}"),
```

## Common CI/CD Issues and Fixes

### Format String Warnings (`clippy::uninlined-format-args`)

**Problem**: Using old-style format strings
```rust
❌ format!("Database error: {}", e)
❌ format!("Count: {}", count)
```

**Solution**: Use variables directly in format strings
```rust
✅ format!("Database error: {e}")
✅ format!("Count: {count}")
```

### Other Common Issues

**Unused imports**:
```rust
❌ use std::collections::HashMap; // unused
```

**Dead code**:
```rust
❌ fn unused_function() {} // dead code
```

**Naming conventions**:
```rust
❌ fn to_goal(self) -> Goal {} // should be into_goal for consuming methods
✅ fn into_goal(self) -> Goal {}
```

## Quick Fix Workflow

1. **Run the check script** to see all issues:
   ```bash
   ./scripts/check-ci.sh
   ```

2. **Fix format strings** (most common issue):
   ```bash
   # Find all format string issues
   cargo clippy --all-targets --all-features -- -D clippy::uninlined-format-args
   
   # Fix them by removing {} and using variables directly
   # format!("Error: {}", error) → format!("Error: {error}")
   ```

3. **Fix formatting**:
   ```bash
   cargo fmt --all
   ```

4. **Verify everything passes**:
   ```bash
   ./scripts/check-ci.sh
   ```

## IDE Configuration Details

### Cursor/VS Code Settings

The `.cursor/settings.json` file configures rust-analyzer to use the same clippy settings as CI/CD:

```json
{
  "rust-analyzer.check.command": "clippy",
  "rust-analyzer.check.extraArgs": [
    "--all-targets",
    "--all-features",
    "--",
    "-D", "warnings",
    "-D", "clippy::uninlined-format-args"
  ]
}
```

### Pre-commit Hook Command

The pre-commit hook runs:
```bash
cargo clippy --all-targets --all-features -- -D warnings -D clippy::uninlined-format-args
```

This is **exactly** the same command that CI/CD runs.

## Troubleshooting

### "My editor doesn't show warnings"

1. **Restart your editor** after updating `.cursor/settings.json`
2. **Check rust-analyzer is active**: Look for "rust-analyzer" in the bottom status bar
3. **Open a Rust file**: Warnings only appear in `.rs` files
4. **Wait a moment**: rust-analyzer needs time to analyze the code

### "Pre-commit hook didn't run"

1. **Check hook is executable**:
   ```bash
   ls -la .git/hooks/pre-commit
   # Should show: -rwxr-xr-x (executable)
   ```

2. **Test the hook manually**:
   ```bash
   ./.git/hooks/pre-commit
   ```

### "Local and CI/CD results don't match"

1. **Run our test script**:
   ```bash
   ./scripts/check-ci.sh
   ```

2. **Check Rust version**:
   ```bash
   rustc --version
   # Should match the version in CI/CD
   ```

3. **Update toolchain**:
   ```bash
   rustup update stable
   ```

## Summary

With this setup, you should **never** have CI/CD failures due to linting issues:

- ✅ **Editor** shows warnings as you type
- ✅ **Pre-commit** blocks commits with issues  
- ✅ **Manual script** lets you test before pushing

The goal is to catch **100%** of CI/CD linting issues locally before they reach the pipeline. 