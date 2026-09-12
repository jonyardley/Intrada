# Account settings & GDPR account deletion

> Tier 3: touches auth, multi-table DB delete, Clerk Backend API,
> and a new top-level UI surface.

## Problem

Two related gaps:

1. **No account / settings surface.** The mobile app (iOS via Tauri) has no
   way to sign out — `bottom_tab_bar` is feature nav only. The web header has
   a bare "Sign out" link but no profile, no preferences, no destructive
   actions. As feature surface grows (default duration/reps, mid-session
   settings, future preferences), there's no home for them.
2. **No account deletion.** GDPR Art. 17 ("right to erasure") requires we
   honour deletion requests. We currently can't — there's no endpoint, no
   UI, and Clerk users persist forever even if the local data goes away.

## Goals

- Single shared "Settings" surface, reachable from a profile button in the
  app header, available on both web and iOS.
- v1 contents:
  - Account row: signed-in email + "Sign out" + "Delete account" (destructive).
  - Session defaults: default focus duration, default rep count.
- New `DELETE /api/account` endpoint that hard-deletes all rows scoped to the
  authenticated `user_id` across every user-scoped table, then deletes the
  Clerk user via the Backend API, then signs the client out.
- Clear, friction-bearing confirmation: a modal listing exactly what will be
  erased, plus type-to-confirm ("delete my account").

## Non-goals

- Data export ("download my data"). Worth doing for GDPR portability later;
  out of scope here.
- Soft-delete / 30-day grace window. Hard delete is simpler and meets Art. 17.
  If a user changes their mind mid-flow they can cancel; once submitted, gone.
- Email-confirmation step. Clerk already verified the email at sign-in. The
  in-app confirmation modal is the friction.
- Profile editing (name, photo). Clerk owns identity; we don't surface it.
- Per-device vs per-account preference scope. Session defaults are stored
  server-side, scoped to user. (See open questions.)

## Approach

### UI surface

**Entry point.** New `ProfileButton` component in `app_header.rs`, top-right,
replacing the existing bare "Sign out" link. Shows a Clerk avatar (initials
fallback). On tap/click: opens a `BottomSheet` (existing primitive — already
behaves as a modal sheet on mobile, centred dialog on desktop).

**Settings sheet contents** (v1):

- Header: avatar + email (from Clerk).
- "Practice defaults" section (`GroupedList`):
  - Default focus duration (minutes) — number input.
  - Default rep count — number input.
- "Account" section (`GroupedList`):
  - Sign out — neutral row.
  - Delete account — destructive row (red, chevron).

**Delete confirmation.** Tapping "Delete account" pushes a second screen
(full-screen on iOS, centred modal on web) with:

- Title: "Delete your account?"
- Body: bullet list of what will be erased (pieces, exercises, sessions,
  routines, goals, lessons, lesson photos, Clerk account).
- "This cannot be undone."
- Type-to-confirm: text field requiring exact string `delete my account`.
- Two buttons: "Cancel" (default) and "Delete account" (destructive,
  disabled until confirmation text matches).

After tapping the destructive button: button shows spinner, calls
`DELETE /api/account`, on success signs out via Clerk and routes to `/`. On
failure: error banner, button re-enabled.

### API

New route module `intrada-api/src/routes/account.rs`:

```
DELETE /api/account
```

Auth required. Response: `204 No Content` on success, `5xx` on failure.

Handler responsibilities, in order:

1. Resolve `user_id` from `AuthUser` extractor. Reject if empty (no auth).
2. **Delete user data.** Single libsql transaction (Turso supports
   transactions on a single connection):
   - `DELETE FROM lesson_photos WHERE user_id = ?`
   - `DELETE FROM lessons WHERE user_id = ?`
   - `DELETE FROM sessions WHERE user_id = ?` (cascade-cleans `setlist_entries` via app-level delete inside the same txn)
   - `DELETE FROM items WHERE user_id = ?`
   - `DELETE FROM routines WHERE user_id = ?` (cascade-cleans `routine_entries` via app-level delete inside the same txn)
   - `DELETE FROM user_preferences WHERE user_id = ?` (new — see below)

Note: `setlist_entries` and `routine_entries` are not directly user-scoped
(they reference parent `session_id` / `routine_id`) — child rows are deleted
by joining through the parent's `user_id`, e.g.
`DELETE FROM setlist_entries WHERE session_id IN (SELECT id FROM sessions WHERE user_id = ?)`.
3. **Delete Clerk user.** New `ClerkClient::delete_user(user_id)` calling
   `DELETE https://api.clerk.com/v1/users/{user_id}` with
   `Authorization: Bearer $CLERK_SECRET_KEY`. If `CLERK_SECRET_KEY` is unset
   (local dev): skip with a warn log.
4. Return `204`.

Photo cleanup was step 3 here until the R2 module was deleted (#281 closed as
stale, bucket empty): photos are on-device files now, so account deletion has
no server-side blobs to reap.

