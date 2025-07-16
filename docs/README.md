# Intrada Documentation

Welcome to the Intrada documentation! This directory contains all the guides and references you need to work with the project.

## Getting Started

- **[Quick Start Guide](QUICKSTART.md)** - Get your development environment running in minutes
- **[Development Guide](DEVELOPMENT.md)** - Development workflow, testing, and best practices

## Documentation

### Project Structure
- **[Development Guide](DEVELOPMENT.md)** - Development workflow and best practices
- **[Deployment Guide](DEPLOYMENT.md)** - Deployment process and configuration
- **[iOS Testing Guide](IOS_TESTING.md)** - iOS testing and configuration

## Infrastructure

## Quick Commands

```bash
# Build everything
cargo build --workspace

# Test everything  
cargo test --workspace

# Generate types
./typegen.sh

# Start server
cd server && cargo run

# Start web app
cd web-leptos && npm run build:css && npm run dev
```

## Need Help?

- Check the [Quick Start Guide](QUICKSTART.md) for common setup issues
- Review the [Development Guide](DEVELOPMENT.md) for workflow questions
- Look at the server implementation in `server/` for backend details

---

**Happy coding! 🎵** 