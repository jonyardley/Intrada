# Intrada Server

A Rust-based server for the Intrada application using Axum web framework and SeaORM for database operations.

## Features

- **Web Framework**: Axum for high-performance async web server
- **Database**: SeaORM with PostgreSQL support
- **Migrations**: Built-in database migration system
- **Environment**: dotenv for environment variable management

## Development Setup

### Quick Start with Docker (Recommended)

1. **Prerequisites**:
   - Docker and Docker Compose
   - Rust (latest stable)

2. **Run the setup script**:
   ```bash
   ./setup-dev.sh
   ```

   This script will:
   - Create `.env` file from `.env.example`
   - Start PostgreSQL with Docker Compose
   - Build the project and migrator
   - Run all database migrations

3. **Start the server**:
   ```bash
   cargo run
   ```

### Manual Setup (Alternative)

If you prefer to set up manually or use a local PostgreSQL installation:

1. **Install dependencies**:
   ```bash
   # Install Rust (if not already installed)
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   
   # Install PostgreSQL (macOS)
   brew install postgresql
   ```

2. **Database setup**:
   ```bash
   # Start PostgreSQL
   brew services start postgresql
   
   # Create database
   createdb intrada_dev
   ```

3. **Environment variables**:
   ```bash
   # Copy example environment file
   cp .env.example .env
   
   # Edit .env with your database URL (for local PostgreSQL)
   DATABASE_URL=postgres://username:password@localhost:5432/intrada_dev
   ```

4. **Run migrations**:
   ```bash
   # Run migrations using the migrator CLI
   cargo run --bin migrator up
   
   # Or run migrations automatically when starting the server
   cargo run
   ```

## Database Operations

### Running Migrations

The project uses SeaORM for database operations and migrations:

```bash
# Run all pending migrations
cargo run --bin migrator up

# Rollback the last migration
cargo run --bin migrator down

# Check migration status
cargo run --bin migrator status

# Reset database (drop all tables and re-run migrations)
cargo run --bin migrator reset
```

### Creating New Migrations

To create a new migration:

1. Add a new migration file in `src/database/migration/`
2. Follow the naming convention: `mYYYYMMDD_HHMMSS_description.rs`
3. Add the migration to the `Migrator` in `src/database/migration.rs`

Example migration structure:
```rust
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // Create table or modify schema
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // Reverse the migration
        Ok(())
    }
}
```

## Running the Server

```bash
# Development mode
cargo run

# Production mode
cargo run --release
```

The server will start on `http://localhost:3000` by default, or use the `PORT` environment variable.

## Docker Compose Management

The project includes Docker Compose configuration for local PostgreSQL development:

```bash
# Start PostgreSQL
docker-compose up -d postgres

# Stop PostgreSQL
docker-compose down

# View logs
docker-compose logs postgres

# Connect to PostgreSQL directly
docker-compose exec postgres psql -U intrada_user -d intrada_db
```

## API Endpoints

- `GET /` - Hello world HTML page
- `GET /hello` - Hello world JSON response
- `GET /health` - Database health check

## Project Structure

```
server/
├── src/
│   ├── bin/
│   │   └── migrator.rs       # Migration CLI tool
│   ├── database/
│   │   ├── entities/         # SeaORM entity models
│   │   ├── migration/        # Database migrations
│   │   └── mod.rs           # Database connection setup
│   ├── lib.rs               # Library exports
│   └── main.rs              # Main application
├── .env.example             # Example environment variables
└── Cargo.toml              # Project dependencies
```

## Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `PORT` - Server port (default: 3000)

## Dependencies

- **axum** - Web framework
- **sea-orm** - Database ORM
- **sea-orm-migration** - Database migrations
- **tokio** - Async runtime
- **uuid** - UUID generation
- **chrono** - Date/time handling
- **serde** - Serialization/deserialization
- **dotenv** - Environment variable loading