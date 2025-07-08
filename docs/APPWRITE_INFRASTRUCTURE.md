# Appwrite Infrastructure as Code

This document describes the complete infrastructure-as-code solution for managing Appwrite database schemas using Rust types. The system ensures that your app types are directly linked to your database schema, providing type safety and preventing schema drift.

## 🏗️ Architecture Overview

The infrastructure system consists of several key components:

1. **Schema Types** - Rust types that define the database structure
2. **Code Generation** - Tools that convert Rust types to Appwrite configuration
3. **CLI Tools** - Command-line utilities for deployment and management
4. **Migration System** - Version-controlled schema changes
5. **CI/CD Pipeline** - Automated deployment and validation
6. **Local Development** - Docker-based development environment

## 📁 Project Structure

```
├── infrastructure/             # Infrastructure-as-Code components
│   ├── src/
│   │   ├── schema.rs          # Schema definitions and conversions
│   │   ├── migrations.rs      # Migration planning and execution
│   │   ├── lib.rs             # Infrastructure library exports
│   │   └── bin/
│   │       └── appwrite_cli.rs # CLI tool for schema management
│   └── Cargo.toml             # Infrastructure dependencies
├── shared/src/app/             # Core application types
│   ├── goal.rs                # PracticeGoal type (maps to goals collection)
│   ├── study.rs               # Study type (maps to studies collection)
│   ├── session.rs             # PracticeSession type (maps to sessions collection)
│   └── study_session.rs       # StudySession type (maps to study_sessions collection)
├── scripts/
│   └── setup-local-appwrite.sh  # Local development setup
├── .github/workflows/
│   └── deploy-appwrite.yml      # CI/CD pipeline
├── docker-compose.yml           # Local Appwrite environment
├── appwrite-generated/          # Generated deployment files
└── DEVELOPMENT.md              # Development guide
```

## 🚀 Getting Started

### Prerequisites

- Docker and Docker Compose
- Rust 1.80+ 
- Node.js 18+ (for Appwrite CLI)
- Git

### Local Development Setup

1. **Start Local Appwrite Environment**
   ```bash
   make setup
   ```
   
   This command will:
   - Setup Crux dependency
   - Start Appwrite using Docker Compose
   - Install and configure Appwrite CLI
   - Create a development project
   - Generate and deploy your schema
   - Configure iOS app settings
   - Create `.env.local` configuration file

2. **Verify Installation**
   - Open http://localhost/console
   - Check that your collections exist:
     - `goals` (from PracticeGoal)
     - `studies` (from Study)
     - `sessions` (from PracticeSession)
     - `study_sessions` (from StudySession)

### Production Setup

1. **Configure GitHub Secrets**
   ```
   STAGING_APPWRITE_ENDPOINT=https://your-staging.appwrite.io/v1
   STAGING_APPWRITE_PROJECT_ID=your-staging-project
   STAGING_APPWRITE_API_KEY=your-staging-api-key
   
   PRODUCTION_APPWRITE_ENDPOINT=https://your-production.appwrite.io/v1
   PRODUCTION_APPWRITE_PROJECT_ID=your-production-project
   PRODUCTION_APPWRITE_API_KEY=your-production-api-key
   ```

2. **Deploy Schema**
   - Push to `staging` branch for staging deployment
   - Push to `main` branch for production deployment
   - Use GitHub Actions "Deploy Appwrite Schema" for manual deployment

## 🛠️ CLI Usage

The Rust CLI tool provides several commands for schema management:

### Generate Schema Files

```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- generate \
    --database-id intrada_db \
    --database-name "Intrada Database" \
    --output ../appwrite-generated \
    --format shell
```

Or use the built binary:
```bash
cd infrastructure
cargo build --bin appwrite_cli --features cli --release
./target/release/appwrite_cli generate \
    --database-id intrada_db \
    --database-name "Intrada Database" \
    --output ../appwrite-generated \
    --format shell
```

Supported formats:
- `shell` - Bash deployment scripts
- `json` - JSON schema definition
- `terraform` - Terraform configuration

### Validate Schema

```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- validate \
    --database-id intrada_db \
    --database-name "Intrada Database"
```

### Deploy Schema

```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- deploy \
    --database-id intrada_db \
    --database-name "Intrada Database" \
    --environment dev
```

