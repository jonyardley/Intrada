# iOS Testing Guide

## 🍎 **iOS Development & Testing Workflow**

This guide covers how to build, test, and deploy your iOS app across different environments, including testing against production without requiring a paid Apple Developer account.

## 🏗️ **Build Architecture**

### **Cross-Platform Core**
- **Shared Rust Logic**: Core business logic lives in `shared/` crate
- **UniFFI Bindings**: Automatic Swift binding generation from Rust
- **Platform-Specific UI**: Native SwiftUI interface in `iOS/`

### **Environment Configuration**
- **Development**: `com.jonyardley.Intrada.dev` → Development backend
- **Production**: `com.jonyardley.Intrada` → Production backend  
- **Configuration**: Dynamic via `Config.plist` generation

## 🚀 **GitHub Actions Workflow**

### **Automatic Builds**
Your iOS app builds automatically on:
- **Push to any branch**: Tests against development environment
- **Push to main**: Tests against production environment
- **Pull requests**: Dry-run validation only

### **Build Process**
1. **Rust Library**: Builds universal iOS library (`libshared.a`)
2. **Swift Bindings**: Generates Swift bindings from Rust types
3. **iOS App**: Compiles Swift app with proper configuration
4. **Testing**: Runs unit tests and integration tests
5. **Artifacts**: Uploads built app for download

### **Environment Detection**
```yaml
# Main branch = Production
main → production environment
  ├── Bundle ID: com.jonyardley.Intrada
  ├── Backend: Production Appwrite
  └── Config: Production secrets

# Other branches = Development  
feature/*, develop, etc → development environment
  ├── Bundle ID: com.jonyardley.Intrada.dev
  ├── Backend: Local Docker Appwrite
  └── Config: Local development
```

## 🧪 **Testing Without Paid Apple Account**

### **What You Can Do**
✅ **iOS Simulator Testing**: Full functionality in simulator
✅ **Production Backend Testing**: App connects to live production data
✅ **Automated Testing**: Complete test suite via GitHub Actions
✅ **Local Development**: Full development environment

### **What You Cannot Do**
❌ **Physical Device Testing**: Requires Apple Developer Program
❌ **App Store Distribution**: Requires paid account and certificates
❌ **TestFlight**: Requires paid Apple Developer account

## 📱 **Local iOS Testing**

### **Quick Start**
```bash
# Test against production environment
./scripts/test-ios-production.sh

# This script will:
# ✅ Build Rust library for iOS
# ✅ Generate Swift bindings  
# ✅ Create production Config.plist
# ✅ Build iOS app
# ✅ Install in iOS Simulator
# ✅ Run tests
```

### **Manual Development**
```bash
# 1. Build Rust library
cd shared
cargo lipo --release --targets aarch64-apple-ios,aarch64-apple-ios-sim,x86_64-apple-ios

# 2. Generate Swift bindings
cargo run --bin uniffi-bindgen generate src/shared.udl --language swift --out-dir ../iOS/Generated/

# 3. Open in Xcode
cd ../iOS
open Intrada.xcodeproj

# 4. Build and run in simulator
# Select iOS Simulator → iPhone 15 Pro
# Press Cmd+R to build and run
```

## 🔧 **Configuration Management**

### **Environment-Specific Config**
Your app automatically configures itself based on build environment:

**Development Config** (`Config.plist`):
```xml
<dict>
    <key>AppwriteEndpoint</key>
    <string>http://localhost/v1</string>
    <key>AppwriteProjectId</key>
    <string>intrada-dev</string>
    <key>Environment</key>
    <string>development</string>
</dict>
```

**Production Config** (`Config.plist`):
```xml
<dict>
    <key>AppwriteEndpoint</key>
    <string>https://cloud.appwrite.io/v1</string>
    <key>AppwriteProjectId</key>
    <string>intrada-prod</string>
    <key>Environment</key>
    <string>production</string>
</dict>
```

### **Reading Config in Swift**
```swift
// The app automatically reads Config.plist
let config = AppConfiguration.current
let endpoint = config.appwriteEndpoint
let projectId = config.appwriteProjectId
```

## 🎯 **Testing Strategies**

### **1. Unit Tests**
- **Location**: `iOS/IntradaTests/`
- **Focus**: Individual component testing
- **Environment**: Mock/isolated

```bash
# Run unit tests
cd iOS
xcodebuild test -scheme Intrada -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### **2. Integration Tests**
- **Location**: `iOS/IntradaIntegrationTests/`
- **Focus**: Backend connectivity
- **Environment**: Live backend (dev/prod)

```bash
# Run integration tests against development
xcodebuild test -scheme Intrada -testPlan IntegrationTests

# Run integration tests against production
ENVIRONMENT=production xcodebuild test -scheme Intrada -testPlan IntegrationTests
```

### **3. UI Tests**
- **Location**: `iOS/IntradaUITests/`
- **Focus**: End-to-end user flows
- **Environment**: Full app with backend

```bash
# Run UI tests
xcodebuild test -scheme Intrada -testPlan UITests
```

## 🔄 **Development Workflow**

### **Feature Development**
```bash
# 1. Create feature branch
git checkout -b feature/new-ios-feature

