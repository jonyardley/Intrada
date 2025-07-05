# Scripts Directory

This directory contains essential automation scripts for managing your Appwrite infrastructure.

## 🚀 Main Scripts

### `setup-appwrite-complete.sh`
**The primary setup script** - Run this for complete Appwrite environment setup.

**What it does:**
- Starts Docker containers
- Creates/validates API keys
- Deploys database schema
- Registers platforms (iOS/Web)
- Creates environment configuration
- Verifies complete setup

**Usage:**
```bash
./scripts/setup-appwrite-complete.sh [api-key]
```

### `setup-platforms-simple.sh`
**Platform registration fallback** - Use when platform registration fails in main script.

**What it does:**
- Registers iOS and Web platforms via direct API
- Multiple fallback methods
- Checks for existing platforms
- Smart error handling

**Usage:**
```bash
./scripts/setup-platforms-simple.sh
```

### `teardown-local-appwrite.sh`
**Complete cleanup** - Removes all Docker containers, volumes, and local config.

**What it does:**
- Stops and removes containers
- Cleans up volumes and networks
- Removes local environment files
- Resets CLI configuration

**Usage:**
```bash
./scripts/teardown-local-appwrite.sh
```

## 🔧 Typical Workflow

1. **Initial Setup:**
   ```bash
   ./scripts/setup-appwrite-complete.sh
   ```

2. **If platform registration fails:**
   ```bash
   ./scripts/setup-platforms-simple.sh
   ```

3. **Clean slate for testing:**
   ```bash
   ./scripts/teardown-local-appwrite.sh
   ./scripts/setup-appwrite-complete.sh
   ```

## 📋 Removed Scripts

The following scripts were consolidated or removed:
- ❌ `setup-platforms.sh` - Functionality moved to `setup-appwrite-complete.sh`
- ❌ `setup-platforms-docker.sh` - Complex workaround no longer needed
- ❌ `deploy-schema.sh` - Auto-generated, functionality in CLI tool

For advanced schema deployment, use the CLI tool directly:
```bash
cd infrastructure
cargo run --bin appwrite_cli deploy --environment dev
``` 