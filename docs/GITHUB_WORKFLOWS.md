# GitHub Actions Workflows

## 🚀 **Overview**

This document describes our comprehensive GitHub Actions workflows for CI/CD, testing, and deployment.

## 📋 **Workflow Summary**

| Workflow | Purpose | Triggers | Environment |
|----------|---------|----------|-------------|
| **Appwrite CI/CD** | Backend deployment & testing | Push/PR to main branches | Development/Production |
| **iOS Build & Test** | iOS app compilation & testing | iOS code changes | Simulator-based testing |
| **Test Crux Setup** | Validate Crux dependency setup | Manual/Crux changes | Dependency validation |

## 🏗️ **Appwrite CI/CD Workflow**

### **File**: `.github/workflows/appwrite-ci.yml`

### **Purpose**
Comprehensive CI/CD pipeline for Appwrite backend infrastructure with environment-specific deployments.

### **Key Features**
- ✅ **Parallel Testing & Deployment**: Separate jobs for testing and deployment
- ✅ **Environment Detection**: Automatic detection based on branch
- ✅ **Concurrency Control**: Prevents conflicting deployments
- ✅ **Dry-Run Support**: PRs show deployment preview without executing
- ✅ **Comprehensive Testing**: Format, clippy, unit tests, and validation

### **Triggers**
```yaml
on:
  push:
    branches: [ main, develop, appwrite-config, 'feature/**' ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:
```

### **Environment Logic**
- **Main Branch** → Production environment
- **Other Branches** → Development environment
- **Manual Override** → Configurable via workflow_dispatch

### **Jobs Architecture**

#### **1. Test Job**
- **Duration**: ~5-10 minutes
- **Purpose**: Validate code quality and compilation
- **Steps**:
  1. Environment detection via script
  2. Crux dependency setup
  3. Rust toolchain with clippy/rustfmt
  4. Code formatting check
  5. Clippy linting
  6. Unit tests
  7. CLI tool build

#### **2. Deploy Job** (Push events only)
- **Duration**: ~10-15 minutes
- **Purpose**: Deploy to target environment
- **Dependencies**: Requires test job success
- **Steps**:
  1. Environment-specific Docker setup (dev only)
  2. Appwrite project setup
  3. Schema validation
  4. Schema deployment
  5. Platform deployment
  6. Deployment verification
  7. Integration tests

#### **3. Dry-Run Job** (PR events only)
- **Duration**: ~5 minutes
- **Purpose**: Show deployment preview
- **Steps**:
  1. Schema validation
  2. Dry-run deployment commands
  3. Generate summary report

### **Environment Configuration**

#### **Development Environment**
- **Trigger**: Any branch except main
- **Appwrite**: Local Docker instance
- **Project ID**: `intrada-dev`
- **Endpoint**: `http://localhost/v1`
- **Secrets**: Auto-generated API keys

#### **Production Environment**
- **Trigger**: Main branch only
- **Appwrite**: Cloud instance
- **Project ID**: From `APPWRITE_PROJECT_ID_PROD` secret
- **Endpoint**: From `APPWRITE_ENDPOINT_PROD` secret
- **Secrets**: `APPWRITE_API_KEY_PROD`

## 🍎 **iOS Build & Test Workflow**

### **File**: `.github/workflows/ios-build.yml`

### **Purpose**
Build and test iOS application with proper Rust/Crux dependencies for cross-platform architecture.

### **Key Features**
- ✅ **Comprehensive iOS Build**: Debug and Release configurations
- ✅ **Rust Integration**: Builds shared library for iOS targets
- ✅ **Swift Bindings**: Generates UniFFI bindings automatically
- ✅ **Environment Testing**: Tests against development/production backends
- ✅ **Artifact Management**: Uploads build artifacts for download

### **Critical Dependencies Verified**

#### **Why iOS Needs Rust & Crux**
```rust
// shared/Cargo.toml - The iOS app depends on this Rust library
[lib]
crate-type = ["lib", "staticlib", "cdylib"]  // staticlib for iOS

[dependencies]
crux_core.workspace = true     // Required: Core Crux framework
crux_http = { path = "../../crux/crux_http" }  // Required: HTTP capability
uniffi = "0.29.3"             // Required: Swift bindings
```