# 2. Make changes to shared Rust code
# Edit shared/src/app/

# 3. Update iOS Swift code
# Edit iOS/Intrada/

# 4. Test locally
./scripts/test-ios-production.sh

# 5. Push and let CI test
git push origin feature/new-ios-feature
# → GitHub Actions builds and tests automatically
```

### **Production Testing**
```bash
# 1. Test locally against production
./scripts/test-ios-production.sh

# 2. Create PR to main
gh pr create --title "iOS Feature Ready"
# → Shows dry-run of production deployment

# 3. Merge to main
gh pr merge
# → Deploys to production and tests iOS app
```

## 📊 **Monitoring & Debugging**

### **GitHub Actions Logs**
- **Build Logs**: See iOS compilation output
- **Test Results**: Unit and integration test results
- **Artifacts**: Download built `.app` files

### **Local Debugging**
```bash
# Check iOS Simulator logs
xcrun simctl spawn booted log stream --level debug

# Check Appwrite connectivity
curl -s http://localhost/v1/health | jq

# Check production connectivity  
curl -s https://cloud.appwrite.io/v1/health | jq
```

### **Xcode Debugging**
- **Breakpoints**: Set in Swift code
- **Console**: `print()` statements appear in Xcode console
- **Network**: Use Network tab in Xcode to monitor API calls

## 🔒 **Security & Certificates**

### **Current Setup (No Paid Account)**
- **Code Signing**: Disabled for simulator builds
- **Bundle ID**: Uses development suffix (`.dev`)
- **Provisioning**: Not required for simulator

### **Future Setup (With Paid Account)**
```bash
# 1. Join Apple Developer Program ($99/year)
# 2. Create App ID in Apple Developer Portal
# 3. Generate development certificates
# 4. Create provisioning profiles
# 5. Configure Xcode signing

# Then you can:
# ✅ Install on physical devices
# ✅ Distribute via TestFlight
# ✅ Submit to App Store
```

## 🚨 **Troubleshooting**

### **Common Issues**

**Build Failures**:
```bash
# Clean build
cd iOS
xcodebuild clean

# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/
```

**Missing Swift Bindings**:
```bash
# Regenerate bindings
cd shared
cargo run --bin uniffi-bindgen generate src/shared.udl --language swift --out-dir ../iOS/Generated/
```

**Simulator Issues**:
```bash
# Reset simulator
xcrun simctl erase all

# Restart simulator
sudo killall Simulator
open -a Simulator
```

### **Environment Problems**

**Local Development Issues**:
```bash
# Check Docker is running
docker ps

# Restart Appwrite
docker compose down -v
docker compose up -d
```

**Production Connection Issues**:
```bash
# Check production health
curl -s https://cloud.appwrite.io/v1/health

# Verify project ID and endpoint in Config.plist
cat iOS/Intrada/Config.plist
```

## 📋 **Test Checklist**

Before releasing iOS features:

### **Development Testing**
- [ ] Unit tests pass locally
- [ ] Integration tests pass against local backend
- [ ] UI tests work in simulator
- [ ] App runs without crashes
- [ ] All screens load correctly

### **Production Testing**
- [ ] Integration tests pass against production
- [ ] Data loads from production backend
- [ ] Authentication works
- [ ] Core features function correctly
- [ ] Error handling works properly

### **CI/CD Validation**
- [ ] GitHub Actions build passes
- [ ] All automated tests pass
- [ ] Artifacts are generated
- [ ] No code signing errors
- [ ] Environment detection works

## 🚀 **Next Steps**

### **Immediate (Free)**
1. **Test Core Features**: Use simulator to test all functionality
2. **Production Validation**: Run integration tests against production
3. **Performance Testing**: Monitor app performance in simulator

### **Future (Paid Account)**
1. **Device Testing**: Test on physical devices
2. **TestFlight**: Beta testing with real users
3. **App Store**: Submit for distribution

### **Advanced Features**
1. **Automated Screenshots**: Generate App Store screenshots
2. **Crash Reporting**: Integrate crash analytics
3. **Performance Monitoring**: Add performance metrics

## 📚 **Additional Resources**

- **[Rust-iOS Guide](https://mozilla.github.io/uniffi-rs/swift/overview.html)**: UniFFI Swift bindings
- **[Xcode Testing](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)**: Apple's testing guide
- **[GitHub Actions iOS](https://docs.github.com/en/actions/using-workflows/using-github-actions-for-continuous-integration#building-and-testing-objective-c-and-swift)**: iOS CI/CD
- **[Appwrite iOS SDK](https://appwrite.io/docs/getting-started-for-ios)**: Backend integration

---

*Your iOS app is now fully configured for testing against production without requiring a paid Apple Developer account!* 🎉