FROM lukemathwalker/cargo-chef:latest-rust-1 AS chef
WORKDIR /app

FROM chef AS planner
# Copy the entire workspace including shared dependencies
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder 
COPY --from=planner /app/recipe.json recipe.json
# Build dependencies - this is the caching Docker layer!
RUN cargo chef cook --release --recipe-path recipe.json
# Build application
COPY . .
# Build both the server and migrator binaries
RUN cargo build --release --bin intrada-server
RUN cargo build --release --bin migrator

# We do not need the Rust toolchain to run the binary!
FROM debian:bookworm-slim AS runtime
WORKDIR /app

# Install required dependencies for PostgreSQL connection
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy both binaries
COPY --from=builder /app/target/release/intrada-server /usr/local/bin/
COPY --from=builder /app/target/release/migrator /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/intrada-server"] 