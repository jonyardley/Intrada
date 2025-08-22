# Intrada Server

A PostgreSQL-backed REST API server for the Intrada practice tracking application.

## Local Development Setup

### Prerequisites
- Docker and Docker Compose
- Rust toolchain

### Quick Start

1. **Start PostgreSQL database:**
   ```bash
   docker-compose up -d
   ```

2. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env if needed (default values should work for local development)
   ```

3. **Run the server:**
   ```bash
   cargo run
   ```

The server will start on `http://localhost:3000` and automatically run database migrations.

### Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `PORT` - Server port (default: 3000)
- `RUST_LOG` - Log level (optional, default: info)

## API Endpoints

### Goals
- `GET /goals` - List all goals
- `POST /goals` - Create a new goal
- `GET /goals/{id}` - Get a specific goal
- `PUT /goals/{id}` - Update a goal
- `DELETE /goals/{id}` - Delete a goal

### Example Usage

```bash
# Create a goal
curl -X POST http://localhost:3000/goals \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Master Chopin Etudes",
    "description": "Work through all Chopin etudes",
    "study_ids": ["chopin-op10", "chopin-op25"],
    "tempo_target": 120
  }'

# List all goals
curl http://localhost:3000/goals
```

## Production Deployment (Fly.io)

### Setup
1. Install [Fly CLI](https://fly.io/docs/hands-on/install-flyctl/)
2. Login: `fly auth login`
3. Deploy: `fly deploy`

### Database
Fly.io will automatically provide the `DATABASE_URL` environment variable when you attach a PostgreSQL database:

```bash
fly postgres create
fly postgres attach <your-postgres-app>
```

The server will automatically run migrations on startup.

## Database Schema

The server uses PostgreSQL with automatic migrations. See `migrations/` directory for schema definitions.

## Development

### Running from project root
If running from the project root, use:
```bash
cargo run -p intrada-server
```

### Database Management Scripts

The server includes several utility scripts for managing the PostgreSQL database:

#### `cleanup-db.sh`
Cleans all data from the database while preserving table structure.

```bash
# Interactive cleanup (prompts for confirmation)
./cleanup-db.sh

# Force cleanup (no confirmation prompt)
./cleanup-db.sh --force
```

**What it does:**
- Deletes all sessions, goals, and studies
- Preserves table structure and schema
- Shows before/after data counts
- Safe to run anytime during development

#### `seed-db.sh`
Adds realistic sample data to the database for testing.

```bash
./seed-db.sh
```

**What it adds:**
- 3 sample studies (Chopin Etude, Bach Invention, Scales)
- 2 sample goals with study associations
- 3 sample practice sessions
- Uses API endpoints if server is running, otherwise inserts directly

#### `reset-db.sh`
Combines cleanup and seeding in one command.

```bash
./reset-db.sh
```

**What it does:**
1. Runs `cleanup-db.sh --force` to clear all data
2. Runs `seed-db.sh` to add fresh sample data
3. Perfect for getting a clean slate with test data

#### Usage Examples

```bash
# Start fresh with clean database
cd server
./cleanup-db.sh

# Add sample data for testing
./seed-db.sh

# Complete reset (clean + seed)
./reset-db.sh

# Then restart server to clear any cached data
pkill -f intrada-server && ./build-and-run.sh
```

### Manual Database Management
```bash
# Reset database (nuclear option)
docker-compose down -v
docker-compose up -d

# View logs
docker-compose logs postgres
``` 