# Removing the API (#1746)

Status: decided 2026-09-12. This spec rides as the first commit of the
removal and records why, what goes, what stays and what is Jon's to do
outside the repo. Any future web presence or sync service is built from
scratch against a new spec, not by reviving this one.

## Decision

The app is a native iOS practice notebook that already works with no
network and no account (`specs/native-ios.md`, `.claude/rules/offline-first.md`).
The API carried four things: item, session and set sync; account
preferences and deletion; MCP tokens and their audit log; the OAuth
consent flow for the MCP server. None of them is on the roadmap
(`docs/roadmap.md`), no screen in `ios/Intrada` reads the account, token or
OAuth parts of the ViewModel, and the app starts local-first. A server
nobody depends on still costs a Fly machine, a Sentry project, Clerk, and
two CI jobs on every push to main.

So the API goes, and the client code that only existed to talk to it goes
with it. Code with no reader is deleted, not parked (#1176); git is the
parking space and this document names the recovery point.

## What goes

Two PRs, independent because `intrada-api` depends on `intrada-core` and
not the other way round. They ride on separate branches so they can be
built in parallel and merged in either order.

### PR 1: the crate and its infrastructure (branch `remove-api-1746`)

- `crates/intrada-api/` and its workspace member line in `Cargo.toml`.
- `Dockerfile`, `.dockerignore`, `fly.toml`.
- `.github/workflows/ci.yml`: the `api-docker-build` and `deploy-api` jobs,
  the `crates/intrada-api/**` path filter in `changes`, and the two names in
  `alert-on-red-main`'s `needs`. The `test`, `msrv`, `clippy`, `fmt` and
  `security` jobs stay for the two remaining crates.
- `codecov.yml` and `deny.toml` entries that only the API needed.
- `scripts/seed-dev-data.sh` (seeds the API's database) and the `just`
  recipes that call it or run the server.
- `docs/mcp-setup.md`; the API sections of `SETUP.md`, `docs/reference.md`
  and `README.md`; the `.env.example` keys the server read.
- `CLAUDE.md`: the crate list, the Auth and DB bullets, the mutate-response
  bullet and the `crux_http` clause of the architecture section.
- `specs/mcp-server.md` and `specs/account-settings-and-deletion.md` move to
  `specs/_archive/` and leave the live table in `specs/README.md`.
- `.claude/rules/sensitive-surfaces.md` and any other rule naming the API
  as a surface.

### PR 2: the client side in core and the shell (branch `remove-sync-1746`)

- `crates/intrada-core/src/http.rs` and the `crux_http` dependency,
  including its `facet_typegen` feature line.
- The `Account`, `McpToken` and `OAuth` event arms and their domain modules
  (`domain/account.rs`, `domain/mcp_tokens.rs`, `domain/mcp_audit.rs`,
  `domain/oauth.rs`), the `Http` effect variant, `api_base_url` on the
  model, the `apiBaseUrl` argument of `StartApp`, `RefetchItems` and
  `RefetchSessions`, and the ViewModel fields these fed.
- The write paths in `domain/item.rs`, `domain/session.rs` and
  `domain/set.rs` keep their temp-id and reconcile shape against the local
  store but stop issuing HTTP commands after the persistence write.
- Regenerated `ios/generated/`; `Store.handleHttp` and its `URLSession`;
  the hard-coded API URL in `RootView.swift`.
- Tests that only exercised HTTP request construction go; tests of the
  local write path stay and must still pass with the HTTP arm deleted.

## What stays

- `intrada-core` and `intrada-ffi`, GRDB persistence, the crash-recovery
  snapshot and its key, the Sentry iOS SDK, the TestFlight lane.
- `docs/rebuild-review.md`, `docs/audit-2026-08.md` and the archive: they
  are history and say so.
- `graphify-out/`: it goes stale with this change and is rebuilt on its
  own, never without `.graphifyignore`.

## Outside the repo, Jon's after merge

- Export the Turso database, then destroy the Fly app `intrada-api`.
- Delete the Sentry `intrada-api` project and the Clerk application.
- Remove the claude.ai Intrada connector, which has no other client.
- Delete the deploy secrets the removed CI jobs read from GitHub.

## Recovery

Everything removed is in git history before the merge commits of the two
PRs. `git log --all -- crates/intrada-api` finds the last commit that held
the crate; `git show <hash>:crates/intrada-core/src/http.rs` recovers the
client. A future sync design should start from `.claude/rules/offline-first.md`,
which is where the invariants live, not from this code.
