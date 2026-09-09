# Native iOS — TestFlight CI/CD

> Tier 3 spec. Rides with its first implementation commit (this branch).
> Status: Phase A (pipeline scaffolding). Last reviewed: 2026-06-17.

## Problem

We now have a paid Apple Developer account. We want the native SwiftUI app
(`com.intrada.native`) to reach a physical device without cabling into Xcode —
i.e. a CI/CD lane that produces a **signed** device build and ships it to
**TestFlight**, so installing is "open the TestFlight app".

The repo already solves the hard repo-specific part of an iOS build (Rust→Swift
binding generation + `xcodegen`), but only builds **unsigned, for the
simulator** (`native-ios` job, `CODE_SIGNING_ALLOWED=NO`). A device archive +
code signing + App Store Connect upload is genuinely new.

## Approach

A **new, separate** GitHub Actions workflow (`release-testflight.yml`) that runs
**only** on `workflow_dispatch` or a `v*` tag — never per-PR (macOS minutes are
10×-billed). It reuses the existing `native-ios` prelude verbatim (Rust toolchain
→ regenerate bindings → `xcodegen generate`) but builds a **Release** core,
signs with a distribution identity, and uploads via **fastlane**.

```
workflow_dispatch / tag v*
  └─ macos-26 / Xcode 26.5
     ├─ Rust + cargo-swift 0.9.0 + xcodegen   (same contract-pinned toolchain as native-ios)
     ├─ just ios-typegen ; just ios-package release   (RELEASE core, device slice)
     ├─ xcodegen generate
     └─ bundle exec fastlane ios beta
          ├─ app_store_connect_api_key   (.p8 via secrets — auth for portal + upload)
          ├─ match(type: appstore, readonly)   (download cert+profile from certs repo)
          ├─ update_code_signing_settings   (flip the *generated* project to Manual + match profile)
          ├─ build_app   (Release archive → app-store .ipa, build number = github.run_number)
          └─ upload_to_testflight   (internal testing; skip_waiting_for_build_processing)
```

### Key decisions

1. **Credential = App Store Connect API key (`.p8`), not Apple ID.** No 2FA, no
   session expiry, headless-friendly. Role **App Manager** (Developer can upload
   a binary but cannot manage build/testers or create the app record).

2. **Signing = fastlane `match` (git storage), not pure cloud signing.** The
   widely-cited "API key + `-allowProvisioningUpdates`, no certs to store"
   recipe is **unreliable on ephemeral runners**: cloud signing covers the
   *export* step, but the *archive* still needs a signing identity whose private
   key lives on the build machine — on a fresh runner Xcode mints a cert on run
   #1 then run #2 fails "private key is not installed in your keychain" (Apple
   forums 695759, fastlane#19973). `match` stores the encrypted Apple
   Distribution cert + App Store profile in a private git repo and syncs them
   read-only into a temp keychain each run. Standard, reproducible, scales to a
   second machine/dev. (Alternative considered: manual `.p12` import — fewer
   moving parts but manual ~yearly cert rotation. Rejected for higher ongoing
   toil.)

3. **Signing config stays OUT of `project.yml`.** The daily loop (`just ios`,
   `just ios-run`, snapshot tests) builds for the simulator with **Automatic**
   signing and must stay untouched. So `project.yml` keeps no signing keys
   (Xcode default = Automatic); the lane flips the *generated* `.xcodeproj` to
   Manual + the match profile via `update_code_signing_settings` **after**
   `xcodegen generate`, **before** `build_app`. The unsigned simulator lanes are
   unaffected because they pass `CODE_SIGNING_ALLOWED=NO` on the xcodebuild
   command line, which overrides project settings.

4. **Build number = `github.run_number`**, injected as a `CURRENT_PROJECT_VERSION`
   xcodebuild build setting (not PlistBuddy — under `GENERATE_INFOPLIST_FILE=YES`
   `CFBundleVersion` is generated from `CURRENT_PROJECT_VERSION`). `run_number`
   is monotonic across the repo, satisfying TestFlight's "unique build per
   version" rule. `MARKETING_VERSION` is derived from the release tag
   (`v0.3.0` → `0.3.0`), validated as `X.Y.Z` in the lane and injected the
   same way, so each tagged release appears in TestFlight as a new version.
   When unset (local runs, branch dispatch) the lane falls back to
   `project.yml`'s value.

5. **Release core, device slice.** The lane runs `cargo swift package … --release`
   (debug cores are 10–100× slower in hot paths). Verified at source level
   (cargo-swift v0.9.0): `--platforms ios` emits the `aarch64-apple-ios` **device**
   slice alongside the simulator slice — the device slice an archive requires.

