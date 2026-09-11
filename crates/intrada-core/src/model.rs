use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::analytics::{AnalyticsView, LastPractisedView};
use crate::domain::account::AccountPreferences;
use crate::domain::chart::{ChordChart, ScaffoldKind};
use crate::domain::item::{Item, ItemKind, Modality};
use crate::domain::mcp_audit::McpAuditEntry;
use crate::domain::mcp_tokens::{CreatedMcpToken, McpToken};
use crate::domain::profile::{Profile, ProfileField, ProfileView};
use crate::domain::session::{
    ActiveSession, ClickState, CompletionStatus, EntryStatus, PracticeSession, RepEvent,
    SessionStatus, SetlistEntry, SummarySession,
};
use crate::domain::set::Set;
use crate::domain::Metre;
use crate::domain::{LibrarySort, ListQuery};
use crate::recognition::PhotoDraft;
use crate::suggestion::SuggestedSession;

/// Internal application state — not exposed to shells.
#[derive(Debug, Default)]
pub struct Model {
    pub api_base_url: String,
    /// When true (set by the iOS shell at `StartApp`), the Library is local-
    /// first: reads hydrate from the on-device store and writes persist locally
    /// with no HTTP. The web shell leaves this false and stays online.
    pub local_first: bool,
    /// The device's UTC offset in minutes (BST = 60, New York = −240/−300),
    /// reported by the shell via `SetUtcOffset` at launch and on foreground.
    /// Turns UTC instants into user-local days for analytics (#1330); 0 until
    /// the shell reports, which degrades to the old UTC day boundary.
    pub utc_offset_minutes: i32,
    pub items: Vec<Item>,
    pub sessions: Vec<PracticeSession>,
    pub session_status: SessionStatus,
    pub active_query: Option<ListQuery>,
    pub active_sort: LibrarySort,
    pub last_error: Option<String>,
    /// Where the current error is, when the handler that set it could say.
    /// Cleared before every event in `App::update`, so it always belongs to the
    /// error the event in hand reported. It says nothing about shell state that
    /// has changed since, which is the shell's to drop (#1595).
    pub last_error_target: Option<FormErrorTarget>,
    /// Set when the user dismisses the error banner. While true, errors from
    /// HTTP failures routed through [`Model::surface_error`] are silently
    /// swallowed — avoids the "dismiss → next refetch fails → banner
    /// reappears" loop when the underlying problem (network down, auth
    /// expired) hasn't been resolved. Cleared by any confirmed API success
    /// via [`Model::record_success`], signalling the system has recovered
    /// and new failures are worth surfacing again (#346).
    pub error_muted: bool,
    pub sets: Vec<Set>,
    pub practice_summaries: HashMap<String, ItemPracticeSummary>,
    /// Per-user practice defaults; `None` until first load completes.
    pub account_preferences: Option<AccountPreferences>,
    /// Device data, not account data: survives sign-out (`specs/profile.md`).
    pub profile: Profile,
    /// True while a `DELETE /api/account` request is outstanding.
    pub delete_in_flight: bool,
    /// One-shot terminal signal: server confirmed the account was
    /// deleted. The shell watches this to sign out + route home.
    /// Does not reset (account is gone; nothing to reset to).
    pub account_deleted: bool,
    /// MCP Personal Access Tokens for the current user. Newest first.
    pub mcp_tokens: Vec<McpToken>,
    /// Set to `true` after the first successful `LoadTokens` so the UI can
    /// distinguish "loading" from "loaded but empty".
    pub mcp_tokens_loaded: bool,
    /// True while a token list / create / revoke request is outstanding.
    pub mcp_tokens_loading: bool,
    /// Set transiently after `CreateToken` succeeds — carries the full
    /// token bytes so the UI can show them once. Cleared by
    /// `DismissCreatedToken` (or naturally when the user navigates away
    /// and the model is reloaded).
    pub just_created_token: Option<CreatedMcpToken>,
    /// Audit-log entries for the current user, newest first.
    pub mcp_audit: Vec<McpAuditEntry>,
    /// True after the first successful `LoadAudit` so the UI can
    /// distinguish "loading" from "loaded but empty".
    pub mcp_audit_loaded: bool,
    /// True while a `LoadAudit` HTTP request is outstanding.
    pub mcp_audit_loading: bool,
    /// True while the OAuth `/oauth/finalize` request is outstanding.
    pub oauth_in_flight: bool,
    /// Set transiently when `/oauth/finalize` returns; the consent view
    /// reacts by navigating the browser to this URL (which contains the
    /// auth code + state for the OAuth client).
    pub oauth_redirect_url: Option<String>,
    /// Set from the confirmed `SetSaveSucceeded { request_id }`; per-form
    /// id-matching isolates concurrent `SetSaveForm` instances (#663).
    pub last_set_save_request_id: Option<String>,
    /// Bumped by every update that concludes with `last_error` present, so
    /// shells can tell a repeated identical failure from a success (#1056).
    pub error_seq: u64,
    /// What the last `ReadPhoto` produced. Transient: the confirm surface reads
    /// it, the user edits it, and `DiscardPhotoDraft` clears it. Never written
    /// to an item without that confirmation (spec non-goal "no silent write").
    pub photo_recognition: PhotoRecognition,
}

/// Model-side recognition state. The view projection is
/// [`PhotoRecognitionView`].
#[derive(Debug, Default, Clone, PartialEq)]
pub enum PhotoRecognition {
    #[default]
    Idle,
    Reading {
        photo_id: String,
    },
    Ready {
        photo_id: String,
        draft: PhotoDraft,
    },
    /// The device has no recognition. Not an error: the photo is still saved
    /// and the user types the fields.
    Unsupported {
        photo_id: String,
    },
    Failed {
        photo_id: String,
    },
}

impl Model {
    /// Surface an error from a background HTTP failure. Respects the
    /// dismiss-mute state set by [`Model::dismiss_error`]: if the user has
    /// already dismissed the banner and the system has not yet recovered,
    /// the error is silently swallowed to stop the banner re-popping. Also
    /// dedupes identical messages to avoid render storms during burst
    /// failures (#346).
    pub fn surface_error(&mut self, msg: impl Into<String>) {
        if self.error_muted {
            return;
        }
        let msg = msg.into();
        if self.last_error.as_deref() == Some(msg.as_str()) {
            return;
        }
        self.last_error = Some(msg);
    }

    /// Mark a confirmed API success. Clears any active error and exits the
    /// dismiss-mute state — the system has demonstrably recovered, so
    /// future failures are worth showing again. Call from any handler that
    /// receives a successful API response.
    pub fn record_success(&mut self) {
        self.last_error = None;
        self.error_muted = false;
    }

