# Appwrite CLI Tool

The Intrada Appwrite CLI is a type-safe infrastructure-as-code tool for managing your Appwrite backend configuration. It generates schemas from Rust types and deploys them to Appwrite instances.

## Installation

Build the CLI tool:
```bash
cd infrastructure
cargo build --bin appwrite_cli --features cli --release
```

The binary will be available at `infrastructure/target/release/appwrite_cli`.

## Configuration

### Environment Variables

Create a `.env.local` file (see `.env.example` for template):

```bash
# Required
APPWRITE_ENDPOINT=http://localhost/v1
APPWRITE_PROJECT_ID=intrada-dev
APPWRITE_API_KEY=your-api-key-here

# Platform Configuration (Optional)
INTRADA_IOS_BUNDLE_ID=com.jonyardley.Intrada
INTRADA_ANDROID_BUNDLE_ID=com.jonyardley.intrada
INTRADA_WEB_HOSTNAME=localhost
```

## Commands

### Generate Schema

Generate Appwrite CLI commands from Rust types:

```bash
# Generate shell script
cd infrastructure
./target/release/appwrite_cli generate

# Generate JSON schema
./target/release/appwrite_cli generate --format json

# Generate Terraform configuration
./target/release/appwrite_cli generate --format terraform

# Save to file
./target/release/appwrite_cli generate --output schema.sh
```

### Validate Schema

Validate the current schema for consistency:

```bash
cd infrastructure
./target/release/appwrite_cli validate

# Custom database settings
./target/release/appwrite_cli validate --database-id my_db --database-name "My Database"
```

### Deploy Schema

Deploy schema to Appwrite:

```bash
cd infrastructure
# Deploy to development
./target/release/appwrite_cli deploy

# Deploy to specific environment
./target/release/appwrite_cli deploy --environment staging

# Dry run (see what would be executed)
./target/release/appwrite_cli deploy --dry-run

# Deploy with current schema for diff
./target/release/appwrite_cli deploy --current-schema current.json
```

### Show Schema Diff

Compare current and target schemas:

```bash
cd infrastructure
# Show differences
./target/release/appwrite_cli diff

# Compare with specific schema file
./target/release/appwrite_cli diff --current-schema current.json
```

### Deploy Platforms

Deploy platform configurations (iOS, Android, Web):

```bash
cd infrastructure
# Deploy platforms using environment variables
./target/release/appwrite_cli deploy-platforms

# Deploy with specific bundle IDs
./target/release/appwrite_cli deploy-platforms \
  --ios-bundle-id com.mycompany.myapp \
  --android-bundle-id com.mycompany.myapp \
  --web-hostname myapp.com

# Dry run
./target/release/appwrite_cli deploy-platforms --dry-run
```

## Configuration Options

### Platform Configuration

The CLI supports multiple ways to configure platform settings:

1. **Environment Variables** (recommended for CI/CD):
   ```bash
   export INTRADA_IOS_BUNDLE_ID=com.mycompany.myapp
   export INTRADA_ANDROID_BUNDLE_ID=com.mycompany.myapp
   export INTRADA_WEB_HOSTNAME=myapp.com
   ```

2. **Command Line Arguments**:
   ```bash
   ./appwrite_cli deploy-platforms --ios-bundle-id com.mycompany.myapp
   ```

3. **Configuration File** (`.env.local`):
   ```
   INTRADA_IOS_BUNDLE_ID=com.mycompany.myapp
   INTRADA_ANDROID_BUNDLE_ID=com.mycompany.myapp
   INTRADA_WEB_HOSTNAME=myapp.com
   ```

### Environment Settings

The CLI supports different environments for deployment:

- `dev` (default): Development environment
- `staging`: Staging environment  
- `prod`: Production environment

## Workflow Examples

### Local Development Setup

```bash
# 1. Start Appwrite
make start

# 2. Deploy schema
cd infrastructure
./target/release/appwrite_cli deploy --environment dev

# 3. Deploy platforms
./target/release/appwrite_cli deploy-platforms --dry-run  # check first
./target/release/appwrite_cli deploy-platforms
```

### CI/CD Pipeline

```bash
cd infrastructure
# 1. Validate schema
./target/release/appwrite_cli validate

# 2. Show what would change
./target/release/appwrite_cli deploy --dry-run --environment staging

# 3. Deploy to staging
./target/release/appwrite_cli deploy --environment staging

# 4. Deploy platforms
./target/release/appwrite_cli deploy-platforms --environment staging
```

### Schema Migration

```bash
cd infrastructure
# 1. Generate current schema backup
./target/release/appwrite_cli generate --format json --output current-schema.json

# 2. Show differences after code changes
./target/release/appwrite_cli diff --current-schema current-schema.json

# 3. Deploy changes
./target/release/appwrite_cli deploy --current-schema current-schema.json
```

## Error Handling

The CLI handles common Appwrite API quirks and errors gracefully:

- **Resource Already Exists**: Continues execution when resources already exist
- **API Quirks**: Handles Appwrite API inconsistencies
- **Validation Errors**: Clear error messages for schema validation failures
- **Network Errors**: Proper error messages for connection issues

## Security Best Practices

1. **API Keys**: Never commit API keys to version control
2. **Environment Files**: Add `.env.local` to `.gitignore`
3. **Bundle IDs**: Use environment-specific bundle IDs
4. **Secrets Management**: Use secure secret management for production

## Troubleshooting

### Common Issues

**"Failed to execute command"**
- Check that Appwrite CLI is installed and accessible
- Verify environment variables are set correctly
- Ensure Appwrite instance is running and accessible

**"Schema validation failed"**
- Check for duplicate collection IDs or attribute keys
- Verify all index attributes exist in the collection
- Review error messages for specific validation issues

**"Platform deployment failed"**
- Try the Docker fallback approach: `./scripts/setup-platforms-docker.sh`
- Manually add platforms in the Appwrite console UI
- Check bundle IDs and hostnames are valid

### Debug Mode

Enable verbose output:
```bash
export RUST_LOG=debug
./appwrite_cli deploy
```

### Getting Help

```bash
# Show all available commands
./appwrite_cli --help

# Show help for specific command
./appwrite_cli deploy --help
```