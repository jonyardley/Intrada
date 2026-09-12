# MCP server (agent-callable API)

> Tier 3 per CLAUDE.md (new top-level feature, auth-sensitivity override).
> No GitHub issue yet — would slot under Layer 5 (Guide) / `pillar:plan` +
> `pillar:track`. Open a tracking issue before starting Phase 1.

## Problem

intrada has rich practice data — items (pieces & exercises), sets (routines),
sessions with scoring, weekly analytics — and no agent-friendly way to
interact with it. A user who wants to ask their AI assistant *"what should I
focus on this week?"* or *"set me up with the Bach Cello Suites"* has to
pivot into the app and do the work by hand. That kills the use case where
the agent does the planning work and the app does the practice work.

An [MCP server](https://modelcontextprotocol.io/) exposes the API as tools
an LLM client (Claude Desktop, Cursor, custom agents, web-based agents) can
call on the user's behalf — read their library, populate it from
natural-language prompts, summarise practice patterns, and feed enough
structured context for the agent to give informed advice.

This is the cheapest concrete step into Layer 5 (Guide) territory: the AI
advice surface lives in the user's existing chat client, not in a new
in-app feature.

## Goals

1. A user with an MCP-capable agent client can connect intrada and grant
   the agent scoped access to their account.
2. The agent can list and create pieces, exercises, and routines on the
   user's behalf — including bulk imports from natural-language prompts.
3. The agent can query practice history and analytics in enough detail to
   give substantive advice without requiring the user to paste data into
   chat.
4. Tokens are scoped, revocable, and visible in account settings.
5. No regression in trust model: an MCP token cannot do anything a
   logged-in user couldn't do.

## Non-goals

- **No `get_advice` tool.** The agent is the advice engine. The MCP server
  exposes data and primitives; the agent reasons over them. Hard-coding
  advice prompts into a server-side tool is strictly worse.
- **No real-time/streaming integration** (live tempo into the agent during
  practice). Out of scope.
- **No multi-tenant agent flows** (an agent acting on behalf of multiple
  users in one session). Token = one user.
- **No third-party developer platform.** The OAuth surface is for end-user
  MCP clients, not for third-party apps building on intrada. Separate spec
  if we ever go there.
- **No tools for `lessons`** in v1. Lessons (the photo-attached lesson
  capture surface) have different access patterns than user-authored
  library content; revisit in a future phase if agent demand emerges.

## Approach

### Architecture

```text
┌────────────────────────────────────────────────────────────────────┐
│  MCP client (Claude Desktop, Cursor, web agent, …)                 │
│   • OAuth or PAT bearer token                                      │
│   • Calls tools: list_items, create_item, get_practice_summary, …  │
└────────────────────────────────────────────────────────────────────┘
                              │ MCP over HTTP+SSE
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│  intrada-api (Fly.io)                                              │
│                                                                    │
│   New crate: intrada-mcp (mounted as a sibling router)             │
│                                                                    │
│   • /api/mcp/*                              MCP endpoint (HTTP+SSE)│
│   • /api/account/tokens/*                   PAT CRUD (Phase 2)     │
│   • /oauth/*                                OAuth 2.1 (Phase 5)    │
│   • /.well-known/oauth-authorization-server OAuth discovery (RFC   │
│                                             8414, Phase 5)         │
│                                                                    │
│   MCP + PAT live under /api for CORS/middleware consistency with   │
│   existing routes. OAuth endpoints live at root per RFC convention │
│   (/.well-known/* MUST be at root).                                │
│                                                                    │
│   Tool handlers share a service layer with existing HTTP routes.   │
│   Same auth extractor — token resolves to a user_id, identical     │
│   per-user scoping as the JWT path.                                │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    Turso (libsql) — same DB
```

### Auth: PAT first, OAuth later

**Phase 2 — PAT.** User generates a token in account settings. Token is a
randomly-generated opaque string, hashed at rest with prefix-shown-once UX
(GitHub PAT pattern: `intrada_pat_xxxxxxxxxxxx`). Stored in a new
`mcp_tokens` table: `(id, user_id, name, hash, prefix, last_used_at,
created_at, revoked_at)`. The MCP endpoint accepts
`Authorization: Bearer intrada_pat_…`, looks up by hash, returns
`AuthUser(user_id)` exactly like the existing JWT path.

**Phase 5 — OAuth 2.1 + DCR.** MCP clients increasingly support
[Dynamic Client Registration](https://datatracker.ietf.org/doc/html/rfc7591).
intrada-api adds an OAuth server (`/oauth/register`, `/authorize`,
`/token`). Authorize page lives on intrada-web; user is already in a
Clerk session (or signs in via Clerk), confirms scope, returns to client
with auth code. Token mints into the same `mcp_tokens` table.

Both paths coexist — the auth extractor doesn't care how the token was
minted.

### Hosting: route inside intrada-api, not a separate service

A new `crates/intrada-mcp` library crate plugged into intrada-api's router
under `/mcp`. Reasons:

- Same `AppState` (DB, auth config) — no IPC, no separate deploy.
- Tool handlers can call into the shared service layer rather than going
  through HTTP loopback.
- Single Fly.io deploy, single secrets surface, single CI path.

### Tool surface (Phase 3 + 4)

Reads:

| Tool | Returns |
|------|---------|
| `list_items(kind?)` | All pieces or exercises for the user |
| `get_item(id)` | Item detail with notes, tempo targets |
| `list_sets` | Routines |
| `get_set(id)` | Routine with ordered item list |
| `list_sessions(start?, end?)` | Practice sessions in window |
| `get_session(id)` | Session with per-item scores |
| `get_practice_summary(start, end)` | **Wide view** — pre-joined: total minutes, items practiced, score trends, focus distribution |

Writes:

| Tool | Effect |
|------|--------|
| `create_item({title, kind, …})` | Create a piece or exercise |
| `update_item(id, …)` | Edit fields |
| `delete_item(id)` | Remove |
| `create_set({title, item_ids, …})` | Create a routine |
| `update_set(id, …)` | Edit routine |
| `bulk_import_items([…])` | Atomic batch — the killer one |

No write tools for sessions or scoring. Practice happens in the app;
agents plan and review.

### Confirmation model for writes

Default risk: an agent calling `create_item` ten times based on a misread
prompt. Mitigations:

1. **Bulk-only previews.** Single-item writes execute immediately. Bulk
   writes (`bulk_import_items`) require `dry_run: true` first, returning
   a structured preview. The agent shows it to the user, confirms, then
   re-calls with `dry_run: false`. Native MCP idiom.
2. **All writes audited.** New `mcp_audit_log` table:
   `(id, token_id, tool, args_hash, created_at)`. Visible in account
   settings.
3. **All writes reversible.** Existing soft-delete pattern means the user
   can undo any agent mistake from the app.

## Key decisions

1. **Live inside intrada-api**, not a separate service. One auth, one
   deploy, one DB pool.
2. **PAT in v1; OAuth in v2.** Validates value before investing in OAuth
   server. `mcp_tokens` schema supports both from day one.
3. **No `get_advice` tool.** The agent advises; the server exposes data.
4. **Wide-view read tools** (`get_practice_summary`) are first-class. The
   agent shouldn't need 10 round-trips to answer a typical weekly question.
5. **Write tools for items + sets only.** Not sessions. Practice ≠
   planning.
6. **Bulk writes use `dry_run`; single writes don't.** Reversible + audited
   is enough for single ops; bulk is where blast radius matters.
7. **Wire protocol uses API terminology** (`items`, `sets`). Tool *descriptions*
   in JSON schemas use user-facing language ("a piece or exercise", "a
   routine — an ordered list of items"). Agents read the descriptions;
   users never see the wire names.
8. **Tool handlers share a service layer with HTTP routes.** Phase 1 is a
   pure refactor: extract per-route business logic into
   `intrada-api/src/services/` so MCP and Axum handlers both call into it.
   Avoids duplicate code and "MCP behaves subtly differently from web"
   bugs.
9. **Validation stays in `intrada-core`** (already imported from
   `routes/items.rs`, `routes/sets.rs`, `routes/sessions.rs`,
   `routes/lessons.rs`). Phase 1 ensures the new service layer routes
   bulk writes through the same `intrada_core::validation` calls so MCP
   gets identical rejection logic to HTTP — no duplication, no drift.
10. **Single flat scope for v1.** A token can do anything the user can.
    Granular read/write/per-resource scopes are deferred until there's a
    concrete reason (third-party clients, untrusted agents) — the
    `mcp_tokens` schema leaves room for a `scopes` column to add later.
11. **Rate limit: 60 req/min per token**, returned as 429 with
    `Retry-After`. Per-token (not per-user) so a misbehaving agent
    doesn't lock the user out of their other tokens.
12. **Discoverability: account settings only.** No dashboard CTA. Users
    discover the integration deliberately rather than being nudged into
    it; reduces support surface for a feature that's still maturing.
13. **Local dev: PAT bound to a sentinel user.** When `CLERK_ISSUER_URL`
    is unset, dev mode mints a PAT for a fixed sentinel `user_id` so
    devs don't need a Clerk account to exercise MCP locally. Same sentinel
    is used by the existing `AuthUser("")` fallback path, swapped to a
    real ID for the MCP path.

## Open questions

1. **iOS PAT entry UX.** The settings page is shared web+iOS. Does the
   user generate the PAT on iOS, copy, paste into Claude Desktop on a
   different device? Affects the once-shown UX. Pencil first during
   Phase 2.
2. **Tauri-as-MCP-host forward-look.** If the iOS app itself becomes an
   MCP host (agent → app inline), the same backend serves it. No spec
   changes; just an additional client. Noted so we don't paint ourselves
   into a corner.

## Phasing

Each phase is its own PR.

1. **Phase 1 — Service-layer refactor.** Extract per-route business logic
   into `intrada-api/src/services/`. No behaviour change. Existing tests
   prove it. Adds `intrada-core` as an `intrada-api` dependency for
   shared validation.
2. **Phase 2 — PAT issuance.** New `mcp_tokens` table, `/account/tokens`
   CRUD, account-settings UI (web + iOS, **Pencil first**). Behaves like
   a real auth path — you can curl the API with one. No MCP server yet.
3. **Phase 3 — MCP server, reads only.** New `intrada-mcp` crate mounted
   at `/mcp`. List/get tools for items, sets, sessions, plus
   `get_practice_summary`. Agent gives meaningful advice on read data
   alone — useful checkpoint to gather feedback before touching writes.
4. **Phase 4 — Write tools.** Item + set creation, updates, deletes,
   `bulk_import_items` with `dry_run`. `mcp_audit_log` table + UI to
   view it.
5. **Phase 5 — OAuth 2.1 + DCR.** OAuth server in intrada-api, authorize
   page in intrada-web, DCR endpoint. Existing PATs keep working.
6. **Phase 6 — Polish.** Rate limits (Phase 4 launch-blocker, formalised
   here), discoverability CTAs, telemetry (Sentry spans on tool calls),
   docs.

## Acceptance criteria

- [ ] User can generate a PAT in account settings, copy it once
      (visible only at creation), see prefix + last-used afterward,
      revoke at any time.
- [ ] Claude Desktop configured with `intrada-mcp` URL + PAT lists a
      seeded test account's items, sets, and sessions.
- [ ] `get_practice_summary(last 7 days)` returns total minutes, score
      trends, and focus distribution in one call.
- [ ] `bulk_import_items` with `dry_run: true` returns a preview without
      writing; with `dry_run: false` writes atomically (all or nothing).
- [ ] Every MCP write appears in `mcp_audit_log` and is visible to the
      user in account settings.
- [ ] Revoking a token immediately invalidates new requests on it.
- [ ] Rate limit (60 req/min per token) returns 429 with retry-after.
- [ ] No regression on existing API: web + iOS auth paths unchanged.
- [ ] Service-layer refactor: no test failures, no behaviour change
      visible to existing API consumers.

## References

- MCP spec: <https://modelcontextprotocol.io/>
- MCP transports: <https://modelcontextprotocol.io/docs/concepts/transports>
- OAuth 2.1 + DCR (RFC 7591): <https://datatracker.ietf.org/doc/html/rfc7591>
- Existing auth extractor: `crates/intrada-api/src/auth.rs`
- Existing routes: `crates/intrada-api/src/routes/mod.rs`
- Validation: `crates/intrada-core/src/validation.rs`
- Roadmap layer 5 / Guide: `docs/roadmap.md`