For specific environments:
```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- deploy \
    --database-id intrada_db \
    --database-name "Intrada Database" \
    --environment production
```

### Dry Run Deployment

```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- deploy \
    --database-id intrada_db \
    --database-name "Intrada Database" \
    --environment dev \
    --dry-run
```

## 📊 Schema Management

### Defining Collections

Collections are automatically generated from your Rust types by implementing the `SchemaDefinition` trait:

```rust
impl SchemaDefinition for PracticeGoal {
    fn collection_name() -> &'static str { "goals" }
    fn collection_id() -> &'static str { "goals" }
    
    fn attributes() -> Vec<AttributeSchema> {
        vec![
            AttributeSchema {
                key: "name".to_string(),
                attribute_type: AttributeType::String { size: Some(255) },
                required: true,
                default: None,
                array: false,
            },
            // ... more attributes
        ]
    }
    
    fn indexes() -> Vec<IndexSchema> {
        vec![
            IndexSchema {
                key: "name_fulltext".to_string(),
                index_type: IndexType::Fulltext,
                attributes: vec!["name".to_string()],
            },
            // ... more indexes
        ]
    }
    
    fn permissions() -> Vec<Permission> {
        vec![
            Permission {
                role: "users".to_string(),
                permission: "create".to_string(),
            },
            // ... more permissions
        ]
    }
}
```

### Current Schema

The system automatically maps these Rust types to Appwrite collections:

| Rust Type | Collection ID | Description |
|-----------|---------------|-------------|
| `PracticeGoal` | `goals` | Practice goals with status tracking |
| `Study` | `studies` | Study materials and content |
| `PracticeSession` | `sessions` | Practice sessions with timing |
| `StudySession` | `study_sessions` | Links between studies and sessions |

### Adding New Collections

1. **Define your Rust type** in `shared/src/app/`
2. **Implement `SchemaDefinition`** for the type in `infrastructure/src/schema.rs`
3. **Add to `SchemaBuilder`** in `infrastructure/src/schema.rs`
4. **Export from `shared/src/app.rs`** module
5. **Deploy** using CLI or CI/CD

Example:
```rust
// In shared/src/app/exercise.rs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Exercise {
    pub name: String,
    pub difficulty: u8,
    pub instructions: String,
}

// In infrastructure/src/schema.rs - add implementation
impl SchemaDefinition for Exercise {
    fn collection_name() -> &'static str { "exercises" }
    fn collection_id() -> &'static str { "exercises" }
    // ... implement required methods
}

// In infrastructure/src/schema.rs - add to SchemaBuilder::build_schema()
Exercise::to_collection_schema(),
```

## 🔄 Migration System

The migration system tracks schema changes and provides rollback capabilities:

### Automatic Migration Planning

```rust
use infrastructure::{MigrationPlanner, SchemaBuilder, MigrationExecutor};

let current_schema = None; // or load from previous state
let target_schema = SchemaBuilder::new("db_id".to_string(), "DB Name".to_string())
    .build_schema();

let migration = MigrationPlanner::plan_migration(
    &current_schema,
    &target_schema,
    "Add new exercise collection".to_string(),
    "Adds support for exercise tracking".to_string(),
);

let commands = MigrationExecutor::generate_commands(&migration);
let rollback_commands = MigrationExecutor::generate_rollback_commands(&migration);
```

### Migration Operations

The system supports these migration operations:

- `CreateDatabase` - Create new database
- `CreateCollection` - Add new collection
- `UpdateCollection` - Modify collection properties
- `DeleteCollection` - Remove collection
- `CreateAttribute` - Add new attribute
- `UpdateAttribute` - Modify attribute properties
- `DeleteAttribute` - Remove attribute
- `CreateIndex` - Add new index
- `DeleteIndex` - Remove index
- `Custom` - Execute custom commands

## 🚢 CI/CD Pipeline

The GitHub Actions workflow provides automated deployment:

### Triggers

- **Push to `staging`** - Deploy to staging environment
- **Push to `main`** - Deploy to production environment
- **Pull Request** - Validate schema changes
- **Manual Dispatch** - Deploy to specific environment

### Workflow Steps

1. **Schema Validation** - Verify schema consistency
2. **Artifact Generation** - Create deployment files
3. **Staging Deployment** - Deploy to staging (if applicable)
4. **Production Deployment** - Deploy to production (if applicable)
5. **Verification** - Post-deployment checks
6. **Notifications** - Success/failure alerts