6. **A tagged build carries its Sentry release, and one that cannot report
   does not build.** `SENTRY_DSN_NATIVE` is baked in at `xcodegen generate`,
   where it expands into the `SENTRY_DSN` build setting the partial Info.plist
   reads, and the lane refuses a tag outright when it is missing, before the
   10x-billed macOS build: a shipped build with crash reporting off is
   invisible until a tester hits a crash. After the upload the lane creates the
   Sentry release with a pinned `sentry-cli`, not `getsentry/action-release`,
   which is a Docker container action and cannot run on a macOS runner. The
   release name is read back from the uploaded `.ipa`, from the same three
   Info.plist keys `SentryRelease.name(for:)` composes at runtime, so the name
   Sentry holds cannot drift from the one the app reports (#1553). Uploading
   the debug symbols, so a crash names a line rather than an address, is
   tracked in #1610.

7. **Internal testing only, for now.** `skip_waiting_for_build_processing: true`
   for a fast loop. External testing (Beta App Review + changelog) is out of
   scope until there are external testers.

### Files

| File | Role |
|------|------|
| `Gemfile` | pins `fastlane 2.236.1` |
| `fastlane/Appfile` | `app_identifier`, `team_id` (API key supplies the rest) |
| `fastlane/Fastfile` | the `beta` lane |
| `fastlane/Matchfile` | certs-repo URL, `appstore` type |
| `.github/workflows/release-testflight.yml` | the lane's CI job |
| `ios/Intrada/Info.plist` | `ITSAppUsesNonExemptEncryption = false` (export compliance) |
| `justfile` | `just testflight` recipe (local parity) |
| `ios/Intrada/Core/SentryRelease.swift` | the release name the app reports, composed to match the lane's |

## One-time human setup (gates the first run — CI cannot bootstrap these)

Done once by the account holder, in order (each depends on the prior):

1. **Accept agreements** — App Store Connect → confirm the Developer Program
   License Agreement shows **Active**. (Free TestFlight app needs no Paid Apps
   agreement.)
2. **Register the bundle id** `com.intrada.native` — Certificates, Identifiers &
   Profiles → Identifiers. No special capabilities needed today.
3. **Create the app record** — Apps → + → New App (iOS, the bundle id, any SKU).
   *Cannot be scripted with the API key — one manual click.*
4. **Create the API key** — Users and Access → Integrations → **Team Keys**
   (not Individual) → role **App Manager**. Save Key ID, Issuer ID, and the
   `.p8` (downloadable **once**).
5. **Create the certs repo** — an empty **private** GitHub repo, e.g.
   `jonyardley/intrada-certificates`. Pick a strong `MATCH_PASSWORD`.
6. **Bootstrap match (local, Ruby 3.x):** `bundle install` (then commit the
   generated `Gemfile.lock`), then `fastlane match appstore` — generates +
   encrypts + pushes the Apple Distribution cert + App Store profile to the certs
   repo (authenticate with the Apple ID when prompted; one time).
7. **GitHub Actions secrets** (repo → Settings → Secrets and variables → Actions):
   `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT_BASE64` (`base64 -i AuthKey_*.p8`),
   `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION` (`printf 'user:github_pat' | base64`),
   `MATCH_PASSWORD`.
8. **First run** — `workflow_dispatch` the workflow; after processing, add
   yourself to an Internal Testing group in the TestFlight tab and install.

(Local `fastlane` needs Ruby ≥ 3.0 — system Ruby 2.6 is too old; use `rbenv`.
CI uses Ruby 3.3.)

## Open questions / first-run risks

- **`update_code_signing_settings` on the xcodegen project** — edits the
  generated `.pbxproj` after generation; confirm the `Intrada` target name +
  match profile name (`match AppStore com.intrada.native`) match on the first run.
- **`export_method`** — uses `app-store` (universally accepted by fastlane);
  Xcode 26.5 prints a "use app-store-connect" deprecation warning — harmless.
- **`Gemfile.lock`** — the `Gemfile` pins fastlane exactly; the full transitive
  lock is generated + committed during bootstrap (step 6), since Ruby 3 isn't
  available in this worktree (system Ruby 2.6). Until it lands, CI resolves deps
  fresh with fastlane still pinned.
- **First archive on a brand-new account** — the App Store profile may take a
  retry to propagate; match handles cert/profile but the app record must exist.

## Out of scope (future)

External TestFlight testers (Beta App Review), App Store submission/release,
dSYM upload to Sentry for the native app, screenshot/metadata automation
(`deliver`).
