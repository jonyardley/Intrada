# Configuration Management

Intrada uses a comprehensive configuration system that supports multiple environments and secure configuration management across iOS and Rust core components.

## Overview

The configuration system provides:
- **Environment-based configuration** (development, staging, production)
- **Build-configuration awareness** (Debug builds use development, Release builds use production)
- **Shared configuration** between iOS app and Rust core
- **Type-safe configuration** access with sensible defaults

## iOS Configuration

### Configuration File Structure

The iOS app uses `Config.plist` for environment configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Environments</key>
    <dict>
        <key>development</key>
        <dict>
            <key>ServerBaseURL</key>
            <string>http://localhost:3000</string>
            <key>DisplayName</key>
            <string>Intrada (Dev)</string>
        </dict>
        <key>staging</key>
        <dict>
            <key>ServerBaseURL</key>
            <string>https://staging.intrada.app</string>
            <key>DisplayName</key>
            <string>Intrada (Staging)</string>
        </dict>
        <key>production</key>
        <dict>
            <key>ServerBaseURL</key>
            <string>https://api.intrada.app</string>
            <key>DisplayName</key>
            <string>Intrada</string>
        </dict>
    </dict>
    <key>CurrentEnvironment</key>
    <string>development</string>
</dict>
</plist>
```

### ConfigurationManager Usage

```swift
// Get the current environment configuration
let config = ConfigurationManager.shared

// Access configuration values
let serverURL = config.serverBaseURL
let appName = config.displayName
let env = config.environment

// Check environment
if config.isDevelopment {
    print("Running in development mode")
}
```

### Environment Detection

- **Debug builds**: Use `CurrentEnvironment` from Config.plist (allows switching environments for development)
- **Release builds**: Always use `production` environment (security best practice)

## Rust Core Configuration

### ApiConfig Usage

```rust
use shared::app::{ApiConfig, Environment};

// Create configuration for specific environment
let config = ApiConfig::for_environment(Environment::Production);

// Create from environment string
let config = ApiConfig::from_env_string("staging");

// Use with HTTP requests
let url = config.url("/api/goals");
let get_command = config.get("/api/goals", handle_response);
```

### Environment Types

```rust
pub enum Environment {
    Development,  // http://localhost:3000
    Staging,     // https://staging.intrada.app  
    Production,  // https://api.intrada.app
}
```

## Configuration Setup

### 1. iOS Setup

1. Copy `Config.plist.template` to `Config.plist`
2. Update URLs for your specific deployment
3. Add `Config.plist` to your Xcode project
4. **Never commit sensitive production URLs** to version control

### 2. Environment URLs

Update the URLs in both:
- `iOS/Intrada/Config.plist` (for iOS app)
- `shared/src/app/http_utils.rs` (for Rust core defaults)

### 3. Development Workflow

**For Development:**
- Set `CurrentEnvironment` to `"development"` in Config.plist
- Server runs on `http://localhost:3000`
- App displays as "Intrada (Dev)"

**For Staging:**
- Set `CurrentEnvironment` to `"staging"` in Config.plist  
- Points to staging server
- App displays as "Intrada (Staging)"

**For Production:**
- Release builds automatically use production environment
- Points to production server
- App displays as "Intrada"

## Security Best Practices

1. **Use Config.plist.template**: Keep sensitive URLs out of version control
2. **Environment separation**: Never let development builds hit production APIs
3. **Build configuration enforcement**: Release builds always use production
4. **URL validation**: Configuration system validates URLs and provides defaults

## Testing

The configuration system includes comprehensive tests:

```bash
# Test Rust configuration
cargo test --package shared http_utils

# Test iOS configuration  
# (Run iOS unit tests in Xcode)
```

## Troubleshooting

**iOS app can't connect to server:**
1. Check `Config.plist` exists and has correct URL
2. For development: ensure local server is running on port 3000
3. Check console logs for configuration loading messages

**Configuration not loading:**
1. Verify `Config.plist` is added to Xcode project
2. Check file permissions
3. Look for warning messages in console

**Environment not switching:**
1. For Debug builds: check `CurrentEnvironment` in Config.plist
2. For Release builds: environment is always `production` (by design)
3. Clean and rebuild project