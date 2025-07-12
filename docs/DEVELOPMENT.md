# Local Development Setup

## Quick Start

Use the automated setup for instant development environment:

```bash
# Complete setup (recommended for first time)
make setup

# Or individual commands
make start          # Start Appwrite services
make dev-deploy     # Deploy schema changes
make status         # Check current status
make stop           # Stop services
make teardown       # Complete cleanup
```

## Appwrite Configuration

Your local Appwrite instance is running at: http://localhost/v1
Appwrite Console: http://localhost/console

### Project Details
- Project ID: intrada-dev
- Database ID: intrada_db
- API Key: Created automatically during setup

### Environment Variables
The following environment variables are configured in `.env.local`:

```
APPWRITE_ENDPOINT=http://localhost/v1
APPWRITE_PROJECT_ID=intrada-dev
APPWRITE_DATABASE_ID=intrada_db
APPWRITE_API_KEY=auto-generated-api-key
```

## Managing Schema

### Generate Schema
```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- generate \
    --database-id intrada_db \
    --database-name "Intrada Database" \
    --output ../appwrite-generated
```

### Deploy Schema Changes
```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- deploy \
    --database-id intrada_db \
    --database-name "Intrada Database" \
    --environment dev
```

### Validate Schema
```bash
cd infrastructure
cargo run --bin appwrite_cli --features cli -- validate \
    --database-id intrada_db \
    --database-name "Intrada Database"
```

## Useful Commands

### Start/Stop Appwrite
```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f appwrite
```

### Reset Database
```bash
# Complete reset (recommended)
make teardown
make setup

# Or manual reset
docker compose down
docker volume rm $(docker volume ls -q | grep appwrite)
docker compose up -d
./scripts/setup-appwrite-complete.sh
```

## Troubleshooting

1. **Appwrite not responding**: Check if Docker containers are running with `docker ps`
2. **Port conflicts**: Make sure ports 80, 443, 8080 are not in use by other services
3. **API key issues**: Regenerate API key from Appwrite console at http://localhost/console
4. **Schema deployment fails**: Check that API key has proper permissions

## Schema Management

The database schema is defined in Rust types and automatically converted to Appwrite collections:

- `PracticeGoal` → `goals` collection
- `Study` → `studies` collection  
- `PracticeSession` → `sessions` collection
- `StudySession` → `study_sessions` collection

Any changes to these Rust types should be reflected by running the schema deployment commands above.