### Environment Configuration

Each environment requires these secrets:

```yaml
STAGING_APPWRITE_ENDPOINT: https://staging.appwrite.io/v1
STAGING_APPWRITE_PROJECT_ID: staging-project-id
STAGING_APPWRITE_API_KEY: staging-api-key

PRODUCTION_APPWRITE_ENDPOINT: https://production.appwrite.io/v1
PRODUCTION_APPWRITE_PROJECT_ID: production-project-id
PRODUCTION_APPWRITE_API_KEY: production-api-key
```

## 🔧 Local Development

### Docker Compose Services

The local environment includes:

- **Appwrite** - Main application server
- **MariaDB** - Database server
- **Redis** - Cache and queue server
- **Traefik** - Reverse proxy
- **Workers** - Background job processors

### Environment Variables

Local development uses these default values:

```bash
APPWRITE_ENDPOINT=http://localhost
APPWRITE_PROJECT_ID=intrada-dev
APPWRITE_DATABASE_ID=intrada_db
APPWRITE_API_KEY=generated-during-setup
```

### Development Workflow

1. **Make schema changes** in Rust types
2. **Validate locally**:
   ```bash
   cd infrastructure
   cargo run --bin appwrite_cli --features cli -- validate \
       --database-id intrada_db \
       --database-name "Intrada Database"
   ```
3. **Deploy to local**:
   ```bash
   cd infrastructure
   cargo run --bin appwrite_cli --features cli -- deploy \
       --database-id intrada_db \
       --database-name "Intrada Database" \
       --endpoint http://localhost \
       --project-id intrada-dev \
       --api-key $APPWRITE_API_KEY
   ```
4. **Test your app** against local Appwrite
5. **Commit and push** to trigger CI/CD

## 🔍 Troubleshooting

### Common Issues

1. **Schema validation fails**
   - Check for duplicate collection IDs
   - Verify attribute names are unique within collections
   - Ensure indexes reference existing attributes

2. **Deployment fails**
   - Verify API key has correct permissions
   - Check network connectivity to Appwrite endpoint
   - Review Appwrite server logs

3. **Local setup issues**
   - Ensure Docker is running
   - Check port availability (80, 443, 8080)
   - Verify sufficient disk space for Docker volumes

4. **CI/CD failures**
   - Check GitHub secrets are configured correctly
   - Verify Rust toolchain version in workflow
   - Review workflow logs for specific errors

### Debug Commands

```bash
# Check local Appwrite status
docker-compose ps

# View Appwrite logs
docker-compose logs -f appwrite

# Reset local environment
docker-compose down
docker volume rm $(docker volume ls -q | grep appwrite)
./scripts/setup-local-appwrite.sh

# Test schema generation
cd infrastructure
cargo run --bin appwrite_cli --features cli -- generate \
    --database-id test \
    --database-name "Test" \
    --output /tmp/test-schema \
    --format json
```

## 📈 Benefits

This infrastructure-as-code approach provides:

1. **Type Safety** - Schema changes are validated at compile time
2. **Version Control** - All schema changes are tracked in Git
3. **Consistency** - Same schema across all environments
4. **Automation** - Reduced manual deployment errors
5. **Rollback** - Easy reversion of problematic changes
6. **Documentation** - Schema is self-documenting through code
7. **Testing** - Schema changes can be tested locally

## 🔮 Future Enhancements

Potential improvements to consider:

1. **Schema Diffing** - Compare deployed schema with local schema
2. **Backup Integration** - Automatic backups before migrations
3. **Multi-Environment** - Support for multiple staging environments
4. **Performance Monitoring** - Track query performance after schema changes
5. **Custom Validators** - Additional schema validation rules
6. **Terraform Provider** - Direct Terraform integration
7. **Visual Schema Explorer** - Web UI for schema visualization

## 📚 References

- [Appwrite Documentation](https://appwrite.io/docs)
- [Appwrite CLI Reference](https://appwrite.io/docs/command-line)
- [Rust Serde Documentation](https://serde.rs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

*This infrastructure system ensures your Rust types and Appwrite database schema stay perfectly synchronized, providing a robust foundation for your application's data layer.* 