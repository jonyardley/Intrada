# SEO: Prerender Marketing Routes (#637)

> **⚠️ Superseded by the 2026-07 practice-coach pivot.** This document describes
> the practice-*notebook* product — hand-built sessions, self-rated scores,
> written reflection. The live design is
> [`specs/intrada-practice-coach-design.md`](../intrada-practice-coach-design.md) with the scenarios in
> [`docs/coach-user-journeys.md`](../../docs/coach-user-journeys.md). Kept for archaeology; **do not
> implement from this document.** **Obsolete, not merely superseded:** the Leptos web shell it targets was deleted in #1133.

## Problem

After #636 (meta tags), crawlers see `<meta>` and `<noscript>` content but
the `<body>` is effectively empty — the marketing homepage's hero, pillars,
features, and CTAs only exist after WASM mounts. Google will crawl JS-rendered
pages eventually, but rankings and previews suffer. The fix is to ship
prerendered HTML so crawlers see real content on first fetch.

## Routes to prerender

| Route    | View          | Notes |
|----------|---------------|-------|
| `/`      | WelcomeView   | Full marketing page — hero, pillars, features, CTA |
| `/login` | LoginView     | Sign-in card with brand |

Future routes (`/privacy`, `/terms`, `/about`, `/pricing`) join the list when
they exist. The script is route-list-driven — adding a new one is a one-line
change.

## Approach

### Build-time prerender with Playwright

A Node.js script (`scripts/prerender.mjs`) runs **after** `trunk build` and
**before** the Sentry inject / SRI refresh / wrangler publish chain in CI.

Steps:
1. Copy `dist/index.html` → `dist/_app.html` (SPA shell, kept for non-marketing routes)
2. Start a local HTTP server on `dist/` with SPA fallback to `_app.html`
3. For each marketing route:
   a. Open headless Chromium via Playwright
   b. Navigate to the route
   c. Wait for substantial body content (same heuristic as deploy-smoke: `body.innerText.length > 100`)
   d. Capture `document.documentElement.outerHTML`
   e. Write to the correct path in dist:
      - `/` → `dist/index.html`
      - `/login` → `dist/login/index.html`
4. Shut down the server

The prerendered HTML includes all `<script>` and `<link>` tags from the
original shell — WASM still loads and Leptos takes over the DOM. Since the
prerendered content matches what CSR produces for an unauthenticated user,
the visual transition is seamless.

### Worker.js routing

Prerendered HTML lives in `dist/prerendered/` (not overwriting `index.html`).
`wrangler.toml` keeps `not_found_handling = "single-page-application"` — the
SPA shell (`index.html`) is still the fallback for all app routes. Worker.js
intercepts marketing routes and serves from `dist/prerendered/` before the
SPA fallback triggers:

```javascript
const PRERENDERED = { "/": "/prerendered/index.html", "/login": "/prerendered/login.html" };
// ... in fetch handler: lookup normalizedPath in PRERENDERED, serve via env.ASSETS.fetch()
```

This avoids the `_app.html` rename approach from the original design — simpler,
and no changes to `wrangler.toml` are needed.

### Auth during prerender

`WelcomeView` calls `expect_context::<AuthState>()`. During prerender in
headless Chrome:
- Clerk init fires but has no valid session → `auth_loading` eventually
  resolves to false, `is_authenticated` stays false
- The marketing content renders immediately (before auth resolves)
- The redirect `Effect` never fires (user isn't authenticated)
- Snapshot is captured after marketing content appears but before any
  potential timeout/error states

This is proven to work — `deploy-smoke.spec.ts` already loads the WASM app
in headless Chromium and asserts body content > 100 chars.

`LoginView` similarly renders its sign-in card for unauthenticated users.

### CI pipeline integration

Current: `trunk build` → artifact → sentry inject → SRI refresh → deploy

New: `trunk build` → **prerender** → artifact → sentry inject → SRI refresh → deploy

The prerender step runs in the `wasm-build` job (or a new job after it) and
the prerendered HTML is included in the `web-dist` artifact. This means:
- deploy-smoke tests exercise the prerendered dist
- E2E tests run against the prerendered dist
- The sentry inject step modifies JS files (not HTML body content), so SRI
  recompute still works

## Key decisions

**CSR re-render, not hydration.** True Leptos hydration requires SSR mode
(server-side rendering), which is a fundamentally different architecture.
CSR re-render means the WASM replaces the prerendered DOM when it loads —
since content matches, there's no visible flash. The tradeoff: a brief moment
where interactive elements (buttons, links) are visible but inert. For
marketing pages this is acceptable — the CTA just needs to work within a few
seconds of page load, and the prerendered content provides immediate visual
feedback.

**Universal prerender, not bot-only.** All users see prerendered HTML, not
just crawlers. Benefits: faster first paint for everyone, no user-agent
sniffing (which is fragile and borderline cloaking). The WASM loads on top
regardless.

**Playwright, not a custom renderer.** We already have Playwright in the E2E
pipeline. Using it for prerender avoids adding a new tool and guarantees the
snapshot matches what a real browser renders.

## Files changed

| File | Change |
|------|--------|
| `scripts/prerender.mjs` | New — Playwright prerender script |
| `worker.js` | Intercept marketing routes, serve from `dist/prerendered/` |
| `scripts/refresh-sri-hashes.py` | Scan all HTML files in dist/ (not just index.html) |
| `scripts/verify-sri-hashes.py` | Same — scan all HTML files |
| `.github/workflows/ci.yml` | Add prerender step + widen sed placeholder injection to all HTML |
| `e2e/tests/deploy-smoke.spec.ts` | Assert prerendered `/` and `/login` contain expected content |

## Acceptance

- `curl https://myintrada.com/` returns HTML with hero copy, h1, CTAs visible in body
- `curl https://myintrada.com/login` returns HTML with sign-in card content
- Lighthouse SEO score > 90 on marketing routes
- SPA routing still works for authenticated users (no regression)
- E2E smoke test asserts prerendered `/` contains expected hero text
- `cargo test` + `cargo clippy` still pass (no Rust changes expected)