    /// User explicitly dismissed the error banner. Clears the active error
    /// and enters the mute state so subsequent background failures don't
    /// immediately re-pop the banner.
    pub fn dismiss_error(&mut self) {
        self.last_error = None;
        self.error_muted = true;
    }

    /// Reset all user-scoped state on sign-out so a subsequent sign-in
    /// (potentially as a different user on the same browser) starts from a
    /// clean slate. Preserves `api_base_url` (set once at app startup; not
    /// per-user). Without this, the next user briefly sees the previous
    /// user's data — most concerning for MCP tokens / audit which are a
    /// soft information disclosure until the first refetch overwrites them
    /// (#645).
    pub fn reset_for_sign_out(&mut self) {
        let api_base_url = std::mem::take(&mut self.api_base_url);
        *self = Self {
            api_base_url,
            // Device state, not user state: the next user is in the same place.
            utc_offset_minutes: self.utc_offset_minutes,
            profile: std::mem::take(&mut self.profile),
            ..Self::default()
        };
    }
}

#[cfg(test)]
impl Model {
    /// Create a test model with a valid API base URL.
    ///
    /// crux_http requires absolute URLs, so tests must use this instead of
    /// `Model::default()` when the handler under test produces HTTP effects.
    pub fn test_default() -> Self {
        Self {
            api_base_url: "http://localhost:3001".to_string(),
            ..Default::default()
        }
    }
}

/// View-layer representation of session lifecycle state.
///
/// Mirrors the internal `SessionStatus` enum but is serializable and
/// exposed to shells via the `ViewModel`. Using an enum instead of a
/// String gives compile-time safety in both Rust and generated Swift code.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum SessionStatusView {
    #[default]
    Idle,
    Building,
    Active,
    Summary,
}

/// Where on the create form the failure the banner names actually is (#1595).
/// Set only by the handler that reported the error, and only where the form has
/// somewhere to point; every other path leaves it `None`, which reads as the
/// banner alone.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum FormErrorTarget {
    Piece {
        field: FormErrorField,
    },
    /// The chord chart as a whole, which is what a chart holding no bars at all
    /// produces: there is nothing inside it to point at.
    Chart,
    /// One bar of the chord chart, numbered from 1, and the token the parser
    /// stumbled on.
    ChartBar {
        bar_number: usize,
        token: String,
    },
    Profile {
        field: ProfileField,
    },
    /// A staged exercise by position, from 0, in the exercises the event
    /// carried. `field` is `None` for a chosen exercise, which has no field of
    /// its own. The shell reorders that list without telling the core, so the
    /// position holds only until it does (spec decision 12).
    Exercise {
        index: usize,
        field: Option<FormErrorField>,
    },
}

/// A field the add form shows. A validation failure on anything else maps to no
/// target rather than a field nobody can reach. Named apart from the shell's own
/// `FormField` view, which it would otherwise shadow inside the app module.
#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum FormErrorField {
    Title,
    Composer,
    Tempo,
    Notes,
    Tags,
}

