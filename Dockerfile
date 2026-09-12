FROM lukemathwalker/cargo-chef:latest-rust-1 AS chef
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
# rust-toolchain.toml overrides the base image's rustc for every cargo command
# below it, including the final build — copy it in first so cook and build
# resolve the same toolchain and the cooked deps aren't fingerprint-mismatched
# and discarded.
COPY rust-toolchain.toml .
# Build dependencies — this is the caching Docker layer.
# --bin intrada-api scopes to only intrada-api's dependency graph, excluding
# intrada-ffi's UniFFI toolchain, which this minimal Rust container doesn't
# need.
RUN cargo chef cook --release --recipe-path recipe.json --bin intrada-api
# Build application
COPY . .
# Baked into the binary at compile time via `option_env!("GIT_SHA")` and
# reported to Sentry as the `release` so events tie to deploys. Defaulted
# empty so local `docker build` without --build-arg still works.
# Placed AFTER cargo-chef cook so changes to GIT_SHA per deploy don't bust
# the dependency-build cache (the most expensive layer); only the final
# application-build layer re-runs, gated by build.rs's
# `cargo:rerun-if-env-changed=GIT_SHA`.
ARG GIT_SHA=""
ENV GIT_SHA=$GIT_SHA
RUN cargo build --release --bin intrada-api

# Runtime image — no Rust toolchain needed.
# Trixie matches the cargo-chef builder's glibc (binary built against glibc 2.38+
# crashes on bookworm's 2.36 with `version `GLIBC_2.38' not found`).
FROM debian:trixie-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/intrada-api /usr/local/bin
ENTRYPOINT ["/usr/local/bin/intrada-api"]
