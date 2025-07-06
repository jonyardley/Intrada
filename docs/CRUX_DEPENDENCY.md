# Crux Dependency Management

## 🦀 **Overview**

This project uses a local version of [Crux](https://github.com/redbadger/crux) that is not yet published to crates.io. This document explains how Crux is managed across different environments.

## 📁 **Current Setup**

### **Local Development**
```toml
# Cargo.toml (workspace)
[workspace.dependencies]
crux_core = { path = "../crux/crux_core" }

# shared/Cargo.toml
crux_http = { path = "../../crux/crux_http" }
```

Your local project expects Crux to be available at `../crux/` relative to the project root.

## 🔧 **Environment Handling**

### **Local Development**
- **Expected Path**: `../crux/` (parallel to your project directory)
- **Setup**: Run `make setup-crux` or `./scripts/setup-crux.sh`
- **Fallback**: Automatically clones Crux if not found locally

### **CI/CD (GitHub Actions)**
- **Automatic Setup**: Clones Crux from GitHub automatically
- **Repository**: `redbadger/crux`
- **Branch**: `main` (configurable)
- **Path**: `../crux/` (consistent with local development)

## 🚀 **Quick Start**

### **For Local Development**
```bash
# Option 1: Use Make target
make setup-crux

# Option 2: Run script directly  
./scripts/setup-crux.sh

# Option 3: Manual setup (if you want to modify Crux)
cd ..
git clone https://github.com/redbadger/crux.git
cd crux
# Make any local modifications to Crux here
```

### **For CI/CD**
No action needed! The GitHub Actions workflows automatically handle Crux setup.

## ⚙️ **Configuration Options**

### **Environment Variables**
You can customize Crux setup using environment variables:

```bash
# Use a specific Crux repository (e.g., your fork)
export CRUX_REPO="your-username/crux"

# Use a specific branch/tag/commit
export CRUX_REF="feature-branch"

# Use a different path (not recommended)
export CRUX_PATH="../my-custom-crux"

# Then run setup
./scripts/setup-crux.sh
```

### **GitHub Actions Configuration**
```yaml
# .github/workflows/appwrite-ci.yml
- name: Setup Crux dependency
  run: ./scripts/setup-crux.sh
  env:
    CI: true
    CRUX_REPO: "redbadger/crux"      # Use your fork if needed
    CRUX_REF: "main"                 # Use specific branch/tag
    CRUX_PATH: "../crux"
```

## 🔄 **Workflow Examples**

### **Standard Development**
```bash
# 1. Clone your project
git clone https://github.com/your-username/intrada.git
cd intrada

# 2. Setup Crux dependency
make setup-crux

# 3. Build project
cargo build
```

### **Developing with Local Crux Changes**
```bash
# 1. Setup with manual Crux clone
cd ..
git clone https://github.com/redbadger/crux.git
cd crux

# 2. Make your changes to Crux
git checkout -b my-feature
# Edit crux_core or crux_http...
git commit -m "My Crux improvements"

# 3. Build your project (uses your local changes)
cd ../intrada
cargo build
```

### **Using a Specific Crux Version**
```bash
# Use a specific commit/tag
CRUX_REF="v0.7.0" ./scripts/setup-crux.sh

# Use a feature branch
CRUX_REF="feature/new-capability" ./scripts/setup-crux.sh
```

## 🏗️ **CI/CD Integration**

### **GitHub Actions Support**
The workflows automatically:
1. **Clone Crux**: Downloads the specified version
2. **Verify Setup**: Ensures all required crates are available
3. **Build Project**: Uses the local Crux for compilation
4. **Cache Dependencies**: Speeds up subsequent builds

### **Build Matrix Support**
You can test against multiple Crux versions:

```yaml
strategy:
  matrix:
    crux-ref: ["main", "v0.7.0", "develop"]
    
steps:
- name: Setup Crux dependency
  env:
    CRUX_REF: ${{ matrix.crux-ref }}
  run: ./scripts/setup-crux.sh
```

## 🔍 **Troubleshooting**

### **Common Issues**

**❌ Crux not found**
```bash
error[E0463]: can't find crate for `crux_core`
```
**Solution**: Run `make setup-crux` or verify `../crux/` exists

**❌ Wrong Crux version** 
```bash
error: trait `SomeFeature` is not implemented
```
**Solution**: Update Crux to compatible version
```bash
cd ../crux
git pull origin main
cd ../intrada
cargo clean && cargo build
```

**❌ CI build failing**
```bash
fatal: repository 'https://github.com/invalid/crux.git' not found
```
**Solution**: Check `CRUX_REPO` environment variable in workflow

### **Debugging Commands**
```bash
# Check Crux status
ls -la ../crux/
cat ../crux/Cargo.toml | grep name

# Verify Crux version
cd ../crux && git log --oneline -5

# Check workspace dependencies
cargo tree | grep crux

# Clean rebuild
cargo clean && cargo build
```

## 📋 **Migration Strategies**

### **When Crux is Published**
Once Crux releases are available on crates.io:

1. **Update Cargo.toml**:
```toml
# From:
crux_core = { path = "../crux/crux_core" }

# To:
crux_core = "0.8.0"
```

2. **Remove local setup**:
```bash
# Remove from Makefile
sed -i '/setup-crux/d' Makefile

# Remove from workflows
# Delete CRUX setup steps from .github/workflows/
```

3. **Clean up**:
```bash
rm scripts/setup-crux.sh
rm .github/crux-config.yml
rm docs/CRUX_DEPENDENCY.md
```

### **Using Git Dependencies**
Alternative approach using Cargo's git support:

```toml
# Cargo.toml
crux_core = { git = "https://github.com/redbadger/crux", rev = "main" }
crux_http = { git = "https://github.com/redbadger/crux", rev = "main" }
```

**Pros**: No local setup needed
**Cons**: Harder to develop with local Crux changes

## 🎯 **Best Practices**

### **Development**
- Use `make setup-crux` for consistent setup
- Pin to specific Crux commits for reproducible builds
- Test CI builds before merging changes

### **CI/CD**  
- Cache Rust dependencies to speed up builds
- Use specific Crux versions rather than `main` for stability
- Test against multiple Crux versions if needed

### **Team Collaboration**
- Document any Crux version requirements
- Share Crux commit hashes for consistent development
- Consider using a Crux fork for team-specific changes

## 📚 **Additional Resources**

- **[Crux Documentation](https://redbadger.github.io/crux/)**
- **[Cargo Path Dependencies](https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html#specifying-path-dependencies)**
- **[GitHub Actions with Rust](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-rust)**

---

*This setup ensures your project can build consistently across local development and CI/CD environments while using the latest Crux features!* 🚀