/// Serializable view state sent to shells for rendering.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ViewModel {
    pub items: Vec<LibraryItemView>,
    /// `items`, unfiltered by `active_query` — for pickers that curate their
    /// own subset rather than mirroring the Library screen's filter (#1484).
    pub all_items: Vec<LibraryItemView>,
    /// Up to 5 items with practice history, most recently practised first,
    /// for the builder's "Recently practised" quick-add section (#1362).
    pub recently_practised: Vec<LibraryItemView>,
    /// Active filter, mirrored so the shell's pill reads one source of truth (#792).
    pub active_query: Option<ListQuery>,
    /// Active sort, mirrored so the shell's menu reads one source of truth.
    pub active_sort: LibrarySort,
    /// Counts of the visible (filtered) set so the subtitle describes what's
    /// actually on screen and reacts to the filter + search.
    pub visible_pieces: usize,
    pub visible_exercises: usize,
    /// Distinct tags across the whole library (case-folded dedupe, sorted) —
    /// the vocabulary for the filter sheet and the add/edit autocomplete.
    pub available_tags: Vec<String>,
    /// Distinct composers (sorted) for the add/edit autocomplete. Computed
    /// pre-filter so it stays the full vocabulary when the list is narrowed.
    pub available_composers: Vec<String>,
    pub sessions: Vec<PracticeSessionView>,
    pub active_session: Option<ActiveSessionView>,
    pub building_setlist: Option<BuildingSetlistView>,
    pub summary: Option<SummaryView>,
    pub session_status: SessionStatusView,
    pub error: Option<String>,
    /// See [`Model::last_error_target`].
    pub error_target: Option<FormErrorTarget>,
    /// See `Model::error_seq` — compare around a send instead of the message.
    pub error_seq: u64,
    pub analytics: Option<AnalyticsView>,
    pub last_practised: Option<LastPractisedView>,
    pub sets: Vec<SetView>,
    pub account_preferences: Option<AccountPreferences>,
    pub profile: ProfileView,
    pub delete_in_flight: bool,
    pub account_deleted: bool,
    pub mcp_tokens: Vec<McpToken>,
    pub mcp_tokens_loaded: bool,
    pub mcp_tokens_loading: bool,
    pub just_created_token: Option<CreatedMcpToken>,
    pub mcp_audit: Vec<McpAuditEntry>,
    pub mcp_audit_loaded: bool,
    pub mcp_audit_loading: bool,
    pub oauth_in_flight: bool,
    pub oauth_redirect_url: Option<String>,
    pub last_set_save_request_id: Option<String>,
    /// The one suggested session on the Practice tab (#1082). `None` whenever
    /// nothing qualifies: it suggests, it never gates.
    pub up_next: Option<SuggestedSession>,
    /// Anything starred? The Practice tab's "Practise your priorities" button
    /// shows only when this is true, and like `up_next` it is derived pre-filter (#981).
    pub has_priorities: bool,
    /// What the last photographed page was read into, for the confirm surface.
    pub photo_recognition: PhotoRecognitionView,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct PhotoRecognitionView {
    pub status: PhotoRecognitionStatus,
    /// The photo being read, so the shell can show it beside the fields.
    pub photo_id: Option<String>,
    /// Present only under `Ready`. Each field carries its own `weak`, which is
    /// what the form marks; there is deliberately no whole-draft flag beside
    /// it, since nothing would read one.
    pub draft: Option<PhotoDraft>,
}

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum PhotoRecognitionStatus {
    #[default]
    Idle,
    Reading,
    Ready,
    Unsupported,
    Failed,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct SetView {
    pub id: String,
    pub name: String,
    pub entry_count: usize,
    pub entries: Vec<SetEntryView>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct SetEntryView {
    pub id: String,
    pub item_id: String,
    pub item_title: String,
    pub item_type: ItemKind,
    pub position: usize,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct LinkedExerciseView {
    pub id: String,
    pub title: String,
    pub key: Option<String>,
    pub tempo: Option<String>,
    pub practice: Option<ItemPracticeSummary>,
    /// This exercise's latest score *on the piece it's linked from* (#1087 B2),
    /// derived from the shared session block — distinct from `practice`, which
    /// is the exercise's flat score across every context. `None` when the pair
    /// has never been practised together (or scored) in a session.
    #[serde(default)]
    pub piece_context_score: Option<u8>,
}

/// The derived scaffold curriculum for a charted piece — the read-only preview
/// (Phase A). Recomputed from the stored chart in `build_view`; the shell renders
/// it and never derives.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ScaffoldPreviewView {
    /// The key the exercises are derived in (the piece's key).
    pub key: String,
    pub specs: Vec<ScaffoldSpecView>,
    /// How many specs hit the arpeggio fallback (out-of-vocab chord).
    pub fallback_total: u8,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ScaffoldSpecView {
    /// Row identity: the shell sends the ticked `kind`s back on commit and the
    /// core re-derives, so spec content never crosses the wire (#1106).
    pub kind: ScaffoldKind,
    pub title: String,
    pub rationale: String,
    pub key: String,
    /// This spec fell back to the chord's arpeggio for at least one change.
    pub fallback: bool,
    /// A matching exercise is already linked to the piece (dedup surface).
    pub already_linked: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct PieceRefView {
    pub id: String,
    pub title: String,
    /// Composer, when the piece has one — disambiguates identically titled
    /// pieces in provenance UI (#1049).
    pub subtitle: Option<String>,
}

/// One piece an exercise is used in, or the "On its own" bucket. A row comes
/// from the piece's `linked_exercise_ids` (an intention), from practising the
/// two together (history, resolved per session from `group_id` — #1087 B1), or
/// from both; `linked` says which (#1363).
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ExerciseUsageView {
    /// `None` is the "On its own" bucket: practice with no piece in the block.
    pub piece: Option<PieceRefView>,
    /// Always `false` for "On its own".
    pub linked: bool,
    pub latest_score: Option<u8>,
    /// Distinct sessions the exercise was practised in, in this context.
    pub session_count: usize,
    /// Most recent session date for this context (RFC3339, sorts as a string).
    pub last_practiced_at: Option<String>,
    /// `true` when this row's `piece` no longer exists in the library — the
    /// piece was deleted since it was practised (#1093, decision 2a). The row
    /// is kept (its sessions are real history), but `piece.title` is the
    /// snapshot title and the shell renders the row muted + non-tappable. Always
    /// `false` for the "On its own" bucket.
    #[serde(default)]
    pub piece_removed: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct LibraryItemView {
    pub id: String,
    pub item_type: ItemKind,
    pub title: String,
    pub subtitle: String,
    pub key: Option<String>,
    pub modality: Option<Modality>,
    pub tempo: Option<String>,
    pub tempo_marking: Option<String>,
    pub tempo_bpm: Option<u16>,
    pub notes: Option<String>,
    pub tags: Vec<String>,
    pub created_at: String,
    pub updated_at: String,
    pub practice: Option<ItemPracticeSummary>,
    pub latest_achieved_tempo: Option<u16>,
    pub priority: bool,
    pub linked_exercises: Vec<LinkedExerciseView>,
    /// For exercises: every piece this exercise is used in, plus the "On its
    /// own" bucket — links and practice history merged (#1363). Empty for
    /// pieces.
    #[serde(default)]
    pub used_in: Vec<ExerciseUsageView>,
    /// For a charted piece: the derived scaffold curriculum (read-only preview).
    /// `None` for exercises and un-charted pieces.
    #[serde(default)]
    pub scaffold_preview: Option<ScaffoldPreviewView>,
    /// The parsed chord chart, for pieces that have one — the shell renders the
    /// bar grid from `symbol.raw` and pre-fills the editor from it.
    #[serde(default)]
    pub chord_chart: Option<ChordChart>,
    /// The piece's time signature, which seeds the click's bar (#1499).
    pub metre: Option<Metre>,
    /// The exercise's step ladder with per-step practice state (#1083);
    /// empty for pieces and un-laddered exercises.
    #[serde(default)]
    pub variants: Vec<VariantView>,
    /// Every live rung of `variants` names a key, so the shell prints "keys"
    /// rather than "steps" beside the count (#1467). False for pieces and for
    /// a ladder with no rungs. No `serde(default)`: the bridge is positional
    /// bincode, where serde never reaches a default, and the attribute would
    /// read as "optional on the wire" to the next person (#846).
    pub ladder_is_keys: bool,
    #[serde(default)]
    pub photo_id: Option<String>,
}

/// One step of an exercise's ladder with its derived practice state (#1083).
/// Only live (non-tombstoned) steps reach the view, in ladder order. Users
/// see "Steps"; `variant` is the core's name and never appears on screen.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct VariantView {
    pub id: String,
    pub label: String,
    pub position: usize,
    pub latest_score: Option<u8>,
    pub score_history: Vec<ScoreHistoryEntry>,
    /// Latest score has reached `SOLID_SCORE_MIN` (8 of 10).
    pub is_solid: bool,
    /// The first step that isn't yet solid; the rung to work on. At most one
    /// per ladder; a fully solid ladder has none.
    pub is_current: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ItemPracticeSummary {
    pub session_count: usize,
    pub total_minutes: u32,
    pub latest_score: Option<u8>,
    pub score_history: Vec<ScoreHistoryEntry>,
    pub latest_tempo: Option<u16>,
    pub tempo_trend: TempoTrendView,
    /// Most recent session date for this item (max `started_at`), independent
    /// of whether a score/tempo was recorded. `None` if never practised.
    /// RFC3339 — sorts chronologically as a string.
    pub last_practiced_at: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ScoreHistoryEntry {
    pub session_date: String,
    pub score: u8,
    pub session_id: String,
}

/// One practised session's slot in a `TempoTrendView`.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct TempoTrendPoint {
    pub session_date: String,
    pub session_id: String,
    pub tempo: Option<u16>,
}

/// An item's measured tempo over time, as a plottable series. A session that
/// measured no tempo keeps its slot with `tempo: None`, so the chart breaks the
/// line there rather than drawing a zero or interpolating across it (#1420).
/// Every number present was measured, because the evidence contract keeps
/// unevidenced defaults out of `achieved_tempo` upstream (T16, #1422).
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct TempoTrendView {
    /// Oldest first, the reverse of `score_history`. One point per setlist
    /// entry, matching `session_count`: an item practised twice in one session
    /// contributes two points at the same date.
    pub points: Vec<TempoTrendPoint>,
    /// Two or more measured tempos; below that there is no direction to read.
    pub has_trend: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct PracticeSessionView {
    pub id: String,
    pub started_at: String,
    pub finished_at: String,
    pub total_duration_display: String,
    pub total_duration_summary: String,
    pub completion_status: CompletionStatus,
    pub notes: Option<String>,
    pub entries: Vec<SetlistEntryView>,
    pub session_intention: Option<String>,
    pub session_score: Option<u8>,
    pub reflection_improved: Option<String>,
    pub reflection_still_rough: Option<String>,
    pub reflection_next_target: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct SetlistEntryView {
    pub id: String,
    pub item_id: String,
    pub item_title: String,
    pub item_type: ItemKind,
    pub position: usize,
    pub duration_display: String,
    pub status: EntryStatus,
    pub notes: Option<String>,
    pub score: Option<u8>,
    pub intention: Option<String>,
    pub rep_target: Option<u8>,
    pub rep_count: Option<u8>,
    pub rep_target_reached: Option<bool>,
    pub rep_history: Option<Vec<RepEvent>>,
    pub planned_duration_secs: Option<u32>,
    pub planned_duration_display: Option<String>,
    pub achieved_tempo: Option<u16>,
    /// The block this entry belongs to in the builder; `None` = standalone.
    pub group_id: Option<String>,
    /// The ladder step this entry practised, when attributed (#1083).
    #[serde(default)]
    pub variant_id: Option<String>,
    pub click_pattern: Option<ClickState>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ActiveSessionView {
    pub current_item_title: String,
    pub current_item_type: ItemKind,
    pub current_position: usize,
    pub total_items: usize,
    pub started_at: String,
    /// Wall-clock anchor (RFC3339 UTC) for the *current item*. Resets to
    /// "now" on each item advance (Next / Skip). The shell derives the
    /// per-item elapsed timer from `Utc::now() - current_item_started_at`
    /// rather than incrementing a counter — survives WebView suspension /
    /// tab backgrounding without drift.
    pub current_item_started_at: String,
    pub entries: Vec<SetlistEntryView>,
    pub session_intention: Option<String>,
    pub current_rep_target: Option<u8>,
    pub current_rep_count: Option<u8>,
    pub current_rep_target_reached: Option<bool>,
    pub current_rep_history: Option<Vec<RepEvent>>,
    /// How many slots the counter draws before the first tap. A drawn target
    /// is not a recorded one: `current_rep_target` stays `None` until a tap.
    pub current_rep_slots: u8,
    pub current_planned_duration_secs: Option<u32>,
    pub next_item_title: Option<String>,
    /// The current entry's "Aim" note, set in the builder (`EntrySettingsSheet`).
    pub current_item_intention: Option<String>,
    /// The anchor piece's title, when the current entry is a related exercise
    /// grouped into that piece's block; `None` for a standalone entry or when
    /// the current entry *is* the anchor piece itself.
    pub current_related_piece_title: Option<String>,
    /// The current item's own declared tempo marking/bpm (from its library
    /// entry) — the practice target, distinct from `achieved_tempo` (what was
    /// actually played, logged after completion).
    pub current_item_tempo_marking: Option<String>,
    pub current_item_tempo_bpm: Option<u16>,
    /// The piece's metre, the answer the click sheet opens with (T19).
    pub current_item_metre: Option<Metre>,
}

/// Whether the builder's entries originate from, and relate to, a saved Set.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum SetSourceStatus {
    #[default]
    NoSource,
    UnmodifiedFromSource {
        set_id: String,
        set_name: String,
    },
    ModifiedFromSource {
        set_id: String,
        set_name: String,
    },
}

/// A unit in the builder queue: a block (a piece with its related exercises) or
/// a single standalone item. `group_id == None` means standalone.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct SetlistBlockView {
    pub group_id: Option<String>,
    /// The block's anchor-piece title; `None` for a standalone item.
    pub piece_title: Option<String>,
    pub related_count: usize,
    pub duration_display: String,
    pub entries: Vec<SetlistEntryView>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct BuildingSetlistView {
    pub entries: Vec<SetlistEntryView>,
    pub item_count: usize,
    /// The same entries grouped into ordered units (blocks + standalone items).
    pub blocks: Vec<SetlistBlockView>,
    pub block_count: usize,
    /// Sum of the entries' planned durations; `None` when nothing is planned
    /// so shells can fall back to counts-only copy.
    pub total_duration_display: Option<String>,
    pub total_duration_summary: Option<String>,
    pub session_intention: Option<String>,
    pub target_duration_mins: Option<u32>,
    pub source_status: SetSourceStatus,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct SummaryView {
    pub total_duration_display: String,
    pub completion_status: CompletionStatus,
    pub notes: Option<String>,
    pub entries: Vec<SetlistEntryView>,
    pub session_intention: Option<String>,
    pub session_score: Option<u8>,
    pub reflection_improved: Option<String>,
    pub reflection_still_rough: Option<String>,
    pub reflection_next_target: Option<String>,
}

// ── Test fixtures ─────────────────────────────────────────────────────
// One place per many-field view type, composed with struct update, so a new
// field costs one edit rather than one per call site (CLAUDE.md, Testing).

#[cfg(test)]
impl LibraryItemView {
    pub(crate) fn fixture(id: &str, title: &str, item_type: ItemKind) -> Self {
        Self {
            id: id.to_string(),
            item_type,
            title: title.to_string(),
            subtitle: String::new(),
            key: None,
            modality: None,
            tempo: None,
            tempo_marking: None,
            tempo_bpm: None,
            notes: None,
            tags: Vec::new(),
            created_at: String::new(),
            updated_at: String::new(),
            practice: None,
            latest_achieved_tempo: None,
            priority: false,
            linked_exercises: Vec::new(),
            used_in: Vec::new(),
            scaffold_preview: None,
            chord_chart: None,
            metre: None,
            variants: Vec::new(),
            ladder_is_keys: false,
            photo_id: None,
        }
    }
}

#[cfg(test)]
impl LinkedExerciseView {
    pub(crate) fn fixture(id: &str, title: &str) -> Self {
        Self {
            id: id.to_string(),
            title: title.to_string(),
            key: None,
            tempo: None,
            practice: None,
            piece_context_score: None,
        }
    }
}

#[cfg(test)]
impl VariantView {
    pub(crate) fn fixture(id: &str, label: &str, position: usize) -> Self {
        Self {
            id: id.to_string(),
            label: label.to_string(),
            position,
            latest_score: None,
            score_history: Vec::new(),
            is_solid: false,
            is_current: false,
        }
    }
}

#[cfg(test)]
impl ItemPracticeSummary {
    pub(crate) fn fixture() -> Self {
        Self {
            session_count: 0,
            total_minutes: 0,
            latest_score: None,
            score_history: Vec::new(),
            latest_tempo: None,
            tempo_trend: TempoTrendView::default(),
            last_practiced_at: None,
        }
    }
}

// ── View helpers ──────────────────────────────────────────────────────

pub fn entry_to_view(entry: &SetlistEntry) -> SetlistEntryView {
    SetlistEntryView {
        id: entry.id.clone(),
        item_id: entry.item_id.clone(),
        item_title: entry.item_title.clone(),
        item_type: entry.item_type.clone(),
        position: entry.position,
        duration_display: crate::domain::session::format_duration_display(entry.duration_secs),
        status: entry.status.clone(),
        notes: entry.notes.clone(),
        score: entry.score,
        intention: entry.intention.clone(),
        rep_target: entry.rep_target,
        rep_count: entry.rep_count,
        rep_target_reached: entry.rep_target_reached,
        rep_history: entry.rep_history.clone(),
        planned_duration_secs: entry.planned_duration_secs,
        planned_duration_display: entry
            .planned_duration_secs
            .map(|secs| crate::domain::session::format_planned_duration(u64::from(secs))),
        achieved_tempo: entry.achieved_tempo,
        group_id: entry.group_id.clone(),
        variant_id: entry.variant_id.clone(),
        click_pattern: entry.click_pattern.clone(),
    }
}

/// Project flat entry views into ordered units: a contiguous run sharing a
/// `group_id` becomes one block (related exercises first, piece last); every
/// ungrouped entry is its own standalone unit.
pub fn build_blocks(entries: &[SetlistEntryView]) -> Vec<SetlistBlockView> {
    let mut blocks: Vec<SetlistBlockView> = Vec::new();
    for entry in entries {
        let extends = match (&entry.group_id, blocks.last()) {
            (Some(g), Some(last)) => last.group_id.as_deref() == Some(g.as_str()),
            _ => false,
        };
        let is_piece = entry.item_type == ItemKind::Piece;
        if extends {
            let block = blocks.last_mut().expect("extends implies a last block");
            if is_piece {
                block.piece_title = Some(entry.item_title.clone());
            } else {
                block.related_count += 1;
            }
            block.entries.push(entry.clone());
        } else {
            let grouped = entry.group_id.is_some();
            blocks.push(SetlistBlockView {
                group_id: entry.group_id.clone(),
                piece_title: (grouped && is_piece).then(|| entry.item_title.clone()),
                related_count: usize::from(grouped && !is_piece),
                duration_display: String::new(),
                entries: vec![entry.clone()],
            });
        }
    }
    for block in &mut blocks {
        let total: u32 = block
            .entries
            .iter()
            .filter_map(|e| e.planned_duration_secs)
            .sum();
        block.duration_display = if total > 0 {
            crate::domain::session::format_planned_duration(u64::from(total))
        } else {
            "—".to_string()
        };
    }
    blocks
}

pub fn build_active_session_view(
    active: &ActiveSession,
    item_index: &HashMap<&str, &Item>,
) -> ActiveSessionView {
    let safe_index = active
        .current_index
        .min(active.entries.len().saturating_sub(1));
    let current = &active.entries[safe_index];

    // Breadcrumb only applies to a related exercise practiced inside a block —
    // not the anchor piece itself.
    let current_related_piece_title = (current.item_type != ItemKind::Piece)
        .then_some(current.group_id.as_deref())
        .flatten()
        .and_then(|group_id| {
            active
                .entries
                .iter()
                .find(|e| e.item_type == ItemKind::Piece && e.group_id.as_deref() == Some(group_id))
                .map(|e| e.item_title.clone())
        });

    // O(1) via the caller's id→Item index (same one build_view uses for
    // linked-exercise lookups) rather than a linear scan over the library.
    let current_item_tempo = item_index
        .get(current.item_id.as_str())
        .and_then(|i| i.tempo.as_ref());

    ActiveSessionView {
        current_item_title: current.item_title.clone(),
        current_item_type: current.item_type.clone(),
        current_position: active.current_index,
        total_items: active.entries.len(),
        started_at: active.session_started_at.to_rfc3339(),
        current_item_started_at: active.current_item_started_at.to_rfc3339(),
        entries: active.entries.iter().map(entry_to_view).collect(),
        session_intention: active.session_intention.clone(),
        current_rep_target: current.rep_target,
        current_rep_count: current.rep_count,
        current_rep_target_reached: current.rep_target_reached,
        current_rep_history: current.rep_history.clone(),
        current_rep_slots: current
            .rep_target
            .unwrap_or(crate::validation::DEFAULT_REP_TARGET),
        current_planned_duration_secs: current.planned_duration_secs,
        next_item_title: active
            .entries
            .get(safe_index + 1)
            .map(|e| e.item_title.clone()),
        current_item_intention: current.intention.clone(),
        current_related_piece_title,
        current_item_tempo_marking: current_item_tempo.and_then(|t| t.marking.clone()),
        current_item_tempo_bpm: current_item_tempo.and_then(|t| t.bpm),
        current_item_metre: item_index
            .get(current.item_id.as_str())
            .and_then(|i| i.metre.clone()),
    }
}

pub fn build_summary_view(summary: &SummarySession) -> SummaryView {
    let total_secs: u64 = summary.entries.iter().map(|e| e.duration_secs).sum();
    SummaryView {
        total_duration_display: crate::domain::session::format_duration_display(total_secs),
        completion_status: summary.completion_status.clone(),
        notes: summary.session_notes.clone(),
        entries: summary.entries.iter().map(entry_to_view).collect(),
        session_intention: summary.session_intention.clone(),
        session_score: summary.session_score,
        reflection_improved: summary.reflection_improved.clone(),
        reflection_still_rough: summary.reflection_still_rough.clone(),
        reflection_next_target: summary.reflection_next_target.clone(),
    }
}

pub fn session_to_view(session: &PracticeSession) -> PracticeSessionView {
    PracticeSessionView {
        id: session.id.clone(),
        started_at: session.started_at.to_rfc3339(),
        finished_at: session.completed_at.to_rfc3339(),
        total_duration_display: crate::domain::session::format_duration_display(
            session.total_duration_secs,
        ),
        total_duration_summary: crate::domain::session::format_duration_summary(
            session.total_duration_secs,
        ),
        completion_status: session.completion_status.clone(),
        notes: session.session_notes.clone(),
        entries: session.entries.iter().map(entry_to_view).collect(),
        session_intention: session.session_intention.clone(),
        session_score: session.session_score,
        reflection_improved: session.reflection_improved.clone(),
        reflection_still_rough: session.reflection_still_rough.clone(),
        reflection_next_target: session.reflection_next_target.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    /// `ExerciseUsageView` crosses the bincode FFI bridge inside the
    /// ViewModel; guard it against the #846 silent-drop class.
    #[test]
    fn exercise_usage_view_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(ExerciseUsageView {
            piece: Some(PieceRefView {
                id: "P".to_string(),
                title: "Sonata".to_string(),
                subtitle: Some("Beethoven".to_string()),
            }),
            linked: true,
            latest_score: Some(6),
            session_count: 2,
            last_practiced_at: Some("2026-07-01T00:00:00+00:00".to_string()),
            piece_removed: true,
        });
    }

    /// `ScaffoldPreviewView` crosses the bincode wire inside the ViewModel
    /// (`LibraryItemView.scaffold_preview`) — guard it against the #846 drop class.
    #[test]
    fn scaffold_preview_view_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(ScaffoldPreviewView {
            key: "G".to_string(),
            specs: vec![ScaffoldSpecView {
                kind: ScaffoldKind::Shells,
                title: "Shells".to_string(),
                rationale: "3rd + 7th of every chord".to_string(),
                key: "G".to_string(),
                fallback: false,
                already_linked: true,
            }],
            fallback_total: 0,
        });
    }

    /// `VariantView` crosses the bincode wire inside `LibraryItemView.variants`
    /// (#1083); guard it against the #846 drop class.
    #[test]
    fn variant_view_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(VariantView {
            id: "v-1".to_string(),
            label: "B♭".to_string(),
            position: 2,
            latest_score: Some(8),
            score_history: vec![ScoreHistoryEntry {
                session_date: "2026-07-01T00:00:00+00:00".to_string(),
                score: 8,
                session_id: "s1".to_string(),
            }],
            is_solid: true,
            is_current: false,
        });
    }

    /// `LinkedExerciseView` crosses the same bincode wire; `piece_context_score`
    /// (#1087 B2) is a trailing `Option` — guard it against the #846 drop class.
    #[test]
    fn linked_exercise_view_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(LinkedExerciseView {
            id: "E".to_string(),
            title: "Enclosures".to_string(),
            key: Some("C".to_string()),
            tempo: Some("♩ = 120".to_string()),
            practice: None,
            piece_context_score: Some(7),
        });
    }

    fn make_item(id: &str, title: &str, kind: ItemKind) -> Item {
        Item {
            id: id.to_string(),
            title: title.to_string(),
            kind,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            created_at: Utc::now(),
            updated_at: Utc::now(),
            linked_exercise_ids: vec![],
            priority: false,
            chord_chart: None,
            variants: vec![],
            photo_id: None,
            metre: None,
        }
    }

    fn make_entry(id: &str, item_id: &str, title: &str, position: usize) -> SetlistEntry {
        SetlistEntry {
            id: id.to_string(),
            item_id: item_id.to_string(),
            item_title: title.to_string(),
            item_type: ItemKind::Piece,
            position,
            duration_secs: 0,
            status: EntryStatus::NotAttempted,
            notes: None,
            score: None,
            intention: None,
            rep_target: None,
            rep_count: None,
            rep_target_reached: None,
            rep_history: None,
            planned_duration_secs: None,
            achieved_tempo: None,
            group_id: None,
            variant_id: None,
            click_pattern: None,
        }
    }

    // ── Model error methods ────────────────────────────────────────────

    #[test]
    fn surface_error_sets_last_error() {
        let mut model = Model::default();
        model.surface_error("network down");
        assert_eq!(model.last_error.as_deref(), Some("network down"));
    }

    #[test]
    fn surface_error_dedupes_identical_messages() {
        let mut model = Model::default();
        model.surface_error("fail");
        model.surface_error("fail");
        assert_eq!(model.last_error.as_deref(), Some("fail"));
    }

    #[test]
    fn surface_error_muted_after_dismiss() {
        let mut model = Model::default();
        model.surface_error("first");
        model.dismiss_error();
        model.surface_error("second");
        assert!(model.last_error.is_none());
        assert!(model.error_muted);
    }

    #[test]
    fn record_success_clears_error_and_unmutes() {
        let mut model = Model::default();
        model.surface_error("oops");
        model.dismiss_error();
        model.record_success();
        assert!(model.last_error.is_none());
        assert!(!model.error_muted);
        model.surface_error("new error");
        assert_eq!(model.last_error.as_deref(), Some("new error"));
    }

    #[test]
    fn reset_for_sign_out_preserves_api_base_url() {
        let mut model = Model {
            api_base_url: "https://api.example.com".to_string(),
            utc_offset_minutes: 60,
            ..Default::default()
        };
        model.items.push(Item {
            id: "item-1".to_string(),
            title: "leftover".to_string(),
            kind: ItemKind::Piece,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            created_at: Utc::now(),
            updated_at: Utc::now(),
            linked_exercise_ids: vec![],
            priority: false,
            chord_chart: None,
            variants: vec![],
            photo_id: None,
            metre: None,
        });
        model.last_set_save_request_id = Some("req-1".to_string());
        model.reset_for_sign_out();
        assert_eq!(model.api_base_url, "https://api.example.com");
        assert_eq!(
            model.utc_offset_minutes, 60,
            "device state survives sign-out"
        );
        assert!(model.items.is_empty());
        assert!(model.last_set_save_request_id.is_none());
    }

    // ── entry_to_view ──────────────────────────────────────────────────

    #[test]
    fn entry_to_view_formats_duration() {
        let mut entry = make_entry("e1", "i1", "Scale", 0);
        entry.duration_secs = 125;
        let view = entry_to_view(&entry);
        assert_eq!(view.duration_display, "2m 5s");
    }

    #[test]
    fn entry_to_view_planned_duration_whole_minutes() {
        let mut entry = make_entry("e1", "i1", "Scale", 0);
        entry.planned_duration_secs = Some(300);
        let view = entry_to_view(&entry);
        assert_eq!(view.planned_duration_display.as_deref(), Some("5 min"));
    }

    #[test]
    fn entry_to_view_planned_duration_partial_minutes() {
        let mut entry = make_entry("e1", "i1", "Scale", 0);
        entry.planned_duration_secs = Some(90);
        let view = entry_to_view(&entry);
        assert_eq!(view.planned_duration_display.as_deref(), Some("1m 30s"));
    }

    #[test]
    fn entry_to_view_carries_variant_id() {
        let mut entry = make_entry("e1", "i1", "Scale", 0);
        entry.variant_id = Some("variant-1".to_string());
        let view = entry_to_view(&entry);
        assert_eq!(view.variant_id.as_deref(), Some("variant-1"));
    }

    // ── build_active_session_view ──────────────────────────────────────

    /// The click sheet opens with the piece's metre (T19); a dropped projection
    /// would open every sheet at 4/4.
    #[test]
    fn active_session_view_carries_the_current_items_metre() {
        let metre = Metre {
            beats: 7,
            unit: 8,
            groups: Some(vec![3, 2, 2]),
        };
        let mut piece = make_item("i1", "Take Five", ItemKind::Piece);
        piece.metre = Some(metre.clone());
        let plain = make_item("i2", "Etude", ItemKind::Exercise);
        let items: HashMap<&str, &Item> = [("i1", &piece), ("i2", &plain)].into_iter().collect();
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![
                make_entry("e1", "i1", "Take Five", 0),
                make_entry("e2", "i2", "Etude", 1),
            ],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        assert_eq!(
            build_active_session_view(&active, &items).current_item_metre,
            Some(metre)
        );
        let second = ActiveSession {
            current_index: 1,
            ..active
        };
        assert_eq!(
            build_active_session_view(&second, &items).current_item_metre,
            None
        );
    }

    /// The resident counter draws against `current_rep_slots`, so a builder
    /// target of 7 must not render as ten slots.
    #[test]
    fn active_session_view_draws_the_builder_target_or_the_default() {
        let mut targeted = make_entry("e1", "i1", "Scale", 0);
        targeted.rep_target = Some(7);
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![targeted, make_entry("e2", "i2", "Etude", 1)],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        assert_eq!(
            build_active_session_view(&active, &HashMap::new()).current_rep_slots,
            7
        );

        let untouched = ActiveSession {
            current_index: 1,
            ..active
        };
        let view = build_active_session_view(&untouched, &HashMap::new());
        assert_eq!(view.current_rep_target, None);
        assert_eq!(
            view.current_rep_slots,
            crate::validation::DEFAULT_REP_TARGET
        );
    }

    #[test]
    fn active_session_view_next_item_title() {
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![
                make_entry("e1", "i1", "Scale", 0),
                make_entry("e2", "i2", "Etude", 1),
            ],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let view = build_active_session_view(&active, &HashMap::new());
        assert_eq!(view.next_item_title.as_deref(), Some("Etude"));
    }

    #[test]
    fn active_session_view_last_item_has_no_next() {
        let active = ActiveSession {
            id: "as2".to_string(),
            entries: vec![
                make_entry("e1", "i1", "Scale", 0),
                make_entry("e2", "i2", "Etude", 1),
            ],
            current_index: 1,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let view = build_active_session_view(&active, &HashMap::new());
        assert!(view.next_item_title.is_none());
    }

    #[test]
    fn active_session_view_promotes_current_item_intention() {
        let mut entry = make_entry("e1", "i1", "Scale", 0);
        entry.intention = Some("evenness".to_string());
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![entry],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let view = build_active_session_view(&active, &HashMap::new());
        assert_eq!(view.current_item_intention.as_deref(), Some("evenness"));
    }

    #[test]
    fn active_session_view_related_piece_title_for_grouped_exercise() {
        let mut exercise = make_entry("e1", "i1", "Scale", 0);
        exercise.item_type = ItemKind::Exercise;
        exercise.group_id = Some("g1".to_string());
        let mut piece = make_entry("e2", "i2", "Clair de Lune", 1);
        piece.item_type = ItemKind::Piece;
        piece.group_id = Some("g1".to_string());
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![exercise, piece],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let view = build_active_session_view(&active, &HashMap::new());
        assert_eq!(
            view.current_related_piece_title.as_deref(),
            Some("Clair de Lune")
        );
    }

    #[test]
    fn active_session_view_no_related_piece_title_for_standalone_entry() {
        // Explicitly Exercise + no group_id: distinct from the anchor-piece
        // test below, which covers item_type == Piece separately. make_entry's
        // default item_type is Piece, so this must override it to actually
        // exercise the "ungrouped exercise" branch rather than short-circuiting
        // on the item_type check alone.
        let mut entry = make_entry("e1", "i1", "Scale", 0);
        entry.item_type = ItemKind::Exercise;
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![entry],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let view = build_active_session_view(&active, &HashMap::new());
        assert!(view.current_related_piece_title.is_none());
    }

    #[test]
    fn active_session_view_no_related_piece_title_when_current_is_the_anchor_piece() {
        let mut piece = make_entry("e1", "i1", "Clair de Lune", 0);
        piece.item_type = ItemKind::Piece;
        piece.group_id = Some("g1".to_string());
        let mut exercise = make_entry("e2", "i2", "Scale", 1);
        exercise.item_type = ItemKind::Exercise;
        exercise.group_id = Some("g1".to_string());
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![piece, exercise],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let view = build_active_session_view(&active, &HashMap::new());
        assert!(
            view.current_related_piece_title.is_none(),
            "breadcrumb is for exercises related to a piece, not the piece itself"
        );
    }

    #[test]
    fn active_session_view_current_item_tempo_from_item_library() {
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![make_entry("e1", "i1", "Scale", 0)],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let item = Item {
            id: "i1".to_string(),
            title: "Scale".to_string(),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: Some(crate::domain::types::Tempo {
                marking: Some("Allegro".to_string()),
                bpm: Some(132),
            }),
            notes: None,
            tags: vec![],
            created_at: Utc::now(),
            updated_at: Utc::now(),
            linked_exercise_ids: vec![],
            priority: false,
            chord_chart: None,
            variants: vec![],
            photo_id: None,
            metre: None,
        };
        let item_index: HashMap<&str, &Item> = HashMap::from([("i1", &item)]);
        let view = build_active_session_view(&active, &item_index);
        assert_eq!(view.current_item_tempo_marking.as_deref(), Some("Allegro"));
        assert_eq!(view.current_item_tempo_bpm, Some(132));
    }

    #[test]
    fn active_session_view_current_item_tempo_none_when_item_missing() {
        let active = ActiveSession {
            id: "as1".to_string(),
            entries: vec![make_entry("e1", "i1", "Scale", 0)],
            current_index: 0,
            session_started_at: Utc::now(),
            current_item_started_at: Utc::now(),
            session_intention: None,
        };
        let view = build_active_session_view(&active, &HashMap::new());
        assert!(view.current_item_tempo_marking.is_none());
        assert!(view.current_item_tempo_bpm.is_none());
    }

    // ── build_summary_view ─────────────────────────────────────────────

    #[test]
    fn summary_view_total_duration() {
        let mut e1 = make_entry("e1", "i1", "Scale", 0);
        e1.duration_secs = 60;
        let mut e2 = make_entry("e2", "i2", "Etude", 1);
        e2.duration_secs = 90;
        let summary = crate::domain::session::SummarySession {
            id: "sum1".to_string(),
            entries: vec![e1, e2],
            session_started_at: Utc::now(),
            session_ended_at: Utc::now(),
            completion_status: CompletionStatus::Completed,
            session_notes: None,
            session_intention: Some("focus".to_string()),
            session_score: None,
            reflection_improved: None,
            reflection_still_rough: None,
            reflection_next_target: None,
        };
        let view = build_summary_view(&summary);
        assert_eq!(view.total_duration_display, "2m 30s");
        assert_eq!(view.session_intention.as_deref(), Some("focus"));
    }

    #[test]
    fn session_view_exposes_coarse_duration_summary() {
        let mut entry = make_entry("e1", "i1", "Scale", 0);
        entry.duration_secs = 2700;
        let session = crate::domain::session::PracticeSession {
            id: "s1".to_string(),
            entries: vec![entry],
            session_notes: None,
            session_intention: None,
            started_at: Utc::now(),
            completed_at: Utc::now(),
            total_duration_secs: 2700,
            completion_status: CompletionStatus::Completed,
            session_score: None,
            reflection_improved: None,
            reflection_still_rough: None,
            reflection_next_target: None,
        };
        let view = session_to_view(&session);
        // Precise (live-timer) form keeps seconds; the summary line drops them.
        assert_eq!(view.total_duration_display, "45m 0s");
        assert_eq!(view.total_duration_summary, "45m");
    }

    #[test]
    fn summary_view_exposes_session_score() {
        let summary = crate::domain::session::SummarySession {
            id: "sum2".to_string(),
            entries: vec![],
            session_started_at: Utc::now(),
            session_ended_at: Utc::now(),
            completion_status: CompletionStatus::Completed,
            session_notes: None,
            session_intention: None,
            session_score: Some(7),
            reflection_improved: None,
            reflection_still_rough: None,
            reflection_next_target: None,
        };
        let view = build_summary_view(&summary);
        assert_eq!(view.session_score, Some(7));
    }

    #[test]
    fn session_to_view_exposes_session_score() {
        let session = crate::domain::session::PracticeSession {
            id: "s2".to_string(),
            entries: vec![],
            session_notes: None,
            session_intention: None,
            started_at: Utc::now(),
            completed_at: Utc::now(),
            total_duration_secs: 60,
            completion_status: CompletionStatus::Completed,
            session_score: Some(5),
            reflection_improved: None,
            reflection_still_rough: None,
            reflection_next_target: None,
        };
        let view = session_to_view(&session);
        assert_eq!(view.session_score, Some(5));
    }

    #[test]
    fn session_to_view_exposes_reflections() {
        let session = crate::domain::session::PracticeSession {
            id: "s3".to_string(),
            entries: vec![],
            session_notes: None,
            session_intention: None,
            started_at: Utc::now(),
            completed_at: Utc::now(),
            total_duration_secs: 60,
            completion_status: CompletionStatus::Completed,
            session_score: None,
            reflection_improved: Some("bars 1-8 clean".to_string()),
            reflection_still_rough: Some("bridge rushes".to_string()),
            reflection_next_target: Some("bridge at 80".to_string()),
        };
        let view = session_to_view(&session);
        assert_eq!(view.reflection_improved, Some("bars 1-8 clean".to_string()));
        assert_eq!(
            view.reflection_still_rough,
            Some("bridge rushes".to_string())
        );
        assert_eq!(
            view.reflection_next_target,
            Some("bridge at 80".to_string())
        );
    }

    #[test]
    fn summary_view_exposes_reflections() {
        let summary = crate::domain::session::SummarySession {
            id: "s4".to_string(),
            entries: vec![],
            session_started_at: Utc::now(),
            session_ended_at: Utc::now(),
            session_notes: None,
            session_intention: Some("even RH at 96".to_string()),
            completion_status: CompletionStatus::Completed,
            session_score: None,
            reflection_improved: None,
            reflection_still_rough: Some("bridge rushes".to_string()),
            reflection_next_target: None,
        };
        let view = build_summary_view(&summary);
        assert_eq!(view.reflection_improved, None);
        assert_eq!(
            view.reflection_still_rough,
            Some("bridge rushes".to_string())
        );
        assert_eq!(view.reflection_next_target, None);
    }

    // ── Integration: Event → model → ViewModel ────────────────────────

    fn update_model(model: &mut Model, event: crate::app::Event) {
        use crux_core::App;
        let app = crate::app::Intrada;
        let _cmd = app.update(event, model);
    }

    fn model_with_summary_state() -> Model {
        use crate::app::Event;
        use crate::domain::session::SessionEvent;

        let now = Utc::now();
        let mut model = Model {
            items: vec![Item {
                id: "piece-1".to_string(),
                title: "Test Piece".to_string(),
                kind: ItemKind::Piece,
                composer: None,
                key: None,
                modality: None,
                tempo: None,
                notes: None,
                tags: vec![],
                created_at: now,
                updated_at: now,
                linked_exercise_ids: vec![],
                priority: false,
                chord_chart: None,
                variants: vec![],
                photo_id: None,
                metre: None,
            }],
            api_base_url: "http://localhost:3001".to_string(),
            ..Default::default()
        };

        update_model(&mut model, Event::Session(SessionEvent::StartBuilding));
        update_model(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );
        update_model(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        let t1 = now + chrono::Duration::seconds(60);
        update_model(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t1 }),
        );
        model
    }

    #[test]
    fn update_session_score_flows_to_summary_view() {
        use crate::app::Event;
        use crate::domain::session::SessionEvent;
        use crux_core::App;

        let mut model = model_with_summary_state();

        update_model(
            &mut model,
            Event::Session(SessionEvent::UpdateSessionScore { score: Some(7) }),
        );

        let app = crate::app::Intrada;
        let vm = app.view(&model);
        let summary = vm.summary.expect("model should be in Summary state");
        assert_eq!(summary.session_score, Some(7));
    }
}
