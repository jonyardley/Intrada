# [Intrada]

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

Alternative methods:

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
npm run build:all
```

Or manually:

```bash
cd web-leptos
npx tailwindcss -i ./style/main.css -o ./style/output.css
trunk build --release
```

## Running core tests

Install cargo-nextest: `cargo binstall cargo-nextest --secure`
Run: `cargo nextest run --release -p shared`
