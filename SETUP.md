# Intrada — Setup & Configuration

This document covers the external accounts, secrets, and configuration needed to run and deploy Intrada.

## Architecture Overview

```
┌──────────────────┐     libsql     ┌──────────┐
│  Fly.io (Axum)   │ ────────────→ │  Turso   │
│  intrada-api     │               │  (SQLite) │
└──────────────────┘               └──────────┘
```

- **API**: Axum 0.8 REST server, deployed to Fly.io via Docker
- **Database**: Turso (managed libsql/SQLite), accessed via HTTP
- **Client**: native SwiftUI iOS app (see [`specs/native-ios.md`](specs/native-ios.md)); no separate deploy target, distributed via TestFlight

## 1. Turso (Database)

### Account setup

1. Install the CLI: `brew install tursodatabase/tap/turso` (or see [docs](https://docs.turso.tech/cli/installation))
2. Sign up: `turso auth signup`

### Create the database

```bash
turso db create intrada
```

### Get credentials

```bash
# Database URL
turso db show intrada --url
# Output: libsql://intrada-<your-org>.turso.io

# Auth token
turso db tokens create intrada
# Output: eyJhbGci...
```

Save both values — you'll need them for Fly.io secrets and local development.

### Database schema

Migrations run automatically on server startup. Key tables:

- `items` — unified library items (pieces and exercises, with kind, title, composer, category, key, tempo, tags)
- `sessions` + `setlist_entries` — completed practice sessions with their entries
- `routines` + `routine_entries` — reusable practice **sets** (table names retained from when the concept was called "routines" pre-PR #407; rename was Rust-side only to avoid a DB migration)

## 2. Fly.io (API Server)

### Account setup

1. Install the CLI: `brew install flyctl` (or see [docs](https://fly.io/docs/flyctl/install/))
2. Sign up: `fly auth signup`

### First deploy

```bash
# Launch creates the app on Fly.io (only needed once)
fly launch --no-deploy

# Set secrets
fly secrets set \
  TURSO_DATABASE_URL="libsql://intrada-<your-org>.turso.io" \
  TURSO_AUTH_TOKEN="<your-token>" \
  ALLOWED_ORIGIN="tauri://localhost"

# Deploy
fly deploy
```

`ALLOWED_ORIGIN` only needs to cover the native app's request origin
(`tauri://localhost` is a historical carry-over from the removed Tauri shell;
the native SwiftUI app calls the API directly via `URLSession` with no
browser-style CORS preflight, so this value mainly matters for any admin/dev
tooling that hits the API from a browser).

### Configuration files

| File | Purpose |
|------|---------|
| `fly.toml` | App name, region, VM size, health check, auto-scaling |
| `Dockerfile` | Multi-stage build (cargo-chef → debian:bookworm-slim) |
| `.dockerignore` | Excludes unnecessary files from Docker build context |

### Machine config (cost-optimised)

| Setting | Value | Why |
|---------|-------|-----|
| VM size | `shared-cpu-1x` | Smallest available — sufficient for a JSON API |
| Memory | 256 MB (+256 MB swap) | Axum binary is lightweight |
| Auto-stop | `suspend` | Resumes in ~1s, zero cost while idle |
| Min machines | 0 | Scales to zero when no traffic |
| Region | `lhr` (London) | Single region, close to Turso |
| Health check | `GET /api/health` every 60s | Monitors server + database connectivity |

### Environment variables

| Variable | Set via | Value |
|----------|---------|-------|
| `TURSO_DATABASE_URL` | `fly secrets set` | `libsql://intrada-<org>.turso.io` |
| `TURSO_AUTH_TOKEN` | `fly secrets set` | Token from `turso db tokens create` |
| `ALLOWED_ORIGIN` | `fly secrets set` | See note above |
| `RUST_LOG` | `fly.toml` [env] | `info` (already configured) |
| `PORT` | `fly.toml` [env] | `8080` (production; defaults to `3001` locally) |

### Verify deployment

```bash
# Health check
curl https://intrada-api.fly.dev/api/health

# Expected: {"status":"ok","database":"ok"}
```

## 3. Sentry (Error reporting + APM)

One Sentry project per surface. DSNs are public (Sentry's security model expects
them embedded in client code), but the Rust SDK reads them via env vars so
projects can be swapped without code changes.

### Projects

| Surface | Sentry platform | DSN delivery |
|---------|----------------|--------------|
| `intrada-api` | Rust | `SENTRY_DSN` env var (Fly secret) |
| Native iOS | Swift | `SENTRY_DSN_NATIVE` env var, baked in via `xcodegen` at build time (see CLAUDE.md → Environment Variables) |

Each project tags events with `environment = development | production`
(determined at runtime), and `release = $GIT_SHA` when set at build time.
Performance tracing is sampled at 10% (`traces_sample_rate = 0.1`).

### Set the API DSN as a Fly.io secret

```bash
fly secrets set SENTRY_DSN="https://...@...ingest.de.sentry.io/..." -a intrada-api
```

The API will pick it up on next deploy. Without it, Sentry init is a no-op.

### Set the native iOS DSN locally

Add to your `.env` file at the repo root:

```
SENTRY_DSN_NATIVE=https://...@...ingest.de.sentry.io/...
```

`just ios` / `just ios-run` pick it up via `set dotenv-load`. Unset in CI, so
test/smoke runs send nothing.

### Verifying

After the next deploy, trigger a test event from each surface (e.g. visit a
404 route, force a panic in a debug build) and confirm it appears in the
matching Sentry project's Issues tab.

## 4. CI/CD Pipeline (GitHub Actions)

`.github/workflows/ci.yml` handles CI and the API deploy:

```
push to PR:   test → clippy → fmt → security & hygiene → native iOS build + snapshot tests
push to main: all checks → API Docker build → deploy API (Fly.io)
```

`deploy-api` gates on `test`, `clippy`, `fmt`, and `api-docker-build` (which
only runs on main, and only when the API actually changed).

The native iOS app ships separately via TestFlight — see §5a below.

### All GitHub Actions secrets

| Secret | Service | Required for |
|--------|---------|-------------|
| `FLY_API_TOKEN` | Fly.io | API deployment |
| `ASC_KEY_ID` | App Store Connect | TestFlight (native iOS) |
| `ASC_ISSUER_ID` | App Store Connect | TestFlight (native iOS) |
| `ASC_KEY_CONTENT_BASE64` | App Store Connect | TestFlight (native iOS) |
| `MATCH_GIT_URL` | fastlane match | TestFlight (native iOS) |
| `MATCH_GIT_BASIC_AUTHORIZATION` | fastlane match | TestFlight (native iOS) |
| `MATCH_PASSWORD` | fastlane match | TestFlight (native iOS) |
| `SENTRY_AUTH_TOKEN` | Sentry | Release tracking for the API deploy and TestFlight |
| `SENTRY_DSN_NATIVE` | Sentry | Crash reporting in TestFlight builds; a tagged run fails without it |

Set at: **GitHub repo → Settings → Secrets and variables → Actions**

### Generating the Fly.io deploy token

```bash
fly tokens create deploy -a intrada-api
```

Add the output as the `FLY_API_TOKEN` secret in GitHub Actions.

## 4a. Native iOS to TestFlight

The native SwiftUI app ships to TestFlight via
`.github/workflows/release-testflight.yml` (runs on `workflow_dispatch` or a
`v*` tag — never per-PR). Full rationale + decisions:
[`specs/ios-testflight-cicd.md`](specs/ios-testflight-cicd.md). Signing uses
fastlane **match** (App Store Connect API key for auth/upload).

**One-time setup, in order** (each step depends on the previous):

1. **App Store Connect** — accept the Developer Program License Agreement
   (Business → Agreements shows *Active*).
2. **Register the bundle id** `com.intrada.native` — Certificates, Identifiers
   & Profiles → Identifiers. No special capabilities needed.
3. **Create the app record** — Apps → + → New App (iOS, the bundle id, any SKU).
   *Cannot be automated with the API key — one manual click.*
4. **Create the API key** — Users and Access → Integrations → **Team Keys** →
   role **App Manager**. Save the Key ID, Issuer ID, and the `.p8` (one-time
   download).
5. **Create a private certs repo**, e.g. `jonyardley/intrada-certificates`, and
   choose a strong `MATCH_PASSWORD`.
6. **Bootstrap match** (local, Ruby ≥ 3 — system Ruby 2.6 is too old, use
   `rbenv`):
   ```bash
   bundle install              # then commit the generated Gemfile.lock
   MATCH_GIT_URL=<certs-repo> MATCH_PASSWORD=<pw> bundle exec fastlane match appstore
   ```
   Authenticate with your Apple ID when prompted. This generates + encrypts +
   pushes the Apple Distribution cert + App Store profile to the certs repo.
7. **Add the GitHub Actions secrets** (table above):
   ```bash
   base64 -i AuthKey_<KEYID>.p8 | pbcopy        # → ASC_KEY_CONTENT_BASE64
   printf 'USER:GITHUB_PAT' | base64 | pbcopy   # → MATCH_GIT_BASIC_AUTHORIZATION (repo read access)
   ```
8. **Run it** — Actions → *Release — TestFlight* → *Run workflow* (or push a
   `v*` tag). After processing, add yourself to an Internal Testing group in the
   app's TestFlight tab and install via the TestFlight app.

Local parity (after the one-time setup): `just testflight`.

## 5. Local Development

### Prerequisites

Install Rust first (mise's `cargo:` backend builds with it):

- Rust via [rustup](https://rustup.rs); `rust-toolchain.toml` pins the version
  and rustup installs it on first build

Then the rest of the dev toolchain (just, xcodegen, oxipng, typos, Ruby for
fastlane, pinned cargo tools like cargo-swift 0.9.0) is declared in
`mise.toml`. Install [mise](https://mise.jdx.dev) once and let it provision
everything:

```bash
brew install mise
mise install
```

### Optional: sccache for faster fresh-worktree builds

`mise install` provisions the `sccache` binary, but it stays inactive until
you opt in — it isn't wired into `mise.toml`'s committed config, so nobody
gets it by surprise. Measured ~30% faster `just check` in a fresh worktree
with `target/` cold and the cache warm (#1206); no measurable overhead when
the cache is empty. Opt in per-machine:

```bash
cat > mise.local.toml <<'EOF'
[env]
RUSTC_WRAPPER = "sccache"
EOF
```

`mise.local.toml` is gitignored and merges over `mise.toml` automatically —
run `mise install` again if you added it after your first install. Default
cache size is 10G at `~/Library/Caches/Mozilla.sccache`; check usage with
`sccache --show-stats`. CI stays on Swatinem/rust-cache, not sccache — the
target-dir cache it already runs beats a cold sccache cache without paying
for remote storage.

### One-time git config

```bash
# Hide the whole-tree swift format reformat commit from git blame
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

### Quick start (recommended)

```bash
# 1. Set up environment
cp .env.example .env
# Edit .env with your Turso credentials

# 2. Start the API dev server
just dev
# → API on :3001

# 3. Open the iOS app
just ios
```

### Manual setup (without just)

```bash
# API server (requires Turso credentials)
export TURSO_DATABASE_URL="libsql://intrada-<your-org>.turso.io"
export TURSO_AUTH_TOKEN="<your-token>"
export ALLOWED_ORIGIN="tauri://localhost"
export PORT=3001

cargo run -p intrada-api
# → API on http://localhost:3001
```

### Quick verification

```bash
# Health check
curl http://localhost:3001/api/health

# Create an item
curl -X POST http://localhost:3001/api/items \
  -H "Content-Type: application/json" \
  -d '{"kind":"piece","title":"Clair de Lune","composer":"Debussy","tags":[]}'

# List items
curl http://localhost:3001/api/items
```

### Seed data

To populate the API with realistic sample data:

```bash
just seed
# or: bash scripts/seed-dev-data.sh
```

The native app has its own demo-data path (the `--seed-sample-data` launch
arg / **Intrada (Seeded)** Xcode scheme) — see [README.md](README.md) and
CLAUDE.md → "Demo data vs. real on-device data" for the distinction.

## Checklist

Use this when setting up from scratch:

- [ ] Turso CLI installed
- [ ] Turso database created (`turso db create intrada`)
- [ ] Database URL and auth token saved
- [ ] Fly.io CLI installed
- [ ] Fly.io app launched (`fly launch --no-deploy`)
- [ ] Fly.io secrets set (TURSO_DATABASE_URL, TURSO_AUTH_TOKEN, ALLOWED_ORIGIN)
- [ ] First deploy successful (`fly deploy`)
- [ ] Health check returns `{"status":"ok","database":"ok"}`
- [ ] Sentry projects created (api, native iOS)
- [ ] `SENTRY_DSN` set on Fly.io
- [ ] `SENTRY_DSN_NATIVE` set locally for native iOS crash reporting (optional)
- [ ] Test event sent from each surface, visible in matching Sentry project
- [ ] TestFlight signing bootstrapped (see §4a) if shipping to testers
