# Intrada — Setup & Configuration

This document covers the external accounts, secrets, and configuration needed
to develop and ship Intrada. The app is a native SwiftUI iOS app, offline-first
with no server: see [`specs/native-ios.md`](specs/native-ios.md).

## 1. Sentry (Error reporting + APM)

DSNs are public (Sentry's security model expects them embedded in client
code), but the Swift SDK reads the value via an env var so the project can be
swapped without code changes.

| Surface | Sentry platform | DSN delivery |
|---------|----------------|--------------|
| Native iOS | Swift | `SENTRY_DSN_NATIVE` env var, baked in via `xcodegen` at build time (see CLAUDE.md → Environment Variables) |

Each event is tagged with `environment = development | production` (determined
at runtime), and `release = $GIT_SHA` when set at build time. Performance
tracing is sampled at 10% (`traces_sample_rate = 0.1`).

### Set the native iOS DSN locally

Add to your `.env` file at the repo root:

```
SENTRY_DSN_NATIVE=https://...@...ingest.de.sentry.io/...
```

`just ios` / `just ios-run` pick it up via `set dotenv-load`. Unset in CI, so
test/smoke runs send nothing.

### Verifying

Trigger a test event (e.g. force a panic in a debug build) and confirm it
appears in the Sentry project's Issues tab.

## 2. CI/CD Pipeline (GitHub Actions)

`.github/workflows/ci.yml` handles CI:

```
push to PR:   test → clippy → fmt → security & hygiene → native iOS build + snapshot tests
push to main: all checks → native iOS release build
```

The native iOS app ships separately via TestFlight — see §3 below.

### GitHub Actions secrets

| Secret | Service | Required for |
|--------|---------|-------------|
| `ASC_KEY_ID` | App Store Connect | TestFlight (native iOS) |
| `ASC_ISSUER_ID` | App Store Connect | TestFlight (native iOS) |
| `ASC_KEY_CONTENT_BASE64` | App Store Connect | TestFlight (native iOS) |
| `MATCH_GIT_URL` | fastlane match | TestFlight (native iOS) |
| `MATCH_GIT_BASIC_AUTHORIZATION` | fastlane match | TestFlight (native iOS) |
| `MATCH_PASSWORD` | fastlane match | TestFlight (native iOS) |
| `SENTRY_AUTH_TOKEN` | Sentry | Release tracking for TestFlight |
| `SENTRY_DSN_NATIVE` | Sentry | Crash reporting in TestFlight builds; a tagged run fails without it |

Set at: **GitHub repo → Settings → Secrets and variables → Actions**

## 3. Native iOS to TestFlight

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

## 4. Local Development

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

### Quick start

```bash
just ios
```

## Checklist

Use this when setting up from scratch:

- [ ] Sentry native iOS project created
- [ ] `SENTRY_DSN_NATIVE` set locally for crash reporting (optional)
- [ ] Test event sent, visible in the Sentry project
- [ ] TestFlight signing bootstrapped (see §3) if shipping to testers
