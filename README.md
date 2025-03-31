# [Practice App]

_Working title_

## Running the leptos web app

`trunk serve --open`

The build process now automatically builds CSS before building the app, thanks to the Trunk.toml configuration.

## Building for production

To build the application for production:

```
cd web-leptos
trunk build --release
```

This will automatically build the CSS and then the Rust application.

## Running core tests

Install cargo-nextest: `cargo binstall cargo-nextest --secure`
Run: `cargo nextest run --release -p shared`
