# Intrada

> Intrada empowers musicians to achieve mastery through structured, efficient, and deeply reflective practice. By providing intelligent tools for planning, focused execution, and insightful analysis, Intrada transforms practice from a routine into a deliberate pathway to virtuosity.

## Quick Start

**Get up and running in one command:**
```bash
make setup
```

For detailed setup instructions, see [docs/QUICKSTART.md](docs/QUICKSTART.md).

## Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Get your development environment running
- **[Development Guide](docs/DEVELOPMENT.md)** - Development workflow and best practices  
- **[Appwrite Infrastructure](docs/APPWRITE_INFRASTRUCTURE.md)** - Backend infrastructure details

## Running the leptos web app

### Development

The simplest way to start the development server is:

```bash
cd web-leptos
npm run dev
```

This script will:
1. Build the CSS file
2. Start the Tailwind CSS watcher in the background
3. Start the Trunk development server

```bash
# If you prefer using trunk directly:
cd web-leptos
trunk serve --open
```

The build process now automatically builds CSS before building the app, thanks to the Trunk.toml hooks configuration.

### Building for production

To build the application for production:

```bash
cd web-leptos
npm run build
```

This will automatically:
1. Build the CSS with Tailwind
2. Build the Rust/WASM application with Trunk in release mode
3. Create optimized production assets in the `dist/` folder

## Running core tests

Install cargo-nextest: `cargo binstall cargo-nextest --secure`

Run: `cargo nextest run --release -p shared`