The iOS app **requires**:
1. **Rust Toolchain**: To compile `shared` crate as `libshared.a`
2. **Crux Dependencies**: `crux_core` and `crux_http` used by shared library
3. **UniFFI**: To generate Swift bindings from Rust
4. **iOS Targets**: `aarch64-apple-ios`, `aarch64-apple-ios-sim`, `x86_64-apple-ios`

### **Build Process**
1. **Environment Detection**: Production vs Development configuration
2. **Crux Setup**: Ensures local Crux dependencies available
3. **Rust Compilation**: Builds universal iOS library (`libshared.a`)
4. **Swift Bindings**: Generates Swift interface from Rust UDL
5. **iOS Configuration**: Creates `Config.plist` for environment
6. **iOS Compilation**: Debug and Release builds
7. **Testing**: Unit tests and integration tests
8. **Archiving**: Creates .xcarchive for main branch

### **Configurations**

#### **Development Configuration**
```xml
<key>AppwriteEndpoint</key>
<string>http://localhost/v1</string>
<key>Environment</key>
<string>development</string>
```

#### **Production Configuration**
```xml
<key>AppwriteEndpoint</key>
<string>https://cloud.appwrite.io/v1</string>
<key>Environment</key>
<string>production</string>
```

### **Caching Strategy**
- **Rust Dependencies**: `~/.cargo/registry`, `~/.cargo/git`, `shared/target`
- **Xcode Derived Data**: `~/Library/Developer/Xcode/DerivedData`
- **Cache Keys**: Include Cargo.lock and Swift file hashes

## 🦀 **Test Crux Setup Workflow**

### **File**: `.github/workflows/test-crux-setup.yml`

### **Purpose**
Validates that Crux dependency setup works correctly across different configurations.

### **Key Features**
- ✅ **Manual Testing**: Can be triggered manually with custom parameters
- ✅ **Automatic Testing**: Runs on Crux setup changes
- ✅ **Matrix Support**: Test multiple Crux versions
- ✅ **Performance Monitoring**: Measures setup time
- ✅ **Comprehensive Validation**: Tests all compilation targets

### **Test Coverage**
1. **Crux Setup Verification**: Validates directory structure and files
2. **Workspace Compilation**: Tests entire workspace builds
3. **Shared Library**: Validates iOS-specific compilation
4. **Infrastructure**: Tests CLI tool compilation
5. **Dependency Resolution**: Verifies Crux dependencies resolve correctly

## 🛠️ **Supporting Scripts**

### **Environment Detection** (`.github/scripts/detect-environment.sh`)
- **Purpose**: Centralized environment detection logic
- **Inputs**: GitHub ref, event type, manual override
- **Outputs**: Environment variables for workflows
- **Features**: Production/development detection, bundle ID assignment

### **Appwrite Project Setup** (`.github/scripts/setup-appwrite-project.sh`)
- **Purpose**: Automated Appwrite project creation for development
- **Features**: Project creation, API key generation, health checks
- **Environment**: Development environments only

### **iOS Configuration** (`.github/scripts/generate-ios-config.sh`)
- **Purpose**: Generate iOS Config.plist files
- **Features**: Environment-specific configuration, plist validation
- **Outputs**: Ready-to-use iOS configuration files

## 📊 **Workflow Optimization**

### **Performance Improvements**
1. **Parallel Jobs**: Testing and deployment run in parallel where possible
2. **Smart Caching**: Separate cache keys for different purposes
3. **Conditional Steps**: Skip unnecessary steps based on environment
4. **Concurrency Control**: Prevent resource conflicts

### **Caching Strategy**
```yaml
# Rust dependencies (shared across workflows)
key: ${{ runner.os }}-rust-${{ hashFiles('**/Cargo.lock') }}-v2

# iOS-specific Rust cache
key: ${{ runner.os }}-ios-rust-${{ hashFiles('shared/Cargo.lock') }}-v2

# Xcode derived data
key: ${{ runner.os }}-xcode-derived-${{ hashFiles('iOS/**/*.swift', 'iOS/**/*.xcodeproj/**') }}-v2
```

