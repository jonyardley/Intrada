# Pre-commit Hooks for Intrada

This document describes the pre-commit hooks set up for the Intrada project to ensure code quality and prevent pipeline failures.

## Overview

The pre-commit hooks automatically run the following checks when you try to commit:
- **Rust Formatting**: Checks that all Rust code is formatted according to the project's `rustfmt.toml` configuration
- **Clippy Linting**: Runs Clippy to catch common Rust mistakes and enforce best practices (treating warnings as errors)

## Automatic Setup

The pre-commit hooks are automatically set up in the `.git/hooks/pre-commit` file and will run on every commit attempt. The hooks only run if there are staged Rust files (`.rs` files) to avoid unnecessary processing.

## Hook Behavior

### When Checks Pass ✅
- The commit proceeds normally
- You'll see green checkmarks for each successful check

### When Checks Fail ❌
- The commit is blocked
- You'll see detailed error messages showing what needs to be fixed
- The hook provides quick fix suggestions

## Manual Testing

You can manually run the same checks that the pre-commit hook uses:

```bash
# Run all checks (formatting, linting, and tests)
./scripts/check-code.sh

# Or run individual checks
cargo fmt --all --check        # Check formatting
cargo clippy --all-targets --all-features -- -D warnings  # Check lints
cargo test --all              # Run tests
```

## Quick Fixes

### Formatting Issues
```bash
cargo fmt --all
```

### Clippy Warnings
Fix the specific warnings shown in the output. Common fixes:
- Remove unused variables/imports
- Add missing `#[allow(dead_code)]` attributes if the code is intentionally unused
- Follow Clippy's suggestions for better code patterns

## Configuration Files

The hooks use the following configuration files:
- `rustfmt.toml`: Formatting rules (100 char line width, 4 spaces, etc.)
- `clippy.toml`: Linting rules (complexity thresholds, allowed patterns, etc.)

## Bypassing Hooks (Not Recommended)

In rare cases where you need to bypass the hooks (e.g., for emergency fixes), you can use:

```bash
git commit --no-verify
```

**Warning**: Only use this in emergencies, as it will likely cause the CI/CD pipeline to fail.

## Troubleshooting

### Hook Not Running
- Ensure the hook file exists: `.git/hooks/pre-commit`
- Ensure it's executable: `chmod +x .git/hooks/pre-commit`

### Hook Failing on Non-Rust Changes
- The hook should automatically skip when no Rust files are staged
- If it's still running, check the `has_rust_changes()` function in the hook

### Performance Issues
- The hook only runs on staged Rust files to minimize processing time
- Large projects may take longer; consider running checks manually first

## Integration with IDE

For the best development experience, configure your IDE to run `cargo fmt` on save and show Clippy warnings inline. This prevents most issues from reaching the pre-commit stage.

### VS Code/Cursor
Add to your settings:
```json
{
  "rust-analyzer.check.command": "clippy",
  "rust-analyzer.check.extraArgs": ["--", "-D", "warnings"],
  "editor.formatOnSave": true
}
```

This ensures the same standards are maintained during development as in the pre-commit hooks. 