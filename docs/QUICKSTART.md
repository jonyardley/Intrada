# Intrada Appwrite Quick Start

## TL;DR - One Command Setup

```bash
make setup
```

That's it! This command will:
- ✅ Start all Appwrite services
- ✅ Create the database and collections
- ✅ Deploy the complete schema
- ✅ Configure environment files
- ✅ Update iOS configuration
- ✅ Verify everything works

## First Time Setup

1. **Run the automation:**
   ```bash
   make setup
   ```

2. **When prompted, create your API key:**
   - Open: http://localhost/console
   - Create account/login
   - Create project: `intrada-dev`
   - Create API key with database permissions
   - Paste the key when prompted

3. **Done!** Your environment is ready.

## Daily Usage

```bash
# Start everything
make start

# Check status
make status

# Stop everything
make stop

# Complete reset (careful!)
make teardown
```

## What Gets Created

- **Project:** `intrada-dev`
- **Database:** `intrada_db`
- **Collections:** `goals`, `studies`, `sessions`, `study_sessions`
- **Configuration:** `.env.local`
- **iOS Config:** `iOS/Intrada/Config.plist`

## Troubleshooting

**Collections not showing?** This is normal - they may take a moment to appear in the API. The deployment logs will show success.

**API key not working?** Run `make setup` again - it will detect and fix issues.

**Need to start over?** Run `make teardown` then `make setup`.

## Advanced Usage

```bash
# Run with specific API key
./scripts/setup-appwrite-complete.sh "your-api-key-here"

# Just tear down
./scripts/teardown-local-appwrite.sh

# Test connection
make test
```

## CI/CD

GitHub Actions workflow included at `.github/workflows/appwrite-setup.yml`

---

**🎉 Happy coding!** Your Appwrite environment is now fully automated and ready to use. 