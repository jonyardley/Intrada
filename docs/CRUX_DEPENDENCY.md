# Crux Dependency Management

## 🦀 **Overview**

This project uses [Crux](https://github.com/redbadger/crux) from the published crates on crates.io. This document explains how Crux dependencies are managed.

## 📁 **Current Setup**

### **Published Crates**
```toml
# Cargo.toml (workspace)
[workspace.dependencies]
crux_core = "0.16.0-rc2"
crux_http = "0.15.0-rc2"
```

The project now uses the official Crux crates published on crates.io, eliminating the need for local Git checkouts.

## 🔧 **Environment Handling**

### **Local Development**
- **Dependencies**: Automatically downloaded from crates.io
- **Setup**: Standard `cargo build` - no additional setup required
- **Caching**: Cargo handles dependency caching automatically

### **CI/CD (GitHub Actions)**
- **Dependencies**: Downloaded from crates.io during build
- **No Special Setup**: No additional Crux setup steps needed
- **Caching**: Standard Cargo dependency caching

## 🚀 **Quick Start**

### **For Local Development**
```bash
# Clone the project
git clone https://github.com/your-username/intrada.git
cd intrada

# Build - dependencies downloaded automatically
cargo build
```

### **For CI/CD**
Standard Rust CI/CD workflows work without modification!

## ⚙️ **Version Management**

### **Updating Crux Versions**
```bash
# Update to latest compatible version
cargo update crux_core crux_http

# Or edit Cargo.toml directly
# crux_core = "0.17.0"
# crux_http = "0.16.0"
```

### **Pinning Specific Versions**
```toml
# Pin to exact version
crux_core = "=0.16.0-rc2"

# Use version range
crux_core = "^0.16.0"

# Use pre-release versions
crux_core = "0.17.0-rc1"
```

## 🔄 **Workflow Examples**

### **Standard Development**
```bash
# 1. Clone your project
git clone https://github.com/your-username/intrada.git
cd intrada

# 2. Build project (dependencies downloaded automatically)
cargo build

# 3. Run tests
cargo test
```

### **Upgrading Crux**
```bash
# Check current versions
cargo tree | grep crux

# Update to latest compatible versions
cargo update crux_core crux_http

# Or update everything
cargo update

# Test the upgrade
cargo test
```

## 🏗️ **CI/CD Integration**

### **GitHub Actions Support**
Standard Rust workflows work without modification:

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: dtolnay/rust-toolchain@stable
    - run: cargo test
```

### **Dependency Caching**
```yaml
- name: Cache dependencies
  uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/registry
      ~/.cargo/git
      target/
    key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
```

## 🔍 **Troubleshooting**

### **Common Issues**

**❌ Version conflicts**
```bash
error: failed to select a version for `crux_core`
```
**Solution**: Update Cargo.lock or use compatible versions
```bash
cargo update
```

**❌ Pre-release versions not found**
```bash
error: no matching version found for `crux_core = "0.17.0"`
```
**Solution**: Check available versions on crates.io
```bash
cargo search crux_core
```

**❌ Network issues**
```bash
error: failed to download from `https://crates.io/...`
```
**Solution**: Check network connectivity or use offline mode
```bash
cargo build --offline  # if dependencies already cached
```

### **Debugging Commands**
```bash
# Check current Crux versions
cargo tree | grep crux

# See available versions
cargo search crux_core

# Check for updates
cargo outdated  # if you have cargo-outdated installed

# Clean and rebuild
cargo clean && cargo build
```

## 📋 **Migration History**

### **Previous Setup (Git Dependencies)**
The project previously used local Git checkouts:
- Required `setup-crux.sh` script
- Used path dependencies to `../crux/`
- Required manual Crux repository management

### **Current Setup (Published Crates)**
Now uses standard crates.io dependencies:
- ✅ No setup scripts needed
- ✅ Standard Cargo workflows
- ✅ Automatic dependency resolution
- ✅ Better version management
- ✅ Faster CI builds

## 🎯 **Best Practices**

### **Development**
- Use `cargo update` regularly to get latest compatible versions
- Pin to specific versions for reproducible builds
- Test upgrades thoroughly before deploying

### **CI/CD**  
- Cache Cargo dependencies for faster builds
- Use `Cargo.lock` for reproducible builds
- Test against multiple Rust versions if needed

### **Team Collaboration**
- Commit `Cargo.lock` to ensure consistent builds
- Document any version requirements in README
- Use semantic versioning for your own releases

## 📚 **Additional Resources**

- **[Crux Documentation](https://redbadger.github.io/crux/)**
- **[Cargo Dependencies](https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html)**
- **[Semantic Versioning](https://semver.org/)**
- **[crates.io](https://crates.io/search?q=crux)**

---

*Using published crates makes dependency management much simpler and more reliable!* 🚀