**Failure ordering.** DB delete first, then Clerk. If DB succeeds but Clerk
fails, the user can re-run delete from the UI (idempotent: DELETE WHERE
user_id finds zero rows, Clerk returns 404 which we treat as success).

### New tables / migrations

- `0054_create_user_preferences` — `user_id TEXT PRIMARY KEY, default_focus_minutes INTEGER, default_rep_count INTEGER, updated_at TEXT NOT NULL`
- Indexes already exist for the user_id column on every other table.

`GET /api/account/preferences` and `PUT /api/account/preferences` for the
session defaults form. Schema is small, so a single row keyed by user_id.

### Crux core

Settings sheet is UI-only state plus one API call (preferences). Two new
events on the existing `Event` enum:

- `LoadAccountPreferences` → fires `Http::get` → `AccountPreferencesLoaded`
- `SaveAccountPreferences { default_focus_minutes, default_rep_count }`
  → fires `Http::put`
- `DeleteAccount` → fires `Http::delete /api/account` → `AccountDeleted`

`Model` gains `account_preferences: Option<AccountPreferences>` and
`delete_in_flight: bool`. ViewModel exposes both.

Session-start flow reads `account_preferences` for default duration / reps
when initialising a new session — that's how project_session_defaults gets
delivered. (Mid-session edits — project_mid_session_settings — stay
out of scope; tracked separately.)

### Clerk Backend API

New module `intrada-api/src/clerk.rs`:

```rust
pub struct ClerkClient { secret_key: String }
impl ClerkClient {
    pub fn from_env() -> Option<Self> { /* CLERK_SECRET_KEY */ }
    pub async fn delete_user(&self, user_id: &str) -> Result<(), ApiError>;
}
```

Wired into `AppState` next to `r2`. Optional — `None` means local dev
skips the Clerk call.

### Web client

- `clerk_bindings.rs` already has `sign_out()`. Add `email()` to read
  `window.__intrada_auth.user.primaryEmailAddress.emailAddress`.
- New component `components/profile_button.rs`.
- New view `views/settings.rs` (rendered inside a `BottomSheet`).
- New view `views/account_delete.rs` (full-screen confirmation).

## Key decisions

| Decision | Choice | Why |
|---|---|---|
| Hard vs soft delete | Hard | GDPR Art. 17; soft-then-purge adds infra without user benefit |
| R2 cleanup strategy | Best-effort prefix list | DB row is the index; orphaned blobs are wasted bytes, not a privacy hole (keys include user_id and have no public listing) |
| Clerk deletion timing | Last | If it fails, user re-runs delete; idempotent. Failing first would leave Clerk user orphaned with no local data. |
| Preferences storage | Server-side, per-user | Survives device wipe; single source of truth. |
| Confirmation friction | Type-to-confirm | Industry standard (GitHub, Stripe, Vercel); cheap to build, prevents accidents |
| Settings entry point | Profile button in `AppHeader` | Already on every screen; consistent web + iOS |
| iOS presentation | `BottomSheet` primitive | Already exists; native-feel; chrome unchanged |

## Open questions

1. **iPad layout.** Should Settings sheet behave differently on iPad
   (popover anchored to the avatar vs full-width sheet)? Default to
   full-width sheet for v1; revisit if it looks wrong.
2. **Error handling for partial Clerk failure.** If DB delete succeeds but
   Clerk delete returns 5xx, do we surface a "your data is deleted but your
   Clerk session still exists — please retry" message, or sign the user out
   anyway and silently log the orphan? Lean toward signing out + logging;
   the user-visible state matches their intent.
3. **Default values for new preferences.** `session_new` currently
   exposes presets (10/15/20/30 mins) with no single "default duration"
   — and reps aren't surfaced in the picker at all. Lean: when the
   prefs row is missing, use 15 minutes (middle preset) and 10 reps
   as fallback. The "Practice defaults" Settings section becomes
   the place where users customise these for the custom-session flow.
4. **Rate limiting on DELETE /api/account.** Worth adding a basic limit
   (one delete per minute per IP) to prevent accidental double-submits? Or
   rely on idempotency + UI button-disable? Lean idempotency; revisit if
   we see issues.

## Plan of attack (rough; full plan in Plan mode)

1. Migration `0029_create_user_preferences`.
2. API: `clerk.rs`, `routes/account.rs`, wire into state.
3. Core: events + model + viewmodel for preferences and delete.
4. Web: `profile_button.rs`, `views/settings.rs`, `views/account_delete.rs`,
   wire into `app.rs` + `app_header.rs`.
5. Pencil: design Settings sheet + Delete confirmation (mobile-first frames).
6. E2E test: sign-in → open settings → delete → verify 401 on a follow-up
   API call (data gone, signed out).

## References

- [memory/project_session_defaults.md] — drives the "Practice defaults" section
- [memory/feedback_pre_push_checks.md] — fmt + clippy before push
- [memory/feedback_self_review_prs.md] — `/review` before reporting ready
- Clerk Backend API: https://clerk.com/docs/reference/backend-api/tag/Users#operation/DeleteUser
- GDPR Art. 17: https://gdpr-info.eu/art-17-gdpr/