### **Action Versions (Standardized)**
- `actions/checkout@v4` - Code checkout
- `actions/cache@v4` - Caching
- `actions/upload-artifact@v4` - Artifact upload
- `dtolnay/rust-toolchain@stable` - Rust setup
- `maxim-lobanov/setup-xcode@v1` - Xcode setup

## 🔍 **Monitoring & Debugging**

### **Workflow Summaries**
Each workflow generates comprehensive summaries showing:
- **Configuration**: Environment, branch, commit details
- **Build Status**: Success/failure of each step
- **Dependencies**: Verification of required components
- **Next Steps**: Actionable items based on results

### **Artifact Management**
- **iOS Builds**: App bundles and archives (7-day retention)
- **Build Logs**: Accessible via GitHub Actions interface
- **Configuration Files**: Config.plist files for debugging

### **Error Handling**
- **Graceful Failures**: Continues where possible with warnings
- **Clear Error Messages**: Descriptive failure reasons
- **Cleanup Steps**: Always runs cleanup even on failure

## 🚦 **Status Indicators**

### **Branch Protection**
Workflows serve as required status checks for:
- **Main Branch**: Both Appwrite CI/CD and iOS Build must pass
- **Feature Branches**: Tests must pass before merge

### **Environment Protection**
- **Production**: Requires manual approval for sensitive operations
- **Development**: Automatic deployment for faster iteration

## 🔧 **Configuration Management**

### **Required Secrets**
```bash
# Production Environment
APPWRITE_ENDPOINT_PROD=https://your-production-endpoint/v1
APPWRITE_PROJECT_ID_PROD=your-production-project-id
APPWRITE_API_KEY_PROD=your-production-api-key

# Development Environment (Optional)
APPWRITE_ENDPOINT_DEV=http://localhost/v1  # Default fallback
APPWRITE_PROJECT_ID_DEV=intrada-dev        # Default fallback
```

### **Environment Variables**
- **Configurable**: Xcode version, Crux repository, timeouts
- **Defaults**: Sensible defaults for all optional parameters
- **Override Support**: Manual workflow dispatch allows customization

## 📈 **Performance Metrics**

### **Typical Durations**
- **Appwrite CI/CD Test**: 5-10 minutes
- **Appwrite CI/CD Deploy**: 10-15 minutes  
- **iOS Build & Test**: 15-25 minutes
- **Crux Setup Test**: 3-5 minutes

### **Optimization Opportunities**
1. **Parallel Matrix Builds**: Test multiple iOS versions simultaneously
2. **Incremental Builds**: Only rebuild changed components
3. **Cache Warming**: Pre-populate caches during low-usage periods

## 🚀 **Usage Examples**

### **Manual Deployment**
```bash
# Trigger manual deployment to production
gh workflow run "Appwrite CI/CD" --ref main --field environment=production

# Test iOS app against production
gh workflow run "iOS Build & Test" --ref main --field test_environment=production

# Test specific Crux version
gh workflow run "Test Crux Setup" --field crux_ref=v0.16.0
```

### **Feature Development**
```bash
# Create feature branch
git checkout -b feature/new-feature

# Push changes (triggers automatic CI)
git push origin feature/new-feature
# → Runs: Appwrite CI/CD (development), iOS Build (development)

# Create PR (triggers dry-run)
gh pr create --title "New feature"
# → Shows: Deployment preview, build status
```

## 🔄 **Migration & Updates**

### **Updating Workflows**
1. **Test Changes**: Use test-crux-setup workflow to validate
2. **Staged Rollout**: Test on feature branches first
3. **Monitor Performance**: Check for regression in build times
4. **Update Documentation**: Keep this document current

### **Dependency Updates**
- **Crux Updates**: Change `CRUX_REF` in workflow configurations
- **Rust Updates**: Update `rust-toolchain.toml` and workflows will adapt
- **Action Updates**: Update action versions across all workflows

---

*These workflows ensure consistent, reliable builds and deployments across all environments and platforms.* 🎉