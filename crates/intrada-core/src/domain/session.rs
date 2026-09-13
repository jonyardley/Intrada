use crate::app::{AppEffect, Effect, Event};
use crate::domain::item::Item;
use crate::domain::item::ItemKind;
use crate::domain::metre::Metre;
use crate::error::LibraryError;
use crate::model::Model;
use crate::validation;
use chrono::{DateTime, Utc};
use crux_core::Command;
use serde::{Deserialize, Serialize};

// ── Enums ──────────────────────────────────────────────────────────────

/// Completion status of a single setlist entry.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum EntryStatus {
    /// Item was practised and time was recorded.
    Completed,
    /// Item was explicitly skipped (duration_secs = 0).
    Skipped,
    /// Session ended early before reaching this item (duration_secs = 0).
    NotAttempted,
}

/// Whether the session ran to completion or was ended early.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum CompletionStatus {
    /// All items in the setlist were addressed (completed or skipped).
    Completed,
    /// Session was ended before all items were reached.
    EndedEarly,
}

/// A single action in the rep history sequence.
///
#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum RepAction {
    /// Failed rep — count decremented.
    Missed,
    /// Successful rep — count incremented.
    Success,
}

/// One tap on the pass counter and when it landed. Sequence alone cannot tell
/// a steady ten from a hard-won one (#1367).
#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct RepEvent {
    pub action: RepAction,
    pub at: DateTime<Utc>,
}

// ── Domain Types ───────────────────────────────────────────────────────

/// One stretch of an item spent on one variation (#1739): what was played,
/// as against `SetlistEntry::planned_variation_id`, which is what was planned.
/// Switching mid item closes the open play and opens another, so an entry
/// practised in C and then D holds two.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct VariationPlay {
    pub id: String,
    /// A live variant of the entry's item; `None` means unattributed, which is
    /// what a piece, and an exercise with no variations, always records.
    pub variation_id: Option<String>,
    pub started_at: DateTime<Utc>,
    pub seconds: u64,
    pub rep_target: Option<u8>,
    pub rep_count: Option<u8>,
    pub rep_target_reached: Option<bool>,
    pub rep_history: Option<Vec<RepEvent>>,
    pub achieved_tempo: Option<u16>,
    pub click_pattern: Option<ClickState>,
    pub score: Option<u8>,
}

impl VariationPlay {
    pub fn opened(
        variation_id: Option<String>,
        rep_target: Option<u8>,
        started_at: DateTime<Utc>,
    ) -> Self {
        Self {
            id: ulid::Ulid::generate().to_string(),
            variation_id,
            started_at,
            seconds: 0,
            rep_target,
            rep_count: None,
            rep_target_reached: None,
            rep_history: None,
            achieved_tempo: None,
            click_pattern: None,
            score: None,
        }
    }

    /// A mark or a banked repetition. Time alone is not a record: the clock
    /// runs whether or not the musician played anything.
    pub fn recorded_something(&self) -> bool {
        self.score.is_some() || self.rep_count.unwrap_or(0) > 0
    }

    /// A play nobody practised: no mark, no repetitions and under five seconds.
    /// A terminal transition drops these so a stray tap on the picker leaves no
    /// trace. The time bound is what separates a stray tap from a stretch that
    /// was genuinely played and simply not marked.
    pub fn is_incidental(&self) -> bool {
        !self.recorded_something() && self.seconds < validation::MIN_PLAY_SECONDS
    }
}

/// An individual item within a session's setlist.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct SetlistEntry {
    pub id: String,
    pub item_id: String,
    pub item_title: String,
    pub item_type: ItemKind,
    pub position: usize,
    pub duration_secs: u64,
    pub status: EntryStatus,
    pub notes: Option<String>,
    pub intention: Option<String>,
    pub planned_duration_secs: Option<u32>,
    /// Block grouping (building phase): entries pulled in alongside a piece via
    /// its related exercises share one `group_id`. A block is the contiguous run
    /// of entries with the same id; `None` = standalone.
    pub group_id: Option<String>,
    /// The variation the builder planned to practise; the plan, not the record
    /// (#1739 decision 5). `None` = no plan. Dropped server-side until the sync
    /// engine, like `group_id` (invariant 6 scoped).
    pub planned_variation_id: Option<String>,
    /// The repetition target set in the builder, a plan on the same footing as
    /// `planned_variation_id`. Every play the entry opens starts from it, so a
    /// switch redraws the same number of slots for the new variation.
    pub planned_rep_target: Option<u8>,
    /// What was actually practised, in order. Empty for an entry never
    /// attempted; every practised entry has at least one, a piece included
    /// (#1739 decision 3).
    pub plays: Vec<VariationPlay>,
}

impl SetlistEntry {
    pub fn open_play(&self) -> Option<&VariationPlay> {
        self.plays.last()
    }

    pub fn open_play_mut(&mut self) -> Option<&mut VariationPlay> {
        self.plays.last_mut()
    }

    /// The one place several marks collapse into one (#1739 decision 9): the
    /// mean of the plays that carry a score, rounded to nearest. Per-variation
    /// history reads the plays and never this.
    pub fn score_summary(&self) -> Option<u8> {
        let scored: Vec<u16> = self
            .plays
            .iter()
            .filter_map(|p| p.score)
            .map(u16::from)
            .collect();
        if scored.is_empty() {
            return None;
        }
        let total: u16 = scored.iter().sum();
        let count = scored.len() as u16;
        Some(((total * 2 + count) / (count * 2)) as u8)
    }
}

#[cfg(test)]
impl VariationPlay {
    pub(crate) fn fixture() -> Self {
        Self {
            id: "play-1".to_string(),
            variation_id: None,
            started_at: DateTime::<Utc>::from_timestamp(0, 0).expect("epoch"),
            seconds: 60,
            rep_target: None,
            rep_count: None,
            rep_target_reached: None,
            rep_history: None,
            achieved_tempo: None,
            click_pattern: None,
            score: None,
        }
    }
}

#[cfg(test)]
impl SetlistEntry {
    pub(crate) fn fixture() -> Self {
        Self {
            id: "entry-1".to_string(),
            item_id: "item-1".to_string(),
            item_title: "Item".to_string(),
            item_type: ItemKind::Piece,
            position: 0,
            duration_secs: 0,
            status: EntryStatus::NotAttempted,
            notes: None,
            intention: None,
            planned_duration_secs: None,
            group_id: None,
            planned_variation_id: None,
            planned_rep_target: None,
            plays: Vec::new(),
        }
    }
}

/// A completed practice session (persisted to localStorage).
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct PracticeSession {
    pub id: String,
    pub entries: Vec<SetlistEntry>,
    pub session_notes: Option<String>,
    pub started_at: DateTime<Utc>,
    pub completed_at: DateTime<Utc>,
    pub total_duration_secs: u64,
    pub completion_status: CompletionStatus,
    #[serde(default)]
    pub session_score: Option<u8>,
}

/// What the shell saw about where an end-of-item tempo came from. Facts only:
/// whether they amount to evidence is the core's ruling (#1420, roadmap Q3).
#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct TempoObservation {
    /// The user set the number themselves rather than accepting the pre-fill.
    pub user_set: bool,
    /// The click was sounding when the item ended, so the pre-filled number
    /// measures what they actually played to.
    pub click_sounding: bool,
}

impl TempoObservation {
    /// A tempo is worth recording when there is evidence behind it, and never
    /// otherwise (design-principles T16, #1420).
    pub fn is_evidenced(&self) -> bool {
        self.user_set || self.click_sounding
    }
}

/// What the click was set to when the item ended. Facts only, like
/// `TempoObservation`: the core decides what they mean. The pattern never
/// divides the tempo; the pulse keeps its rate and `sounding` gates the beats.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ClickState {
    pub metre: Metre,
    /// Bitmask over `metre.beats`, LSB = beat 1. Fixed width and cheap to mask.
    pub sounding: u16,
}

// ── Transient State Types ──────────────────────────────────────────────

/// State during setlist assembly (Building phase).
#[derive(Debug, Clone, Default)]
pub struct BuildingSession {
    pub entries: Vec<SetlistEntry>,
}

/// State during active practice (Active phase).
/// Persisted under `Store.sessionInProgressKey` for crash recovery.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ActiveSession {
    pub id: String,
    pub entries: Vec<SetlistEntry>,
    pub current_index: usize,
    pub current_item_started_at: DateTime<Utc>,
    pub session_started_at: DateTime<Utc>,
}

/// State during post-session review (Summary phase).
#[derive(Debug, Clone)]
pub struct SummarySession {
    pub id: String,
    pub entries: Vec<SetlistEntry>,
    pub session_started_at: DateTime<Utc>,
    pub session_ended_at: DateTime<Utc>,
    pub session_notes: Option<String>,
    pub completion_status: CompletionStatus,
    pub session_score: Option<u8>,
}

/// The lifecycle state of a session in the core Model.
#[derive(Debug, Clone, Default)]
pub enum SessionStatus {
    #[default]
    Idle,
    Building(BuildingSession),
    Active(ActiveSession),
    Summary(SummarySession),
}

// ── Events ─────────────────────────────────────────────────────────────

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum SessionEvent {
    // === Building Phase ===
    StartBuilding,
    SetEntryIntention {
        entry_id: String,
        intention: Option<String>,
    },
    /// Plan which variation an entry will be practised on; `None` clears
    /// (#1083, narrowed by #1739 decision 5). Building phase only: once
    /// practice starts the record is the plays, and `SwitchVariation` is what
    /// changes it. The variation must be a live variant of the entry's item.
    /// Local-first only until sync.
    SetEntryVariant {
        entry_id: String,
        variant_id: Option<String>,
    },
    /// Set or clear the rep target for an entry during building phase.
    /// `None` disables the counter; `Some(n)` enables it with target `n`.
    SetRepTarget {
        entry_id: String,
        target: Option<u8>,
    },
    /// Set or clear the planned duration for an entry during building phase.
    /// `None` clears the planned duration; `Some(secs)` sets it (range: 60–3600).
    SetEntryDuration {
        entry_id: String,
        duration_secs: Option<u32>,
    },
    AddToSetlist {
        item_id: String,
    },
    /// One-tap "Practise this": from Idle, start building seeded with the
    /// item (a piece brings its related exercises, as `AddToSetlist`).
    StartBuildingWith {
        item_id: String,
    },
    /// The Up next card's CTA: from Idle, start building seeded with the
    /// suggested block (#1082). Carries only `now`, because the core
    /// re-derives the suggestion rather than trusting the shell's copy of it,
    /// and the derivation is clock-dependent.
    StartBuildingFromSuggestion {
        now: DateTime<Utc>,
    },
    /// The Practice tab's "Practise your priorities" (#981): from Idle, start
    /// building seeded with every starred item, least ready first. Carries only
    /// `now`, for the same reason `StartBuildingFromSuggestion` does: the core
    /// re-derives the set rather than trusting the shell's copy, and the
    /// ordering is clock-dependent.
    StartBuildingWithPriorities {
        now: DateTime<Utc>,
    },
    RemoveFromSetlist {
        entry_id: String,
    },
    ReorderSetlist {
        entry_id: String,
        new_position: usize,
    },
    /// Move a whole block to a new unit-position (blocks + standalone items,
    /// in order). Keeps the block contiguous.
    ReorderBlock {
        group_id: String,
        new_position: usize,
    },
    /// Drop a block's related exercises, keeping the piece (becomes standalone).
    KeepOnlyPiece {
        group_id: String,
    },
    /// Dissolve a block — its entries stay in place but become standalone.
    UngroupBlock {
        group_id: String,
    },
    /// Dissolve every block.
    UngroupAllBlocks,
    /// Remove a whole block (piece + its related exercises).
    RemoveBlock {
        group_id: String,
    },
    /// Add one more exercise into an already-present block, positioned before
    /// the block's anchor piece. Membership is binary, same idempotency as
    /// `AddToSetlist` (#939): re-adding a present item is a no-op.
    AddExerciseToBlock {
        group_id: String,
        item_id: String,
    },
    StartSession {
        now: DateTime<Utc>,
    },
    CancelBuilding,

    // === Active Phase ===
    NextItem {
        now: DateTime<Utc>,
    },
    SkipItem {
        now: DateTime<Utc>,
    },
    FinishSession {
        now: DateTime<Utc>,
    },
    EndSessionEarly {
        now: DateTime<Utc>,
    },
    /// Bank a pass on the current entry (capped at target). The first tap on
    /// an untouched entry writes the target too; see `record_rep`.
    RepGotIt {
        now: DateTime<Utc>,
    },
    /// Step back a pass on the current entry (floor 0).
    RepMissed {
        now: DateTime<Utc>,
    },
    /// Close the open play and open another on `variation_id` (#1739 decision
    /// 6). Switching to the variation already open writes nothing, so a stray
    /// tap cannot reset the repetition counter. Active phase only.
    SwitchVariation {
        entry_id: String,
        variation_id: Option<String>,
        now: DateTime<Utc>,
    },

    // === Summary Phase ===
    UpdateEntryNotes {
        entry_id: String,
        notes: Option<String>,
    },
    /// `play_id` names the row of the item-complete sheet being marked, and
    /// must belong to `entry_id` (#1739).
    UpdateEntryScore {
        entry_id: String,
        play_id: String,
        score: Option<u8>,
    },
    /// `tempo` is as displayed, in `click.metre.unit` beats per minute; the
    /// core normalises it to crotchets before it is stored (#1499). `play_id`
    /// names the row, as `UpdateEntryScore`.
    UpdateEntryTempo {
        entry_id: String,
        play_id: String,
        tempo: Option<u16>,
        observed: TempoObservation,
        click: Option<ClickState>,
    },
    UpdateSessionNotes {
        notes: Option<String>,
    },
    SaveSession {
        now: DateTime<Utc>,
    },
    DiscardSession,

    // === Recovery ===
    RecoverSession {
        session: ActiveSession,
        now: DateTime<Utc>,
    },

    // === History ===
    UpdateSessionScore {
        score: Option<u8>,
    },
}

// ── Helpers ────────────────────────────────────────────────────────────

/// Format seconds into a human-readable duration string.
pub fn format_duration_display(secs: u64) -> String {
    let hours = secs / 3600;
    let minutes = (secs % 3600) / 60;
    let seconds = secs % 60;

    if hours > 0 {
        format!("{hours}h {minutes}m {seconds}s")
    } else if minutes > 0 {
        format!("{minutes}m {seconds}s")
    } else {
        format!("{seconds}s")
    }
}

/// The builder's planned-duration dialect ("12 min" for whole minutes) —
/// shared by block rows, per-entry planned labels, and the builder total.
pub fn format_planned_duration(secs: u64) -> String {
    if secs.is_multiple_of(60) {
        format!("{} min", secs / 60)
    } else {
        format_duration_display(secs)
    }
}

/// Coarse "45m" / "2h 15m" total (Pencil's pattern) for session-summary lines —
/// minutes floored, seconds dropped. Distinct from `format_duration_display`,
/// which keeps seconds for the live timer and per-entry rows.
pub fn format_duration_summary(secs: u64) -> String {
    let total_minutes = secs / 60;
    let hours = total_minutes / 60;
    let minutes = total_minutes % 60;
    if hours > 0 {
        format!("{hours}h {minutes}m")
    } else {
        format!("{minutes}m")
    }
}

fn create_entry(
    item_id: &str,
    item_title: &str,
    item_type: ItemKind,
    position: usize,
) -> SetlistEntry {
    SetlistEntry {
        id: ulid::Ulid::generate().to_string(),
        item_id: item_id.to_string(),
        item_title: item_title.to_string(),
        item_type,
        position,
        duration_secs: 0,
        status: EntryStatus::NotAttempted,
        notes: None,
        intention: None,
        planned_duration_secs: None,
        group_id: None,
        planned_variation_id: None,
        planned_rep_target: None,
        plays: Vec::new(),
    }
}

fn reindex_entries(entries: &mut [SetlistEntry]) {
    for (i, entry) in entries.iter_mut().enumerate() {
        entry.position = i;
    }
}

/// Partition entries into ordered units: a contiguous run sharing a `Some`
/// `group_id` is one unit (a block); every `None` entry is its own unit.
fn into_units(entries: Vec<SetlistEntry>) -> Vec<Vec<SetlistEntry>> {
    let mut units: Vec<Vec<SetlistEntry>> = Vec::new();
    for entry in entries {
        match &entry.group_id {
            Some(g) => {
                let extends = units
                    .last()
                    .and_then(|u| u.first())
                    .and_then(|e| e.group_id.as_deref())
                    == Some(g.as_str());
                if extends {
                    units.last_mut().expect("checked above").push(entry);
                } else {
                    units.push(vec![entry]);
                }
            }
            None => units.push(vec![entry]),
        }
    }
    units
}

/// True when every `group_id` occupies a single contiguous run — the block
/// invariant a reorder must never break.
fn groups_contiguous(entries: &[SetlistEntry]) -> bool {
    let mut closed: std::collections::HashSet<&str> = std::collections::HashSet::new();
    let mut current: Option<&str> = None;
    for entry in entries {
        let g = entry.group_id.as_deref();
        if g != current {
            if let Some(prev) = current {
                closed.insert(prev);
            }
            if let Some(g) = g {
                if closed.contains(g) {
                    return false;
                }
            }
            current = g;
        }
    }
    true
}

/// Clear the `group_id` of any block left without its anchor piece — a block
/// only means "this piece's warm-up", so when the piece goes the related
/// exercises become standalone (§7.4 dissolve).
fn dissolve_pieceless_groups(entries: &mut [SetlistEntry]) {
    let anchored: std::collections::HashSet<&str> = entries
        .iter()
        .filter(|e| e.item_type == ItemKind::Piece)
        .filter_map(|e| e.group_id.as_deref())
        .collect();
    let orphans: std::collections::HashSet<String> = entries
        .iter()
        .filter_map(|e| e.group_id.clone())
        .filter(|g| !anchored.contains(g.as_str()))
        .collect();
    for entry in entries.iter_mut() {
        if entry
            .group_id
            .as_deref()
            .is_some_and(|g| orphans.contains(g))
        {
            entry.group_id = None;
        }
    }
}

fn freeze_rep_state(entry: &mut SetlistEntry) {
    if let Some(play) = entry.open_play_mut() {
        if let (Some(target), Some(count)) = (play.rep_target, play.rep_count) {
            play.rep_target_reached = Some(count >= target);
        }
    }
}

/// An entry that has just become current opens its first play, seeded from the
/// builder's plan (#1739 decisions 3 and 5), or from the item's first live
/// variation when the builder set no plan (#1758): starting on nothing left
/// the picker reading "Pick a variation" while the clock already ran, and the
/// unattributed seconds became a row the musician never asked for. An item
/// with no live variants, a piece included, still opens unattributed, exactly
/// as decision 3 intends. Idempotent: a recovered session already carries its
/// plays.
fn open_first_play(entry: &mut SetlistEntry, items: &[Item], now: DateTime<Utc>) {
    if entry.plays.is_empty() {
        let variation_id = entry.planned_variation_id.clone().or_else(|| {
            items
                .iter()
                .find(|item| item.id == entry.item_id)
                .and_then(|item| {
                    item.variants
                        .iter()
                        .filter(|v| v.deleted_at.is_none())
                        .min_by_key(|v| v.position)
                        .map(|v| v.id.clone())
                })
        });
        entry.plays.push(VariationPlay::opened(
            variation_id,
            entry.planned_rep_target,
            now,
        ));
    }
}

/// Stamp the open play's seconds from its own start, so a switch mid item
/// splits the time rather than double-counting it.
fn close_open_play(entry: &mut SetlistEntry, now: DateTime<Utc>) {
    if let Some(play) = entry.open_play_mut() {
        play.seconds = (now - play.started_at).num_seconds().max(0) as u64;
    }
}

/// A stray tap on the picker is not practice: every terminal transition drops
/// the plays that recorded nothing and ran for under five seconds. A practised
/// entry always keeps at least one, though, so decision 3's invariant holds and
/// the item-complete sheet always has a row to mark: dropping the only play
/// would leave the shell sending a `play_id` the core has just deleted.
fn drop_incidental_play(entry: &mut SetlistEntry) {
    if entry.plays.len() < 2 {
        return;
    }
    let opened = entry.plays[0].clone();
    entry.plays.retain(|p| !p.is_incidental());
    if entry.plays.is_empty() {
        entry.plays.push(opened);
    }
}

fn drop_incidental_plays(entries: &mut [SetlistEntry]) {
    for entry in entries.iter_mut() {
        drop_incidental_play(entry);
    }
}

/// The first tap is what switches the counter on: it writes the target along
/// with itself, so an untouched entry keeps all four rep fields `None` and
/// banks nothing (design-principles T19). A target set in the builder is kept.
fn record_rep(model: &mut Model, action: RepAction, now: DateTime<Utc>) -> Command<Effect, Event> {
    let SessionStatus::Active(ref mut active) = model.session_status else {
        return crux_core::render::render();
    };
    let Some(entry) = active.entries.get_mut(active.current_index) else {
        return crux_core::render::render();
    };
    // Repetitions belong to the variation being played, so they retarget the
    // open play and reset when a switch opens the next one (#1739 decision 6).
    open_first_play(entry, &model.items, now);
    let Some(play) = entry.open_play_mut() else {
        return crux_core::render::render();
    };
    if play.rep_target_reached == Some(true) {
        return crux_core::render::render();
    }

    let target = *play
        .rep_target
        .get_or_insert(validation::DEFAULT_REP_TARGET);
    let count = play.rep_count.unwrap_or(0);
    let new_count = match action {
        RepAction::Success => (count + 1).min(target),
        RepAction::Missed => count.saturating_sub(1),
    };
    play.rep_count = Some(new_count);
    play.rep_target_reached = Some(new_count >= target);
    let history = play.rep_history.get_or_insert_with(Vec::new);
    if history.len() < validation::MAX_REP_HISTORY {
        history.push(RepEvent { action, at: now });
    }

    model.last_error = None;
    Command::all([
        Command::notify_shell(AppEffect::SaveSessionInProgress(active.clone())).into(),
        crux_core::render::render(),
    ])
}

/// Find an entry by id in Active *or* Summary phase, so the mid-session
/// reflection sheet can write per-entry data before the summary screen.
fn entry_for_update_mut<'a>(model: &'a mut Model, entry_id: &str) -> Option<&'a mut SetlistEntry> {
    match &mut model.session_status {
        SessionStatus::Active(active) => active.entries.iter_mut().find(|e| e.id == entry_id),
        SessionStatus::Summary(summary) => summary.entries.iter_mut().find(|e| e.id == entry_id),
        SessionStatus::Idle | SessionStatus::Building(_) => None,
    }
}

// Unlike score/notes (post-play reflection only, `entry_for_update_mut`), the
// variation tag is also a Building-phase plan ("which rung am I about to climb"),
// so its lookup spans all three phases (#1083). The immutable twin exists for
// checks that also read the library (a mutable borrow would lock the model).
fn entry_for_variant<'a>(model: &'a Model, entry_id: &str) -> Option<&'a SetlistEntry> {
    match &model.session_status {
        SessionStatus::Building(building) => building.entries.iter().find(|e| e.id == entry_id),
        SessionStatus::Active(active) => active.entries.iter().find(|e| e.id == entry_id),
        SessionStatus::Summary(summary) => summary.entries.iter().find(|e| e.id == entry_id),
        SessionStatus::Idle => None,
    }
}

fn entry_for_variant_mut<'a>(model: &'a mut Model, entry_id: &str) -> Option<&'a mut SetlistEntry> {
    match &mut model.session_status {
        SessionStatus::Building(building) => building.entries.iter_mut().find(|e| e.id == entry_id),
        SessionStatus::Active(active) => active.entries.iter_mut().find(|e| e.id == entry_id),
        SessionStatus::Summary(summary) => summary.entries.iter_mut().find(|e| e.id == entry_id),
        SessionStatus::Idle => None,
    }
}

fn transition_to_summary(
    active: &mut ActiveSession,
    items: &[Item],
    now: DateTime<Utc>,
    completion_status: CompletionStatus,
) -> SummarySession {
    let elapsed = (now - active.current_item_started_at).num_seconds().max(0) as u64;
    if let Some(entry) = active.entries.get_mut(active.current_index) {
        entry.duration_secs = elapsed;
        entry.status = EntryStatus::Completed;
        open_first_play(entry, items, active.current_item_started_at);
        close_open_play(entry, now);
        freeze_rep_state(entry);
    }

    if completion_status == CompletionStatus::EndedEarly {
        for entry in active.entries.iter_mut().skip(active.current_index + 1) {
            entry.status = EntryStatus::NotAttempted;
            entry.duration_secs = 0;
            entry.plays.clear();
        }
    }

    drop_incidental_plays(&mut active.entries);

    SummarySession {
        id: active.id.clone(),
        entries: active.entries.clone(),
        session_started_at: active.session_started_at,
        session_ended_at: now,
        session_notes: None,
        completion_status,
        session_score: None,
    }
}

// ── Event Handler ──────────────────────────────────────────────────────

pub fn handle_session_event(event: SessionEvent, model: &mut Model) -> Command<Effect, Event> {
    match event {
        // ── Building Phase ─────────────────────────────────────────
        SessionEvent::StartBuilding => {
            if !matches!(model.session_status, SessionStatus::Idle) {
                model.last_error = Some("A practice is already in progress".to_string());
                return crux_core::render::render();
            }
            model.session_status = SessionStatus::Building(BuildingSession::default());
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::SetEntryIntention {
            entry_id,
            intention,
        } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                // No-op when not in Building state
                return crux_core::render::render();
            };

            if let Err(e) = validation::validate_intention(&intention) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            let Some(entry) = building.entries.iter_mut().find(|e| e.id == entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found in setlist"));
                return crux_core::render::render();
            };

            entry.intention = intention;
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::SetEntryVariant {
            entry_id,
            variant_id,
        } => {
            // The plan is a Building-phase thing: once practice starts, the
            // record is the plays and `SwitchVariation` is what changes it
            // (#1739 decision 5).
            if !matches!(model.session_status, SessionStatus::Building(_)) {
                model.last_error =
                    Some("A variation can only be planned while building".to_string());
                return crux_core::render::render();
            }

            let Some(entry) = entry_for_variant(model, &entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found"));
                return crux_core::render::render();
            };

            if let Err(e) = validation::validate_entry_variation(entry, &variant_id, model) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            let Some(entry) = entry_for_variant_mut(model, &entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found"));
                return crux_core::render::render();
            };
            entry.planned_variation_id = variant_id;
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::SetRepTarget { entry_id, target } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                // No-op when not in Building state
                return crux_core::render::render();
            };

            if let Some(t) = target {
                if let Err(e) = validation::validate_rep_target(&Some(t)) {
                    model.last_error = Some(e.to_string());
                    return crux_core::render::render();
                }
            }

            let Some(entry) = building.entries.iter_mut().find(|e| e.id == entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found in setlist"));
                return crux_core::render::render();
            };

            entry.planned_rep_target = target;
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::SetEntryDuration {
            entry_id,
            duration_secs,
        } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                // No-op when not in Building state
                return crux_core::render::render();
            };

            if let Err(e) = validation::validate_planned_duration(&duration_secs) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            let Some(entry) = building.entries.iter_mut().find(|e| e.id == entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found in setlist"));
                return crux_core::render::render();
            };

            entry.planned_duration_secs = duration_secs;
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::StartBuildingWith { item_id } => {
            if !matches!(model.session_status, SessionStatus::Idle) {
                model.last_error = Some("A practice is already in progress".to_string());
                return crux_core::render::render();
            }
            if !model.items.iter().any(|i| i.id == item_id) {
                model.last_error = Some(LibraryError::NotFound { id: item_id }.to_string());
                return crux_core::render::render();
            }
            model.session_status = SessionStatus::Building(BuildingSession::default());
            handle_session_event(SessionEvent::AddToSetlist { item_id }, model)
        }

        SessionEvent::StartBuildingFromSuggestion { now } => {
            if !matches!(model.session_status, SessionStatus::Idle) {
                model.last_error = Some("A practice is already in progress".to_string());
                return crux_core::render::render();
            }
            // Nothing to suggest is not an error: the CTA cannot be on screen
            // in that case, and a race must not strand an empty builder.
            let Some(suggestion) = crate::app::derive_up_next(model, now) else {
                return crux_core::render::render();
            };

            let mut building = BuildingSession::default();
            let group_id = ulid::Ulid::generate().to_string();
            for suggested in &suggestion.items {
                let position = building.entries.len();
                let mut entry = create_entry(
                    &suggested.item_id,
                    &suggested.item_title,
                    suggested.item_type.clone(),
                    position,
                );
                entry.group_id = Some(group_id.clone());
                entry.planned_variation_id.clone_from(&suggested.variant_id);
                building.entries.push(entry);
            }

            model.session_status = SessionStatus::Building(building);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::StartBuildingWithPriorities { now } => {
            if !matches!(model.session_status, SessionStatus::Idle) {
                model.last_error = Some("A practice is already in progress".to_string());
                return crux_core::render::render();
            }
            // Nothing starred is not an error, for the same reason as the Up
            // next CTA: the button cannot be on screen, and a race must not
            // strand an empty builder.
            let ordered = crate::app::derive_priorities(model, now);
            if ordered.is_empty() {
                return crux_core::render::render();
            }

            model.session_status = SessionStatus::Building(BuildingSession::default());
            // `AddToSetlist` owns block formation, deduping and idempotency
            // (#939), so seeding folds over it rather than building entries a
            // second way. Every step's command is kept: dropping all but the
            // last would silently swallow any effect it grows later.
            Command::all(
                ordered
                    .into_iter()
                    .map(|item_id| {
                        handle_session_event(SessionEvent::AddToSetlist { item_id }, model)
                    })
                    .collect::<Vec<_>>(),
            )
        }

        SessionEvent::AddToSetlist { item_id } => {
            if !matches!(model.session_status, SessionStatus::Building(_)) {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            }

            // Membership is binary (the picker/sheet toggle relies on it):
            // re-adding a present item is an idempotent no-op, not a duplicate (#939).
            if let SessionStatus::Building(ref building) = model.session_status {
                if building.entries.iter().any(|e| e.item_id == item_id) {
                    model.last_error = None;
                    return crux_core::render::render();
                }
            }

            // Resolve the item and — for a piece — its related exercises as owned
            // tuples before taking the mutable Building borrow.
            let Some(item) = model.items.iter().find(|i| i.id == item_id) else {
                model.last_error = Some(LibraryError::NotFound { id: item_id }.to_string());
                return crux_core::render::render();
            };
            let piece = (item.id.clone(), item.title.clone(), item.kind.clone());
            let related: Vec<(String, String, ItemKind)> = if item.kind == ItemKind::Piece {
                item.linked_exercise_ids
                    .iter()
                    .filter_map(|ex_id| {
                        model
                            .items
                            .iter()
                            .find(|i| &i.id == ex_id && i.kind == ItemKind::Exercise)
                            .map(|i| (i.id.clone(), i.title.clone(), i.kind.clone()))
                    })
                    .collect()
            } else {
                Vec::new()
            };

            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Internal error: expected Building state".to_string());
                return crux_core::render::render();
            };

            // Skip related exercises already in the setlist — don't duplicate.
            let existing: std::collections::HashSet<String> =
                building.entries.iter().map(|e| e.item_id.clone()).collect();
            let related_to_add: Vec<(String, String, ItemKind)> = related
                .into_iter()
                .filter(|(id, _, _)| !existing.contains(id))
                .collect();

            // A block forms only when ≥1 related exercise actually comes along.
            let group_id = if related_to_add.is_empty() {
                None
            } else {
                Some(ulid::Ulid::generate().to_string())
            };

            // Related first (warm-up order), then the piece.
            for (id, title, kind) in &related_to_add {
                let position = building.entries.len();
                let mut entry = create_entry(id, title, kind.clone(), position);
                entry.group_id.clone_from(&group_id);
                building.entries.push(entry);
            }
            let position = building.entries.len();
            let mut piece_entry = create_entry(&piece.0, &piece.1, piece.2, position);
            piece_entry.group_id = group_id;
            building.entries.push(piece_entry);

            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::RemoveFromSetlist { entry_id } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            let len_before = building.entries.len();
            building.entries.retain(|e| e.id != entry_id);

            if building.entries.len() == len_before {
                model.last_error = Some(format!("Entry '{entry_id}' not found in setlist"));
                return crux_core::render::render();
            }

            dissolve_pieceless_groups(&mut building.entries);
            reindex_entries(&mut building.entries);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::ReorderSetlist {
            entry_id,
            new_position,
        } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            let Some(current_index) = building.entries.iter().position(|e| e.id == entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found in setlist"));
                return crux_core::render::render();
            };

            if new_position >= building.entries.len() {
                model.last_error = Some(format!(
                    "Invalid position: {new_position} (max: {})",
                    building.entries.len().saturating_sub(1)
                ));
                return crux_core::render::render();
            }

            let entry = building.entries.remove(current_index);
            building.entries.insert(new_position, entry);
            if !groups_contiguous(&building.entries) {
                // Revert — the move would split a block.
                let entry = building.entries.remove(new_position);
                building.entries.insert(current_index, entry);
                model.last_error = Some("Can't move an item out of its block".to_string());
                return crux_core::render::render();
            }
            reindex_entries(&mut building.entries);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::ReorderBlock {
            group_id,
            new_position,
        } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            let mut units = into_units(std::mem::take(&mut building.entries));
            let Some(current) = units.iter().position(|u| {
                u.first().and_then(|e| e.group_id.as_deref()) == Some(group_id.as_str())
            }) else {
                building.entries = units.into_iter().flatten().collect();
                model.last_error = Some(format!("Block '{group_id}' not found in setlist"));
                return crux_core::render::render();
            };

            let target = new_position.min(units.len().saturating_sub(1));
            let unit = units.remove(current);
            units.insert(target, unit);
            building.entries = units.into_iter().flatten().collect();
            reindex_entries(&mut building.entries);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::KeepOnlyPiece { group_id } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            let in_block = |e: &SetlistEntry| e.group_id.as_deref() == Some(group_id.as_str());
            if !building.entries.iter().any(in_block) {
                model.last_error = Some(format!("Block '{group_id}' not found in setlist"));
                return crux_core::render::render();
            }

            building
                .entries
                .retain(|e| !(in_block(e) && e.item_type == ItemKind::Exercise));
            // The lone piece left behind is no longer a block.
            for entry in building.entries.iter_mut().filter(|e| in_block(e)) {
                entry.group_id = None;
            }
            reindex_entries(&mut building.entries);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::UngroupBlock { group_id } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            let mut found = false;
            for entry in building
                .entries
                .iter_mut()
                .filter(|e| e.group_id.as_deref() == Some(group_id.as_str()))
            {
                entry.group_id = None;
                found = true;
            }
            if !found {
                model.last_error = Some(format!("Block '{group_id}' not found in setlist"));
                return crux_core::render::render();
            }
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::UngroupAllBlocks => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };
            for entry in &mut building.entries {
                entry.group_id = None;
            }
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::RemoveBlock { group_id } => {
            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            let len_before = building.entries.len();
            building
                .entries
                .retain(|e| e.group_id.as_deref() != Some(group_id.as_str()));
            if building.entries.len() == len_before {
                model.last_error = Some(format!("Block '{group_id}' not found in setlist"));
                return crux_core::render::render();
            }
            reindex_entries(&mut building.entries);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::AddExerciseToBlock { group_id, item_id } => {
            let SessionStatus::Building(ref building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            // Membership is binary, same idempotency as `AddToSetlist` (#939).
            if building.entries.iter().any(|e| e.item_id == item_id) {
                model.last_error = None;
                return crux_core::render::render();
            }

            let Some(anchor_index) = building.entries.iter().position(|e| {
                e.group_id.as_deref() == Some(group_id.as_str()) && e.item_type == ItemKind::Piece
            }) else {
                model.last_error = Some(format!("Block '{group_id}' not found in setlist"));
                return crux_core::render::render();
            };

            let Some(item) = model.items.iter().find(|i| i.id == item_id) else {
                model.last_error = Some(LibraryError::NotFound { id: item_id }.to_string());
                return crux_core::render::render();
            };
            if item.kind != ItemKind::Exercise {
                model.last_error = Some("Only an exercise can be added to a block".to_string());
                return crux_core::render::render();
            }
            let (id, title, kind) = (item.id.clone(), item.title.clone(), item.kind.clone());

            let SessionStatus::Building(ref mut building) = model.session_status else {
                model.last_error = Some("Internal error: expected Building state".to_string());
                return crux_core::render::render();
            };
            let mut entry = create_entry(&id, &title, kind, anchor_index);
            entry.group_id = Some(group_id);
            building.entries.insert(anchor_index, entry);
            reindex_entries(&mut building.entries);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::StartSession { now } => {
            let SessionStatus::Building(ref building) = model.session_status else {
                model.last_error = Some("Not in building state".to_string());
                return crux_core::render::render();
            };

            if let Err(e) = validation::validate_entries_not_empty(&building.entries, "Setlist") {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            let mut active = ActiveSession {
                id: ulid::Ulid::generate().to_string(),
                entries: building.entries.clone(),
                current_index: 0,
                current_item_started_at: now,
                session_started_at: now,
            };

            if let Some(entry) = active.entries.first_mut() {
                open_first_play(entry, &model.items, now);
            }

            let save_effect = AppEffect::SaveSessionInProgress(active.clone());
            model.session_status = SessionStatus::Active(active);
            model.last_error = None;

            Command::all([
                Command::notify_shell(save_effect).into(),
                crux_core::render::render(),
            ])
        }

        SessionEvent::CancelBuilding => {
            // Idempotent: already-Idle cancel is a no-op success, not a silent error (#944).
            match model.session_status {
                SessionStatus::Building(_) | SessionStatus::Idle => {
                    model.session_status = SessionStatus::Idle;
                    model.last_error = None;
                }
                _ => {
                    model.last_error = Some("Not in building state".to_string());
                }
            }
            crux_core::render::render()
        }

        // ── Active Phase ───────────────────────────────────────────
        SessionEvent::NextItem { now } => {
            let SessionStatus::Active(ref mut active) = model.session_status else {
                model.last_error = Some("Not in active state".to_string());
                return crux_core::render::render();
            };

            if active.current_index >= active.entries.len() - 1 {
                let summary =
                    transition_to_summary(active, &model.items, now, CompletionStatus::Completed);
                model.session_status = SessionStatus::Summary(summary);
                model.last_error = None;
                return crux_core::render::render();
            }

            let elapsed = (now - active.current_item_started_at).num_seconds().max(0) as u64;

            if let Some(entry) = active.entries.get_mut(active.current_index) {
                entry.duration_secs = elapsed;
                entry.status = EntryStatus::Completed;
                open_first_play(entry, &model.items, active.current_item_started_at);
                close_open_play(entry, now);
                freeze_rep_state(entry);
                drop_incidental_play(entry);
            }

            active.current_index += 1;
            active.current_item_started_at = now;
            if let Some(entry) = active.entries.get_mut(active.current_index) {
                open_first_play(entry, &model.items, now);
            }
            model.last_error = None;

            let save_effect = AppEffect::SaveSessionInProgress(active.clone());
            Command::all([
                Command::notify_shell(save_effect).into(),
                crux_core::render::render(),
            ])
        }

        SessionEvent::SkipItem { now } => {
            let SessionStatus::Active(ref mut active) = model.session_status else {
                model.last_error = Some("Not in active state".to_string());
                return crux_core::render::render();
            };

            if let Some(entry) = active.entries.get_mut(active.current_index) {
                entry.duration_secs = 0;
                entry.status = EntryStatus::Skipped;
                // Skipped means not practised, so the play opened when the item
                // became current goes (#1739 decision 3). A play that banked
                // repetitions or a mark first is not that play and survives,
                // exactly as rep state did before plays existed. Time alone
                // does not count here: the clock ran while they decided to skip.
                close_open_play(entry, now);
                freeze_rep_state(entry);
                entry.plays.retain(VariationPlay::recorded_something);
            }

            if active.current_index >= active.entries.len() - 1 {
                drop_incidental_plays(&mut active.entries);
                let summary = SummarySession {
                    id: active.id.clone(),
                    entries: active.entries.clone(),
                    session_started_at: active.session_started_at,
                    session_ended_at: now,
                    session_notes: None,
                    completion_status: CompletionStatus::Completed,
                    session_score: None,
                };
                model.session_status = SessionStatus::Summary(summary);
                model.last_error = None;
                return crux_core::render::render();
            }

            active.current_index += 1;
            active.current_item_started_at = now;
            if let Some(entry) = active.entries.get_mut(active.current_index) {
                open_first_play(entry, &model.items, now);
            }
            model.last_error = None;

            let save_effect = AppEffect::SaveSessionInProgress(active.clone());
            Command::all([
                Command::notify_shell(save_effect).into(),
                crux_core::render::render(),
            ])
        }

        SessionEvent::FinishSession { now } => {
            let SessionStatus::Active(ref mut active) = model.session_status else {
                model.last_error = Some("Not in active state".to_string());
                return crux_core::render::render();
            };

            let summary =
                transition_to_summary(active, &model.items, now, CompletionStatus::Completed);
            model.session_status = SessionStatus::Summary(summary);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::EndSessionEarly { now } => {
            let SessionStatus::Active(ref mut active) = model.session_status else {
                model.last_error = Some("Not in active state".to_string());
                return crux_core::render::render();
            };

            let summary =
                transition_to_summary(active, &model.items, now, CompletionStatus::EndedEarly);
            model.session_status = SessionStatus::Summary(summary);
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::RepGotIt { now } => record_rep(model, RepAction::Success, now),

        SessionEvent::RepMissed { now } => record_rep(model, RepAction::Missed, now),

        SessionEvent::SwitchVariation {
            entry_id,
            variation_id,
            now,
        } => {
            if !matches!(model.session_status, SessionStatus::Active(_)) {
                model.last_error = Some("Not in active state".to_string());
                return crux_core::render::render();
            }

            let Some(entry) = entry_for_variant(model, &entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found"));
                return crux_core::render::render();
            };

            // Switching to the variation already open writes nothing, so a
            // stray tap cannot clear the dots (#1739 decision 6). Checked
            // before capacity, or a full entry could not re-tap its own row.
            if entry.open_play().map(|p| p.variation_id.as_deref()) == Some(variation_id.as_deref())
            {
                model.last_error = None;
                return crux_core::render::render();
            }

            if let Err(e) = validation::validate_entry_variation(entry, &variation_id, model) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            if let Err(e) = validation::validate_play_capacity(entry) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            let SessionStatus::Active(ref mut active) = model.session_status else {
                return crux_core::render::render();
            };
            let Some(entry) = active.entries.iter_mut().find(|e| e.id == entry_id) else {
                return crux_core::render::render();
            };

            close_open_play(entry, now);
            freeze_rep_state(entry);
            let rep_target = entry.planned_rep_target;
            entry
                .plays
                .push(VariationPlay::opened(variation_id, rep_target, now));

            model.last_error = None;
            Command::all([
                Command::notify_shell(AppEffect::SaveSessionInProgress(active.clone())).into(),
                crux_core::render::render(),
            ])
        }

        // ── Entry Updates (Active or Summary) ──────────────────────
        // Accepted in both phases so the mid-session reflection sheet can record
        // as the user moves on. Invariant: only Completed entries can be scored.
        SessionEvent::UpdateEntryScore {
            entry_id,
            play_id,
            score,
        } => {
            if let Some(s) = score {
                if !(validation::MIN_SCORE..=validation::MAX_SCORE).contains(&s) {
                    return crux_core::render::render();
                }
            }

            let Some(entry) = entry_for_update_mut(model, &entry_id) else {
                return crux_core::render::render();
            };

            if entry.status != EntryStatus::Completed {
                return crux_core::render::render();
            }

            if let Err(e) = validation::validate_play_belongs(entry, &play_id) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            if let Some(play) = entry.plays.iter_mut().find(|p| p.id == play_id) {
                play.score = score;
            }
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::UpdateEntryTempo {
            entry_id,
            play_id,
            tempo,
            observed,
            click,
        } => {
            if let Some(ref state) = click {
                if let Err(e) = validation::validate_click_state(state) {
                    model.last_error = Some(e.to_string());
                    return crux_core::render::render();
                }
            }
            let crotchets = tempo.map(|displayed| {
                click
                    .as_ref()
                    .map_or(displayed, |c| c.metre.crotchet_bpm(displayed))
            });
            if let Err(_e) = validation::validate_achieved_tempo(&crotchets) {
                return crux_core::render::render();
            }

            // An unevidenced number is a pre-fill nobody looked at: record
            // nothing, and clear nothing, so it cannot destroy a real
            // measurement. Clearing is always honoured.
            if tempo.is_some() && !observed.is_evidenced() {
                return crux_core::render::render();
            }

            let Some(entry) = entry_for_update_mut(model, &entry_id) else {
                return crux_core::render::render();
            };

            if entry.status != EntryStatus::Completed {
                return crux_core::render::render();
            }

            if let Err(e) = validation::validate_play_belongs(entry, &play_id) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            if let Some(play) = entry.plays.iter_mut().find(|p| p.id == play_id) {
                play.achieved_tempo = crotchets;
                // The pattern is evidence only if the click was actually heard.
                play.click_pattern = if crotchets.is_some() && observed.click_sounding {
                    click
                } else {
                    None
                };
            }
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::UpdateEntryNotes { entry_id, notes } => {
            if let Err(e) = validation::validate_entry_notes(&notes) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            let Some(entry) = entry_for_update_mut(model, &entry_id) else {
                model.last_error = Some(format!("Entry '{entry_id}' not found"));
                return crux_core::render::render();
            };

            entry.notes = notes;
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::UpdateSessionNotes { notes } => {
            let SessionStatus::Summary(ref mut summary) = model.session_status else {
                model.last_error = Some("Not in summary state".to_string());
                return crux_core::render::render();
            };

            if let Err(e) = validation::validate_session_notes(&notes) {
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }

            summary.session_notes = notes;
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::UpdateSessionScore { score } => {
            if let Some(s) = score {
                if !(validation::MIN_SCORE..=validation::MAX_SCORE).contains(&s) {
                    return crux_core::render::render();
                }
            }
            let SessionStatus::Summary(ref mut summary) = model.session_status else {
                model.last_error = Some("Not in summary state".to_string());
                return crux_core::render::render();
            };
            summary.session_score = score;
            model.last_error = None;
            crux_core::render::render()
        }

        SessionEvent::SaveSession { now } => {
            let SessionStatus::Summary(ref summary) = model.session_status else {
                model.last_error = Some("Not in summary state".to_string());
                return crux_core::render::render();
            };

            let total_duration_secs: u64 = summary.entries.iter().map(|e| e.duration_secs).sum();

            let practice_session = PracticeSession {
                id: summary.id.clone(),
                entries: summary.entries.clone(),
                session_notes: summary.session_notes.clone(),
                started_at: summary.session_started_at,
                completed_at: now,
                total_duration_secs,
                completion_status: summary.completion_status.clone(),
                session_score: summary.session_score,
            };

            model.sessions.push(practice_session.clone());
            model.practice_summaries = crate::app::build_practice_summaries(&model.sessions);
            model.session_status = SessionStatus::Idle;
            model.last_error = None;

            let clear = Command::notify_shell(AppEffect::ClearSessionInProgress).into();
            model.record_success();
            Command::all([
                crate::persistence::save_session(practice_session),
                clear,
                crux_core::render::render(),
            ])
        }

        SessionEvent::DiscardSession => {
            if !matches!(model.session_status, SessionStatus::Summary(_)) {
                model.last_error = Some("Not in summary state".to_string());
                return crux_core::render::render();
            }

            model.session_status = SessionStatus::Idle;
            model.last_error = None;

            Command::all([
                Command::notify_shell(AppEffect::ClearSessionInProgress).into(),
                crux_core::render::render(),
            ])
        }

        // ── Recovery ───────────────────────────────────────────────
        SessionEvent::RecoverSession { session, now } => {
            if !matches!(model.session_status, SessionStatus::Idle) {
                model.last_error =
                    Some("Cannot recover: a practice is already in progress".to_string());
                return crux_core::render::render();
            }

            // Re-anchor the running item's wall-clock timer: the blob's anchor
            // is from before the kill, so resuming hours later would otherwise
            // show that gap as elapsed practice (#962).
            let mut session = session;
            session.current_item_started_at = now;
            model.session_status = SessionStatus::Active(session);
            model.last_error = None;
            crux_core::render::render()
        }
    }
}

// ── Tests ──────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::Intrada;
    use crux_core::App;

    fn model_with_library() -> Model {
        let now = Utc::now();
        Model {
            items: vec![
                Item {
                    id: "piece-1".to_string(),
                    title: "Moonlight Sonata".to_string(),
                    kind: ItemKind::Piece,
                    composer: Some("Beethoven".to_string()),
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
                },
                Item {
                    id: "piece-2".to_string(),
                    title: "Clair de Lune".to_string(),
                    kind: ItemKind::Piece,
                    composer: Some("Debussy".to_string()),
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
                },
                Item {
                    id: "exercise-1".to_string(),
                    title: "C Major Scale".to_string(),
                    kind: ItemKind::Exercise,
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
                },
            ],
            ..Default::default()
        }
    }

    fn update(model: &mut Model, event: Event) {
        let app = Intrada;
        let _cmd = app.update(event, model);
    }

    // --- Block grouping (related exercises travel with a piece) ---

    fn linked_model() -> Model {
        let now = Utc::now();
        let mk = |id: &str, title: &str, kind: ItemKind, linked: &[&str]| Item {
            id: id.to_string(),
            title: title.to_string(),
            kind,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            linked_exercise_ids: linked.iter().map(|s| s.to_string()).collect(),
            created_at: now,
            updated_at: now,
            priority: false,
            chord_chart: None,
            variants: vec![],
            photo_id: None,
            metre: None,
        };
        Model {
            items: vec![
                mk("piece-P", "Sonata", ItemKind::Piece, &["ex-A", "ex-B"]),
                mk("piece-Q", "Nocturne", ItemKind::Piece, &[]),
                mk("piece-R", "Etude", ItemKind::Piece, &["ex-C"]),
                mk("ex-A", "Scales", ItemKind::Exercise, &[]),
                mk("ex-B", "Arpeggios", ItemKind::Exercise, &[]),
                mk("ex-C", "Sight-reading", ItemKind::Exercise, &[]),
                mk("ex-D", "Trills", ItemKind::Exercise, &[]),
            ],
            ..Default::default()
        }
    }

    fn building_entries(model: &Model) -> &[SetlistEntry] {
        match &model.session_status {
            SessionStatus::Building(b) => &b.entries,
            _ => panic!("expected Building state"),
        }
    }

    fn session_entries(model: &Model) -> &[SetlistEntry] {
        match &model.session_status {
            SessionStatus::Building(b) => &b.entries,
            SessionStatus::Active(a) => &a.entries,
            SessionStatus::Summary(s) => &s.entries,
            SessionStatus::Idle => panic!("expected a session"),
        }
    }

    fn play_of(entry: &SetlistEntry) -> &VariationPlay {
        entry.open_play().expect("the entry has an open play")
    }

    fn first_play_id(model: &Model, entry_id: &str) -> String {
        session_entries(model)
            .iter()
            .find(|e| e.id == entry_id)
            .expect("the entry is in the session")
            .plays
            .first()
            .expect("the entry has a play")
            .id
            .clone()
    }

    fn ids(model: &Model) -> Vec<String> {
        building_entries(model)
            .iter()
            .map(|e| e.item_id.clone())
            .collect()
    }

    fn add(model: &mut Model, item_id: &str) {
        update(
            model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: item_id.to_string(),
            }),
        );
    }

    fn group_of(model: &Model, item_id: &str) -> Option<String> {
        building_entries(model)
            .iter()
            .find(|e| e.item_id == item_id)
            .and_then(|e| e.group_id.clone())
    }

    #[test]
    fn start_building_with_seeds_exercise_from_idle() {
        let mut m = linked_model();
        update(
            &mut m,
            Event::Session(SessionEvent::StartBuildingWith {
                item_id: "ex-C".to_string(),
            }),
        );
        let e = building_entries(&m);
        assert_eq!(e.len(), 1);
        assert_eq!(e[0].item_id, "ex-C");
        assert_eq!(e[0].group_id, None);
        assert_eq!(m.last_error, None);
    }

    #[test]
    fn start_building_with_piece_forms_block() {
        let mut m = linked_model();
        update(
            &mut m,
            Event::Session(SessionEvent::StartBuildingWith {
                item_id: "piece-P".to_string(),
            }),
        );
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
        let e = building_entries(&m);
        assert!(e[0].group_id.is_some(), "block has a group_id");
        assert!(e.iter().all(|x| x.group_id == e[0].group_id));
    }

    #[test]
    fn start_building_with_rejects_when_not_idle() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-A");
        update(
            &mut m,
            Event::Session(SessionEvent::StartBuildingWith {
                item_id: "ex-C".to_string(),
            }),
        );
        assert_eq!(
            m.last_error.as_deref(),
            Some("A practice is already in progress")
        );
        assert_eq!(ids(&m), ["ex-A"], "existing setlist untouched");
    }

    #[test]
    fn start_building_with_unknown_item_stays_idle() {
        let mut m = linked_model();
        update(
            &mut m,
            Event::Session(SessionEvent::StartBuildingWith {
                item_id: "nope".to_string(),
            }),
        );
        assert!(m.last_error.is_some());
        assert!(
            matches!(m.session_status, SessionStatus::Idle),
            "a failed seed must not leave an empty building session"
        );
    }

    // ── The Up next card's seeding event (#1082) ─────────────────────

    fn suggestion_model() -> Model {
        let mut m = linked_model();
        // Pin the anchor so these tests assert the seeding, not the ranking
        // (which `suggestion.rs` covers).
        for item in &mut m.items {
            if item.id == "piece-P" {
                item.priority = true;
            }
        }
        m
    }

    fn start_from_suggestion(model: &mut Model) {
        update(
            model,
            Event::Session(SessionEvent::StartBuildingFromSuggestion { now: Utc::now() }),
        );
    }

    #[test]
    fn start_building_from_suggestion_seeds_the_derived_block() {
        let mut m = suggestion_model();
        start_from_suggestion(&mut m);

        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
        let e = building_entries(&m);
        assert!(e[0].group_id.is_some(), "the seeded block has a group_id");
        assert!(
            e.iter().all(|x| x.group_id == e[0].group_id),
            "one block, not three standalone entries"
        );
        assert_eq!(m.last_error, None);
    }

    #[test]
    fn start_building_from_suggestion_caps_the_block_at_three_items() {
        let mut m = suggestion_model();
        for item in &mut m.items {
            if item.id == "piece-P" {
                item.linked_exercise_ids = vec![
                    "ex-A".to_string(),
                    "ex-B".to_string(),
                    "ex-C".to_string(),
                    "ex-D".to_string(),
                ];
            }
        }
        start_from_suggestion(&mut m);

        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
    }

    #[test]
    fn start_building_from_suggestion_rejects_when_not_idle() {
        let mut m = suggestion_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-C");
        start_from_suggestion(&mut m);

        assert_eq!(
            m.last_error.as_deref(),
            Some("A practice is already in progress")
        );
        assert_eq!(ids(&m), ["ex-C"], "existing setlist untouched");
    }

    #[test]
    fn start_building_from_suggestion_is_a_no_op_with_nothing_to_suggest() {
        // No piece has a related exercise linked, so there is no block to resume.
        let mut m = linked_model();
        m.items.retain(|i| i.id == "piece-Q" || i.id == "ex-D");
        start_from_suggestion(&mut m);

        assert!(
            matches!(m.session_status, SessionStatus::Idle),
            "an empty derivation must not leave an empty building session"
        );
        assert_eq!(m.last_error, None, "nothing to suggest is not an error");
    }

    #[test]
    fn start_building_from_suggestion_attributes_the_current_step() {
        let mut m = suggestion_model();
        let step_id = "v-C".to_string();
        for item in &mut m.items {
            if item.id == "ex-A" {
                item.variants = vec![crate::domain::variant::Variant {
                    id: step_id.clone(),
                    label: "C".to_string(),
                    position: 0,
                    updated_at: Utc::now(),
                    deleted_at: None,
                }];
            }
        }
        start_from_suggestion(&mut m);

        let e = building_entries(&m);
        let seeded = e.iter().find(|x| x.item_id == "ex-A").expect("ex-A seeded");
        assert_eq!(
            seeded.planned_variation_id.as_deref(),
            Some(step_id.as_str())
        );
        let unladdered = e.iter().find(|x| x.item_id == "ex-B").expect("ex-B seeded");
        assert_eq!(unladdered.planned_variation_id, None);
    }

    #[test]
    fn start_building_from_suggestion_makes_no_network_call() {
        let mut m = suggestion_model();
        let app = Intrada;
        let mut cmd = app.update(
            Event::Session(SessionEvent::StartBuildingFromSuggestion { now: Utc::now() }),
            &mut m,
        );
        assert!(
            cmd.effects().all(|e| matches!(e, Effect::Render(_))),
            "the suggestion is derived from data already in the model: no HTTP, \
             no storage read (invariant 1)"
        );
    }

    #[test]
    fn start_building_from_suggestion_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(Event::Session(
            SessionEvent::StartBuildingFromSuggestion { now: Utc::now() },
        ));
    }

    // ── "Practise your priorities" (#981) ────────────────────────────

    fn star(model: &mut Model, starred: &[&str]) {
        for item in &mut model.items {
            if starred.contains(&item.id.as_str()) {
                item.priority = true;
            }
        }
    }

    /// Same mark and return count on every fixture, so the expected interval
    /// is identical and only the gap decides the order.
    fn practised_days_ago(model: &mut Model, item_id: &str, days: i64) {
        model.practice_summaries.insert(
            item_id.to_string(),
            crate::model::ItemPracticeSummary {
                session_count: 4,
                latest_score: Some(6),
                last_practiced_at: Some((Utc::now() - chrono::Duration::days(days)).to_rfc3339()),
                ..crate::model::ItemPracticeSummary::fixture()
            },
        );
    }

    fn start_with_priorities(model: &mut Model) {
        update(
            model,
            Event::Session(SessionEvent::StartBuildingWithPriorities { now: Utc::now() }),
        );
    }

    #[test]
    fn start_building_with_priorities_seeds_every_starred_item() {
        let mut m = linked_model();
        star(&mut m, &["piece-Q", "ex-D"]);
        start_with_priorities(&mut m);

        assert_eq!(
            ids(&m),
            ["piece-Q", "ex-D"],
            "both starred items reach the setlist; the ordering itself is pinned in priorities.rs"
        );
        assert_eq!(m.last_error, None);
    }

    #[test]
    fn start_building_with_priorities_seeds_least_ready_first() {
        let mut m = linked_model();
        star(&mut m, &["piece-Q", "ex-D"]);
        practised_days_ago(&mut m, "piece-Q", 2);
        practised_days_ago(&mut m, "ex-D", 90);
        start_with_priorities(&mut m);

        assert_eq!(
            ids(&m),
            ["ex-D", "piece-Q"],
            "the longer-neglected item leads, against both library order and the alphabet"
        );
    }

    #[test]
    fn start_building_with_priorities_brings_a_starred_pieces_block() {
        let mut m = linked_model();
        star(&mut m, &["piece-P"]);
        start_with_priorities(&mut m);

        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
        let e = building_entries(&m);
        assert!(e[0].group_id.is_some(), "the seeded piece keeps its block");
        assert!(e.iter().all(|x| x.group_id == e[0].group_id));
    }

    #[test]
    fn start_building_with_priorities_seeds_a_starred_exercise_once() {
        let mut m = linked_model();
        star(&mut m, &["piece-P", "ex-A"]);
        start_with_priorities(&mut m);

        assert_eq!(
            ids(&m).iter().filter(|id| *id == "ex-A").count(),
            1,
            "starred in its own right and pulled in by its piece is still one entry"
        );
    }

    #[test]
    fn start_building_with_priorities_rejects_when_not_idle() {
        let mut m = linked_model();
        star(&mut m, &["piece-Q"]);
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-C");
        start_with_priorities(&mut m);

        assert_eq!(
            m.last_error.as_deref(),
            Some("A practice is already in progress")
        );
        assert_eq!(ids(&m), ["ex-C"], "existing setlist untouched");
    }

    #[test]
    fn start_building_with_priorities_is_a_no_op_with_nothing_starred() {
        let mut m = linked_model();
        start_with_priorities(&mut m);

        assert!(
            matches!(m.session_status, SessionStatus::Idle),
            "an empty priority set must not leave an empty building session"
        );
        assert_eq!(m.last_error, None, "nothing starred is not an error");
    }

    #[test]
    fn start_building_with_priorities_makes_no_network_call() {
        let mut m = linked_model();
        star(&mut m, &["piece-P"]);
        let app = Intrada;
        let mut cmd = app.update(
            Event::Session(SessionEvent::StartBuildingWithPriorities { now: Utc::now() }),
            &mut m,
        );
        assert!(
            cmd.effects().all(|e| matches!(e, Effect::Render(_))),
            "the priority set is derived from data already in the model: no HTTP, \
             no storage read (invariant 1)"
        );
    }

    #[test]
    fn start_building_with_priorities_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(Event::Session(
            SessionEvent::StartBuildingWithPriorities { now: Utc::now() },
        ));
    }

    #[test]
    fn add_to_setlist_is_idempotent_by_item_id() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-C");
        add(&mut m, "ex-C");
        assert_eq!(ids(&m), ["ex-C"], "second add of the same item is a no-op");
        assert_eq!(m.last_error, None);
    }

    #[test]
    fn add_piece_twice_does_not_duplicate_block() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        add(&mut m, "piece-P");
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
        assert_eq!(m.last_error, None);
    }

    #[test]
    fn re_adding_present_piece_is_a_full_no_op_even_with_new_relateds() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-Q");
        if let Some(piece) = m.items.iter_mut().find(|i| i.id == "piece-Q") {
            piece.linked_exercise_ids = vec!["ex-C".to_string()];
        }
        add(&mut m, "piece-Q");
        assert_eq!(
            ids(&m),
            ["piece-Q"],
            "membership no-op wins; newly linked relateds come in by removing and re-adding"
        );
    }

    #[test]
    fn add_piece_pulls_related_into_a_block_related_first() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        let e = building_entries(&m);
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
        let g = e[0].group_id.clone();
        assert!(g.is_some(), "block has a group_id");
        assert!(
            e.iter().all(|x| x.group_id == g),
            "all three share the group"
        );
        assert_eq!((e[0].position, e[1].position, e[2].position), (0, 1, 2));
    }

    #[test]
    fn add_piece_without_related_is_standalone() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-Q");
        let e = building_entries(&m);
        assert_eq!(e.len(), 1);
        assert_eq!(e[0].group_id, None);
    }

    #[test]
    fn add_exercise_directly_is_standalone() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-C");
        let e = building_entries(&m);
        assert_eq!(e.len(), 1);
        assert_eq!(e[0].group_id, None);
    }

    #[test]
    fn add_piece_skips_already_present_related() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-A");
        add(&mut m, "piece-P");
        let e = building_entries(&m);
        assert_eq!(
            e.iter().filter(|x| x.item_id == "ex-A").count(),
            1,
            "ex-A not duplicated"
        );
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
        assert_eq!(
            e[0].group_id, None,
            "the pre-existing ex-A stays standalone"
        );
        assert!(e[1].group_id.is_some());
        assert_eq!(e[1].group_id, e[2].group_id, "ex-B + piece form the block");
    }

    #[test]
    fn add_exercise_to_block_inserts_before_anchor_piece() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        let g = group_of(&m, "piece-P").unwrap();
        update(
            &mut m,
            Event::Session(SessionEvent::AddExerciseToBlock {
                group_id: g.clone(),
                item_id: "ex-D".to_string(),
            }),
        );
        assert_eq!(m.last_error, None);
        assert_eq!(ids(&m), ["ex-A", "ex-B", "ex-D", "piece-P"]);
        assert_eq!(group_of(&m, "ex-D"), Some(g.clone()));
        assert!(groups_contiguous(building_entries(&m)));
    }

    #[test]
    fn add_exercise_to_block_rejects_unknown_group() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        update(
            &mut m,
            Event::Session(SessionEvent::AddExerciseToBlock {
                group_id: "no-such-group".to_string(),
                item_id: "ex-D".to_string(),
            }),
        );
        assert!(m.last_error.is_some());
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"], "setlist untouched");
    }

    #[test]
    fn add_exercise_to_block_rejects_non_exercise_item() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        let g = group_of(&m, "piece-P").unwrap();
        update(
            &mut m,
            Event::Session(SessionEvent::AddExerciseToBlock {
                group_id: g,
                item_id: "piece-Q".to_string(),
            }),
        );
        assert!(m.last_error.is_some());
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"], "setlist untouched");
    }

    #[test]
    fn add_exercise_to_block_is_idempotent_by_item_id() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        let g = group_of(&m, "piece-P").unwrap();
        for _ in 0..2 {
            update(
                &mut m,
                Event::Session(SessionEvent::AddExerciseToBlock {
                    group_id: g.clone(),
                    item_id: "ex-D".to_string(),
                }),
            );
        }
        assert_eq!(m.last_error, None);
        assert_eq!(ids(&m), ["ex-A", "ex-B", "ex-D", "piece-P"]);
    }

    #[test]
    fn remove_block_removes_piece_and_related() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-C");
        add(&mut m, "piece-P");
        let g = group_of(&m, "piece-P").unwrap();
        update(
            &mut m,
            Event::Session(SessionEvent::RemoveBlock { group_id: g }),
        );
        assert!(m.last_error.is_none());
        assert_eq!(ids(&m), ["ex-C"]);
    }

    #[test]
    fn keep_only_piece_drops_related_and_destandalones() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        let g = group_of(&m, "piece-P").unwrap();
        update(
            &mut m,
            Event::Session(SessionEvent::KeepOnlyPiece { group_id: g }),
        );
        let e = building_entries(&m);
        assert_eq!(ids(&m), ["piece-P"]);
        assert_eq!(e[0].group_id, None, "lone piece is no longer a block");
    }

    #[test]
    fn ungroup_block_keeps_items_in_place() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        let g = group_of(&m, "piece-P").unwrap();
        update(
            &mut m,
            Event::Session(SessionEvent::UngroupBlock { group_id: g }),
        );
        let e = building_entries(&m);
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P"]);
        assert!(e.iter().all(|x| x.group_id.is_none()));
    }

    #[test]
    fn ungroup_all_clears_every_group() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        add(&mut m, "ex-C");
        update(&mut m, Event::Session(SessionEvent::UngroupAllBlocks));
        assert!(building_entries(&m).iter().all(|x| x.group_id.is_none()));
    }

    #[test]
    fn reorder_block_moves_the_whole_unit() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        add(&mut m, "ex-C");
        let g = group_of(&m, "piece-P").unwrap();
        update(
            &mut m,
            Event::Session(SessionEvent::ReorderBlock {
                group_id: g,
                new_position: 1,
            }),
        );
        assert_eq!(ids(&m), ["ex-C", "ex-A", "ex-B", "piece-P"]);
    }

    #[test]
    fn reorder_within_block_is_allowed() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        let ex_b = building_entries(&m)[1].id.clone();
        update(
            &mut m,
            Event::Session(SessionEvent::ReorderSetlist {
                entry_id: ex_b,
                new_position: 0,
            }),
        );
        assert!(m.last_error.is_none());
        let e = building_entries(&m);
        assert_eq!(ids(&m), ["ex-B", "ex-A", "piece-P"]);
        assert!(e.iter().all(|x| x.group_id == e[0].group_id));
    }

    #[test]
    fn reorder_that_splits_a_block_is_rejected() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "ex-C");
        add(&mut m, "piece-P");
        let ex_c = building_entries(&m)[0].id.clone();
        update(
            &mut m,
            Event::Session(SessionEvent::ReorderSetlist {
                entry_id: ex_c,
                new_position: 2,
            }),
        );
        assert!(m.last_error.is_some(), "splitting move rejected");
        assert_eq!(
            ids(&m),
            ["ex-C", "ex-A", "ex-B", "piece-P"],
            "order unchanged"
        );
    }

    #[test]
    fn building_view_projects_blocks_and_standalones() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P");
        add(&mut m, "ex-C");
        let vm = Intrada.view(&m);
        let b = vm.building_setlist.expect("building view");
        assert_eq!(b.item_count, 4);
        assert_eq!(b.block_count, 2);
        let block = &b.blocks[0];
        assert!(block.group_id.is_some());
        assert_eq!(block.piece_title.as_deref(), Some("Sonata"));
        assert_eq!(block.related_count, 2);
        assert_eq!(block.entries.len(), 3);
        let solo = &b.blocks[1];
        assert_eq!(solo.group_id, None);
        assert_eq!(solo.piece_title, None);
        assert_eq!(solo.related_count, 0);
    }

    #[test]
    fn two_adjacent_blocks_project_separately() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P"); // block G1: ex-A, ex-B, piece-P
        add(&mut m, "piece-R"); // block G2: ex-C, piece-R
        assert_eq!(ids(&m), ["ex-A", "ex-B", "piece-P", "ex-C", "piece-R"]);
        let g1 = group_of(&m, "piece-P");
        let g2 = group_of(&m, "piece-R");
        assert!(g1.is_some() && g2.is_some() && g1 != g2, "distinct blocks");
        let b = Intrada.view(&m).building_setlist.unwrap();
        assert_eq!(b.block_count, 2);
        assert_eq!(b.item_count, 5);
        assert_eq!(b.blocks[0].piece_title.as_deref(), Some("Sonata"));
        assert_eq!(b.blocks[0].related_count, 2);
        assert_eq!(b.blocks[1].piece_title.as_deref(), Some("Etude"));
        assert_eq!(b.blocks[1].related_count, 1);
    }

    #[test]
    fn standalone_can_move_between_two_blocks() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P"); // G1: 0,1,2
        add(&mut m, "piece-R"); // G2: 3,4
        add(&mut m, "ex-D"); // standalone: 5
        let ex_d = building_entries(&m)
            .iter()
            .find(|e| e.item_id == "ex-D")
            .unwrap()
            .id
            .clone();
        update(
            &mut m,
            Event::Session(SessionEvent::ReorderSetlist {
                entry_id: ex_d,
                new_position: 3,
            }),
        );
        assert!(
            m.last_error.is_none(),
            "a standalone between blocks splits neither"
        );
        assert_eq!(
            ids(&m),
            ["ex-A", "ex-B", "piece-P", "ex-D", "ex-C", "piece-R"]
        );
        assert!(groups_contiguous(building_entries(&m)));
    }

    #[test]
    fn removing_the_piece_dissolves_the_block_to_standalone() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P"); // ex-A, ex-B, piece-P (group)
        let piece = building_entries(&m)
            .iter()
            .find(|e| e.item_id == "piece-P")
            .unwrap()
            .id
            .clone();
        update(
            &mut m,
            Event::Session(SessionEvent::RemoveFromSetlist { entry_id: piece }),
        );
        assert!(m.last_error.is_none());
        assert_eq!(ids(&m), ["ex-A", "ex-B"]);
        assert!(
            building_entries(&m).iter().all(|x| x.group_id.is_none()),
            "related become standalone when their piece is removed"
        );
        let b = Intrada.view(&m).building_setlist.unwrap();
        assert_eq!(
            b.block_count, 2,
            "two standalone units, not one pieceless block"
        );
    }

    #[test]
    fn removing_a_related_keeps_the_block() {
        let mut m = linked_model();
        update(&mut m, Event::Session(SessionEvent::StartBuilding));
        add(&mut m, "piece-P"); // ex-A, ex-B, piece-P
        let ex_a = building_entries(&m)[0].id.clone();
        update(
            &mut m,
            Event::Session(SessionEvent::RemoveFromSetlist { entry_id: ex_a }),
        );
        assert!(m.last_error.is_none());
        assert_eq!(ids(&m), ["ex-B", "piece-P"]);
        let e = building_entries(&m);
        assert!(
            e[0].group_id.is_some() && e[0].group_id == e[1].group_id,
            "the piece + remaining related stay one block"
        );
    }

    // --- Building Phase Tests ---

    #[test]
    fn test_start_building() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));

        assert!(model.last_error.is_none());
        assert!(matches!(model.session_status, SessionStatus::Building(_)));
    }

    #[test]
    fn test_start_building_when_already_building() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(&mut model, Event::Session(SessionEvent::StartBuilding));

        assert!(model.last_error.is_some());
    }

    #[test]
    fn test_add_to_setlist() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(b.entries.len(), 1);
            assert_eq!(b.entries[0].item_title, "Moonlight Sonata");
            assert_eq!(b.entries[0].item_type, ItemKind::Piece);
            assert_eq!(b.entries[0].position, 0);
        } else {
            panic!("Expected Building state");
        }
    }

    #[test]
    fn test_add_to_setlist_item_not_found() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "nonexistent".to_string(),
            }),
        );

        assert!(model.last_error.is_some());
    }

    #[test]
    fn test_remove_from_setlist() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-2".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            b.entries[0].id.clone()
        } else {
            panic!("Expected Building state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::RemoveFromSetlist { entry_id }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(b.entries.len(), 1);
            assert_eq!(b.entries[0].item_title, "Clair de Lune");
            assert_eq!(b.entries[0].position, 0); // Re-indexed
        } else {
            panic!("Expected Building state");
        }
    }

    #[test]
    fn test_reorder_setlist() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-2".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "exercise-1".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            b.entries[2].id.clone() // exercise-1 at position 2
        } else {
            panic!("Expected Building state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::ReorderSetlist {
                entry_id,
                new_position: 0,
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(b.entries[0].item_title, "C Major Scale");
            assert_eq!(b.entries[1].item_title, "Moonlight Sonata");
            assert_eq!(b.entries[2].item_title, "Clair de Lune");
            assert_eq!(b.entries[0].position, 0);
            assert_eq!(b.entries[1].position, 1);
            assert_eq!(b.entries[2].position, 2);
        } else {
            panic!("Expected Building state");
        }
    }

    #[test]
    fn test_start_session_empty_setlist() {
        let mut model = model_with_library();
        let now = Utc::now();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        assert!(model.last_error.is_some());
        assert!(matches!(model.session_status, SessionStatus::Building(_)));
    }

    #[test]
    fn test_start_session_with_items() {
        let mut model = model_with_library();
        let now = Utc::now();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Active(ref active) = model.session_status {
            assert_eq!(active.current_index, 0);
            assert_eq!(active.entries.len(), 1);
            assert_eq!(active.session_started_at, now);
        } else {
            panic!("Expected Active state");
        }
    }

    // --- StartSession variation seeding tests (#1758) ---

    #[test]
    fn test_start_session_seeds_the_first_live_variation_when_no_plan_is_set() {
        let (mut model, entry_id) = model_with_exercise_building();
        let now = Utc::now();

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        let entry = session_entries(&model)
            .iter()
            .find(|e| e.id == entry_id)
            .expect("the entry is in the session");
        assert_eq!(play_of(entry).variation_id, Some("v-c".to_string()));
    }

    #[test]
    fn test_start_session_keeps_the_planned_variation_over_the_first_live_one() {
        let (mut model, entry_id) = model_with_exercise_building();
        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id: entry_id.clone(),
                variant_id: Some("v-f".to_string()),
            }),
        );
        let now = Utc::now();

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        let entry = session_entries(&model)
            .iter()
            .find(|e| e.id == entry_id)
            .expect("the entry is in the session");
        assert_eq!(play_of(entry).variation_id, Some("v-f".to_string()));
    }

    #[test]
    fn test_start_session_leaves_a_piece_unattributed() {
        let mut model = model_with_library();
        let now = Utc::now();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        let entry = &session_entries(&model)[0];
        assert_eq!(play_of(entry).variation_id, None);
    }

    #[test]
    fn test_start_session_leaves_an_all_tombstoned_ladder_unattributed() {
        let (mut model, entry_id) = model_with_exercise_building();
        model
            .items
            .iter_mut()
            .find(|i| i.id == "exercise-1")
            .unwrap()
            .variants
            .iter_mut()
            .for_each(|v| v.deleted_at = Some(Utc::now()));
        let now = Utc::now();

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        let entry = session_entries(&model)
            .iter()
            .find(|e| e.id == entry_id)
            .expect("the entry is in the session");
        assert_eq!(play_of(entry).variation_id, None);
    }

    #[test]
    fn test_next_item_seeds_the_first_live_variation_for_the_new_entry() {
        let mut model = model_with_library();
        give_exercise_a_ladder(&mut model);
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "exercise-1".to_string(),
            }),
        );
        let now = Utc::now();
        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::NextItem {
                now: now + chrono::Duration::seconds(30),
            }),
        );

        let entries = session_entries(&model);
        assert_eq!(play_of(&entries[1]).variation_id, Some("v-c".to_string()));
    }

    #[test]
    fn test_cancel_building() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(&mut model, Event::Session(SessionEvent::CancelBuilding));

        assert!(model.last_error.is_none());
        assert!(matches!(model.session_status, SessionStatus::Idle));
    }

    #[test]
    fn test_cancel_building_when_idle_is_noop_success() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::CancelBuilding));

        assert!(model.last_error.is_none());
        assert!(matches!(model.session_status, SessionStatus::Idle));
    }

    #[test]
    fn test_cancel_building_is_idempotent_when_called_twice() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(&mut model, Event::Session(SessionEvent::CancelBuilding));
        update(&mut model, Event::Session(SessionEvent::CancelBuilding));

        assert!(model.last_error.is_none());
        assert!(matches!(model.session_status, SessionStatus::Idle));
    }

    #[test]
    fn test_cancel_building_from_active_is_a_wrong_state_error() {
        // Cancelling the builder must not silently nuke an Active session (#944).
        let (mut model, _) = model_with_active_session(2);

        update(&mut model, Event::Session(SessionEvent::CancelBuilding));

        assert_eq!(model.last_error.as_deref(), Some("Not in building state"));
        assert!(matches!(model.session_status, SessionStatus::Active(_)));
    }

    // --- Active Phase Tests ---

    fn model_with_active_session(item_count: usize) -> (Model, DateTime<Utc>) {
        let mut model = model_with_library();
        let now = Utc::now();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));

        let items = ["piece-1", "piece-2", "exercise-1"];
        for item_id in items.iter().take(item_count.min(3)) {
            update(
                &mut model,
                Event::Session(SessionEvent::AddToSetlist {
                    item_id: (*item_id).to_string(),
                }),
            );
        }

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        (model, now)
    }

    #[test]
    fn test_next_item() {
        let (mut model, start) = model_with_active_session(3);
        let now = start + chrono::Duration::seconds(30);

        update(&mut model, Event::Session(SessionEvent::NextItem { now }));

        assert!(model.last_error.is_none());
        if let SessionStatus::Active(ref active) = model.session_status {
            assert_eq!(active.current_index, 1);
            assert_eq!(active.entries[0].duration_secs, 30);
            assert_eq!(active.entries[0].status, EntryStatus::Completed);
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_next_item_on_last_transitions_to_summary() {
        let (mut model, start) = model_with_active_session(1);
        let now = start + chrono::Duration::seconds(60);

        update(&mut model, Event::Session(SessionEvent::NextItem { now }));

        assert!(model.last_error.is_none());
        assert!(matches!(model.session_status, SessionStatus::Summary(_)));
    }

    #[test]
    fn test_finish_session() {
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(30);
        let t2 = t1 + chrono::Duration::seconds(45);

        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t2 }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref summary) = model.session_status {
            assert_eq!(summary.entries[0].duration_secs, 30);
            assert_eq!(summary.entries[1].duration_secs, 45);
            assert_eq!(summary.completion_status, CompletionStatus::Completed);
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_end_session_early() {
        let (mut model, start) = model_with_active_session(3);
        let t1 = start + chrono::Duration::seconds(30);
        let t2 = t1 + chrono::Duration::seconds(20);

        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::EndSessionEarly { now: t2 }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref summary) = model.session_status {
            assert_eq!(summary.entries[0].duration_secs, 30);
            assert_eq!(summary.entries[0].status, EntryStatus::Completed);
            assert_eq!(summary.entries[1].duration_secs, 20);
            assert_eq!(summary.entries[1].status, EntryStatus::Completed);
            assert_eq!(summary.entries[2].duration_secs, 0);
            assert_eq!(summary.entries[2].status, EntryStatus::NotAttempted);
            assert_eq!(summary.completion_status, CompletionStatus::EndedEarly);
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_skip_item() {
        let (mut model, start) = model_with_active_session(3);
        let now = start + chrono::Duration::seconds(10);

        update(&mut model, Event::Session(SessionEvent::SkipItem { now }));

        assert!(model.last_error.is_none());
        if let SessionStatus::Active(ref active) = model.session_status {
            assert_eq!(active.current_index, 1);
            assert_eq!(active.entries[0].duration_secs, 0);
            assert_eq!(active.entries[0].status, EntryStatus::Skipped);
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_skip_last_item_transitions_to_summary() {
        let (mut model, start) = model_with_active_session(1);
        let now = start + chrono::Duration::seconds(10);

        update(&mut model, Event::Session(SessionEvent::SkipItem { now }));

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref summary) = model.session_status {
            assert_eq!(summary.entries[0].status, EntryStatus::Skipped);
            assert_eq!(summary.entries[0].duration_secs, 0);
        } else {
            panic!("Expected Summary state");
        }
    }

    // --- Summary Phase Tests ---

    fn model_with_summary() -> Model {
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(30);
        let t2 = t1 + chrono::Duration::seconds(45);

        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t2 }),
        );
        model
    }

    #[test]
    fn test_update_entry_notes() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryNotes {
                entry_id,
                notes: Some("Needs more practice".to_string()),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(s.entries[0].notes, Some("Needs more practice".to_string()));
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_update_entry_notes_too_long() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryNotes {
                entry_id,
                notes: Some("x".repeat(5001)),
            }),
        );

        assert!(model.last_error.is_some());
    }

    #[test]
    fn test_update_session_notes() {
        let mut model = model_with_summary();

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateSessionNotes {
                notes: Some("Great practice today".to_string()),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(s.session_notes, Some("Great practice today".to_string()));
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_update_session_notes_rejected_outside_summary() {
        let (mut model, _start) = model_with_active_session(2);

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateSessionNotes {
                notes: Some("mid-session thought".to_string()),
            }),
        );

        assert_eq!(model.last_error, Some("Not in summary state".to_string()));
        let SessionStatus::Active(_) = model.session_status else {
            panic!("Active session must be untouched");
        };
    }

    #[test]
    fn test_save_session() {
        let mut model = model_with_summary();

        let now = Utc::now();
        update(
            &mut model,
            Event::Session(SessionEvent::SaveSession { now }),
        );

        assert!(model.last_error.is_none());
        assert!(matches!(model.session_status, SessionStatus::Idle));
        assert_eq!(model.sessions.len(), 1);
        assert_eq!(model.sessions[0].total_duration_secs, 75); // 30 + 45
        assert_eq!(
            model.sessions[0].completion_status,
            CompletionStatus::Completed
        );
    }

    #[test]
    fn save_session_persists_the_session_locally() {
        let mut model = model_with_summary();
        let app = Intrada;
        let mut cmd = app.update(
            Event::Session(SessionEvent::SaveSession { now: Utc::now() }),
            &mut model,
        );
        let id = model.sessions[0].id.clone();
        assert!(
            cmd.effects().any(|e| matches!(e, Effect::Persistence(req)
                if matches!(&req.operation, crate::persistence::PersistenceOperation::SaveSession(s) if s.id == id))),
            "the saved session reaches the on-device store"
        );
    }

    #[test]
    fn test_save_session_updates_practice_summaries_in_view() {
        // Regression test for #247: practice data must be visible in the
        // ViewModel immediately after SaveSession, without a re-fetch.
        let mut model = model_with_summary();

        // Score the first entry before saving
        if let SessionStatus::Summary(ref mut summary) = model.session_status {
            summary.entries[0]
                .open_play_mut()
                .expect("the practised entry has a play")
                .score = Some(4);
        }

        let now = Utc::now();
        update(
            &mut model,
            Event::Session(SessionEvent::SaveSession { now }),
        );

        // The model should have updated practice_summaries
        assert!(
            !model.practice_summaries.is_empty(),
            "practice_summaries should be populated after save"
        );

        // Build the view — this is what the shell sees
        let app = crate::app::Intrada;
        let vm = <crate::app::Intrada as crux_core::App>::view(&app, &model);

        // Find the item that was practised (piece-1)
        let practised_item = vm.items.iter().find(|i| i.id == "piece-1");
        assert!(
            practised_item.is_some(),
            "piece-1 should be in the ViewModel"
        );

        let practice = practised_item.unwrap().practice.as_ref();
        assert!(
            practice.is_some(),
            "piece-1 should have practice data after SaveSession"
        );

        let practice = practice.unwrap();
        assert_eq!(practice.session_count, 1);
        assert_eq!(practice.latest_score, Some(4));
    }

    #[test]
    fn test_discard_session() {
        let mut model = model_with_summary();

        update(&mut model, Event::Session(SessionEvent::DiscardSession));

        assert!(model.last_error.is_none());
        assert!(matches!(model.session_status, SessionStatus::Idle));
        assert!(model.sessions.is_empty());
    }

    // --- Recovery Tests ---

    #[test]
    fn test_recover_session() {
        let mut model = model_with_library();
        let now = Utc::now();

        let active = ActiveSession {
            id: "recovered-session".to_string(),
            entries: vec![create_entry(
                "piece-1",
                "Moonlight Sonata",
                ItemKind::Piece,
                0,
            )],
            current_index: 0,
            current_item_started_at: now,
            session_started_at: now,
        };

        update(
            &mut model,
            Event::Session(SessionEvent::RecoverSession {
                session: active,
                now,
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(a.id, "recovered-session");
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_recover_session_reanchors_current_item_timer() {
        let mut model = model_with_library();
        let started_yesterday = Utc::now() - chrono::Duration::hours(20);
        let now = Utc::now();

        let active = ActiveSession {
            id: "stale-session".to_string(),
            entries: vec![create_entry(
                "piece-1",
                "Moonlight Sonata",
                ItemKind::Piece,
                0,
            )],
            current_index: 0,
            current_item_started_at: started_yesterday,
            session_started_at: started_yesterday,
        };

        update(
            &mut model,
            Event::Session(SessionEvent::RecoverSession {
                session: active,
                now,
            }),
        );

        let SessionStatus::Active(ref a) = model.session_status else {
            panic!("Expected Active state");
        };
        assert_eq!(
            a.current_item_started_at, now,
            "resume must re-anchor the running item's timer, not show 20h elapsed"
        );
        assert_eq!(
            a.session_started_at, started_yesterday,
            "the session's historical start stays untouched"
        );
    }

    #[test]
    fn test_recover_session_when_not_idle() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));

        let now = Utc::now();
        let active = ActiveSession {
            id: "recovered".to_string(),
            entries: vec![],
            current_index: 0,
            current_item_started_at: now,
            session_started_at: now,
        };

        update(
            &mut model,
            Event::Session(SessionEvent::RecoverSession {
                session: active,
                now,
            }),
        );

        assert!(model.last_error.is_some());
    }

    // --- Edge Case Tests ---

    #[test]
    fn test_all_items_skipped() {
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(5);
        let t2 = t1 + chrono::Duration::seconds(5);

        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem { now: t1 }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem { now: t2 }),
        );

        assert!(matches!(model.session_status, SessionStatus::Summary(_)));

        let save_time = Utc::now();
        update(
            &mut model,
            Event::Session(SessionEvent::SaveSession { now: save_time }),
        );

        assert_eq!(model.sessions.len(), 1);
        assert_eq!(model.sessions[0].total_duration_secs, 0);
    }

    #[test]
    fn test_single_item_setlist() {
        let (mut model, start) = model_with_active_session(1);
        let now = start + chrono::Duration::seconds(120);

        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(s.entries.len(), 1);
            assert_eq!(s.entries[0].duration_secs, 120);
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_complete_lifecycle() {
        let mut model = model_with_library();
        let t0 = Utc::now();

        // 1. Start building
        update(&mut model, Event::Session(SessionEvent::StartBuilding));

        // 2. Add 3 items
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-2".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "exercise-1".to_string(),
            }),
        );

        // 3. Start session
        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now: t0 }),
        );

        // 4. Practice first item for 30s, then Next
        let t1 = t0 + chrono::Duration::seconds(30);
        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );

        // 5. Skip second item
        let t2 = t1 + chrono::Duration::seconds(5);
        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem { now: t2 }),
        );

        // 6. Finish on third item after 60s
        let t3 = t2 + chrono::Duration::seconds(60);
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t3 }),
        );

        // 7. Add notes
        let entry_id_0 = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary");
        };
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryNotes {
                entry_id: entry_id_0,
                notes: Some("Good tempo control".to_string()),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateSessionNotes {
                notes: Some("Focused session".to_string()),
            }),
        );

        // 8. Save
        let t_save = Utc::now();
        update(
            &mut model,
            Event::Session(SessionEvent::SaveSession { now: t_save }),
        );

        // Verify final state
        assert!(matches!(model.session_status, SessionStatus::Idle));
        assert_eq!(model.sessions.len(), 1);

        let session = &model.sessions[0];
        assert_eq!(session.entries.len(), 3);
        assert_eq!(session.entries[0].duration_secs, 30);
        assert_eq!(session.entries[0].status, EntryStatus::Completed);
        assert_eq!(
            session.entries[0].notes,
            Some("Good tempo control".to_string())
        );
        assert_eq!(session.entries[1].duration_secs, 0);
        assert_eq!(session.entries[1].status, EntryStatus::Skipped);
        assert_eq!(session.entries[2].duration_secs, 60);
        assert_eq!(session.entries[2].status, EntryStatus::Completed);
        assert_eq!(session.session_notes, Some("Focused session".to_string()));
        assert_eq!(session.total_duration_secs, 90); // 30 + 0 + 60
        assert_eq!(session.completion_status, CompletionStatus::Completed);
    }

    // --- UpdateEntryScore Tests ---

    #[test]
    fn test_update_entry_score_on_completed_entry() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(4),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).score, Some(4));
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_update_entry_score_toggle_clears_score() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        // Set score to 4
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(4),
            }),
        );

        // Clear score by setting to None (toggle)
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: None,
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).score, None);
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_update_entry_score_ignored_on_skipped_entry() {
        // Create a session where one item is skipped
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(5);
        let t2 = t1 + chrono::Duration::seconds(30);

        // Skip the first item
        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem { now: t1 }),
        );
        // Finish the second item
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t2 }),
        );

        let (skipped_entry_id, practised_entry_id) =
            if let SessionStatus::Summary(ref s) = model.session_status {
                assert_eq!(s.entries[0].status, EntryStatus::Skipped);
                (s.entries[0].id.clone(), s.entries[1].id.clone())
            } else {
                panic!("Expected Summary state");
            };

        // A skipped entry keeps no play of its own (#1739 decision 3), so the
        // only real id the sheet could send is one from the practised item.
        let play_id = first_play_id(&model, &practised_entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: skipped_entry_id.clone(),
                play_id,
                score: Some(3),
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(s.entries[0].score_summary(), None, "score not set");
            assert!(s.entries[0].plays.is_empty());
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_update_entry_score_out_of_range_rejected() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        // Score 0 — out of range
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(0),
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).score, None); // Score not set
        }

        // Score 11 — out of range
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(11),
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).score, None); // Score still not set
        }
    }

    #[test]
    fn test_update_entry_score_rejected_on_pending_entry() {
        // The current item (the one in progress) has status NotAttempted
        // until NextItem / SkipItem flips it. Scoring it would let the user
        // rate work they haven't done — invariant: only Completed entries
        // can be scored, regardless of session phase.
        let (mut model, _start) = model_with_active_session(2);

        let entry_id = if let SessionStatus::Active(ref a) = model.session_status {
            a.entries[0].id.clone()
        } else {
            panic!("Expected Active state");
        };

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(3),
            }),
        );

        // Score not set — entry is still NotAttempted
        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).score, None);
            assert_eq!(a.entries[0].status, EntryStatus::NotAttempted);
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_update_entry_score_works_mid_session_on_completed_entry() {
        // The mid-session reflection sheet's flow: NextItem flips the
        // just-completed entry to Completed, THEN the sheet dispatches
        // UpdateEntryScore for that entry. Session is still Active (we're
        // moving on to item 2, not finishing). The score should land.
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(45);

        // Advance — entry[0] becomes Completed, current_index moves to 1
        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );

        // Capture the just-completed entry id (still in Active phase)
        let entry_id = if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(a.entries[0].status, EntryStatus::Completed);
            assert_eq!(a.current_index, 1);
            a.entries[0].id.clone()
        } else {
            panic!("Expected Active state — only one of two items advanced");
        };

        // Score the just-completed entry mid-session
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(4),
            }),
        );

        // Score persisted, session still Active
        assert!(model.last_error.is_none());
        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).score, Some(4));
        } else {
            panic!("Expected Active state — session shouldn't have ended");
        }
    }

    #[test]
    fn test_mid_session_entry_score_survives_into_summary() {
        // A per-entry score set mid-session must still be present once the
        // session finishes and projects into the Summary — the reconciliation
        // the reflection hand-off (Phase 6) relies on.
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(45);
        let t2 = t1 + chrono::Duration::seconds(30);

        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );
        let entry_id = if let SessionStatus::Active(ref a) = model.session_status {
            a.entries[0].id.clone()
        } else {
            panic!("Expected Active state after advancing one of two items");
        };

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id,
                play_id,
                score: Some(4),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t2 }),
        );

        if let SessionStatus::Summary(ref summary) = model.session_status {
            assert_eq!(play_of(&summary.entries[0]).score, Some(4));
        } else {
            panic!("Expected Summary state after finishing the session");
        }
    }

    #[test]
    fn test_update_entry_tempo_works_mid_session_on_completed_entry() {
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(45);

        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );

        let entry_id = if let SessionStatus::Active(ref a) = model.session_status {
            a.entries[0].id.clone()
        } else {
            panic!("Expected Active state");
        };

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id,
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).achieved_tempo, Some(120));
        }
    }

    #[test]
    fn test_update_entry_notes_works_mid_session_on_completed_entry() {
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(45);

        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );

        let entry_id = if let SessionStatus::Active(ref a) = model.session_status {
            a.entries[0].id.clone()
        } else {
            panic!("Expected Active state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryNotes {
                entry_id,
                notes: Some("felt solid".to_string()),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(a.entries[0].notes.as_deref(), Some("felt solid"));
        }
    }

    #[test]
    fn test_update_entry_score_works_on_last_item_after_finish_session() {
        // The last-item path through the reflection sheet: NextItem to the
        // final item, FinishSession → transitions to Summary, then the sheet
        // dispatches UpdateEntryScore. `transition_to_summary` clones entries
        // into `summary.entries`, so the entry id must still resolve via
        // `entry_for_update_mut`. Pinning this so a future refactor of the
        // transition can't silently drop scoring on the last item.
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(45);
        let t2 = t1 + chrono::Duration::seconds(60);

        // Advance to the last item, then finish the session
        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: t1 }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t2 }),
        );

        // Should be in Summary phase now
        let last_entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(s.entries[1].status, EntryStatus::Completed);
            s.entries[1].id.clone()
        } else {
            panic!("Expected Summary state after FinishSession");
        };

        // Score the last item — same code path the reflection sheet takes
        let play_id = first_play_id(&model, &last_entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: last_entry_id,
                play_id,
                score: Some(5),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[1]).score, Some(5));
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_update_entry_score_unknown_entry_id_is_silent_noop() {
        // The sheet snapshots the entry id at open time. If the session is
        // cleared (recovery, new session) before Continue, the id won't
        // match anything in the new model. `entry_for_update_mut` returns
        // None — the dispatch must be silent (no last_error, no panic).
        let mut model = model_with_summary();
        let live_entry_id = match model.session_status {
            SessionStatus::Summary(ref s) => s.entries[0].id.clone(),
            _ => panic!("Expected Summary state"),
        };
        let play_id = first_play_id(&model, &live_entry_id);

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: "no-such-entry".to_string(),
                play_id: play_id.clone(),
                score: Some(3),
            }),
        );

        // Same shape for tempo
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: "no-such-entry".to_string(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        // Score and tempo handlers don't surface an error for unknown ids
        // (they're silent no-ops, matching the existing pattern).
        assert!(model.last_error.is_none());
    }

    #[test]
    fn test_update_entry_score_rejected_on_skipped_entry_in_active_phase() {
        // SkipItem produces EntryStatus::Skipped, not Completed. The
        // status gate in the handlers should reject scoring a skipped
        // entry mid-session, just as it does in the summary phase.
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(5);

        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem { now: t1 }),
        );

        let (skipped_entry_id, running_entry_id) =
            if let SessionStatus::Active(ref a) = model.session_status {
                assert_eq!(a.entries[0].status, EntryStatus::Skipped);
                assert_eq!(a.current_index, 1, "Should have advanced past skipped item");
                (a.entries[0].id.clone(), a.entries[1].id.clone())
            } else {
                panic!("Expected Active state: second item should still be running");
            };

        // A skipped entry keeps no play of its own (#1739 decision 3).
        let play_id = first_play_id(&model, &running_entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: skipped_entry_id,
                play_id,
                score: Some(3),
            }),
        );

        // Score not applied — entry is Skipped, not Completed
        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(a.entries[0].score_summary(), None);
            assert!(a.entries[0].plays.is_empty());
            assert_eq!(a.entries[0].status, EntryStatus::Skipped);
        }
    }

    #[test]
    fn test_update_entry_score_boundary_values() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        // Score 1 — minimum valid
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(1),
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).score, Some(1));
        }

        // Score 10 — maximum valid
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: entry_id.clone(),
                play_id,
                score: Some(10),
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).score, Some(10));
        }
    }

    // --- SetEntryVariant Tests (#1083 C1) ---

    fn give_exercise_a_ladder(model: &mut Model) -> (String, String) {
        let now = Utc::now();
        let ex = model
            .items
            .iter_mut()
            .find(|i| i.id == "exercise-1")
            .expect("fixture exercise");
        ex.variants = vec![
            crate::domain::variant::Variant {
                id: "v-c".to_string(),
                label: "C".to_string(),
                position: 0,
                updated_at: now,
                deleted_at: None,
            },
            crate::domain::variant::Variant {
                id: "v-f".to_string(),
                label: "F".to_string(),
                position: 1,
                updated_at: now,
                deleted_at: None,
            },
        ];
        ("v-c".to_string(), "v-f".to_string())
    }

    /// Building state whose single entry is the laddered exercise. Local-first,
    /// as on iOS; variations are gated to that mode (#1083).
    fn model_with_exercise_building() -> (Model, String) {
        let mut model = model_with_library();
        give_exercise_a_ladder(&mut model);
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "exercise-1".to_string(),
            }),
        );
        let entry_id = building_entries(&model)[0].id.clone();
        (model, entry_id)
    }

    /// The same setlist carried through to Summary.
    fn model_with_exercise_summary() -> (Model, String) {
        let (mut model, _) = model_with_exercise_building();
        let now = Utc::now();
        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: now + chrono::Duration::seconds(60),
            }),
        );
        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };
        (model, entry_id)
    }

    fn planned_variation(model: &Model) -> Option<String> {
        session_entries(model)[0].planned_variation_id.clone()
    }

    /// Planning a variation is a Building-phase move (#1739 decision 5): once
    /// the entry has been practised the record is its plays, and
    /// `SwitchVariation` is what changes them.
    #[test]
    fn set_entry_variant_is_rejected_on_a_completed_entry() {
        let (mut model, entry_id) = model_with_exercise_summary();

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id,
                variant_id: Some("v-c".to_string()),
            }),
        );

        assert!(model.last_error.is_some(), "surfaced, not silent");
        assert_eq!(planned_variation(&model), None);
    }

    #[test]
    fn set_entry_variant_rejects_a_variant_of_another_item() {
        let (mut model, entry_id) = model_with_exercise_building();
        // A ladder on a different exercise.
        let now = Utc::now();
        model.items.push(Item {
            id: "exercise-2".to_string(),
            title: "Arpeggios".to_string(),
            kind: ItemKind::Exercise,
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
            variants: vec![crate::domain::variant::Variant {
                id: "v-other".to_string(),
                label: "C".to_string(),
                position: 0,
                updated_at: now,
                deleted_at: None,
            }],
            photo_id: None,
            metre: None,
        });

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id,
                variant_id: Some("v-other".to_string()),
            }),
        );

        assert!(model.last_error.is_some());
        assert_eq!(planned_variation(&model), None);
    }

    #[test]
    fn set_entry_variant_rejects_a_tombstoned_variant() {
        let (mut model, entry_id) = model_with_exercise_building();
        model
            .items
            .iter_mut()
            .find(|i| i.id == "exercise-1")
            .unwrap()
            .variants
            .iter_mut()
            .find(|v| v.id == "v-f")
            .unwrap()
            .deleted_at = Some(Utc::now());

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id,
                variant_id: Some("v-f".to_string()),
            }),
        );

        assert!(model.last_error.is_some());
        assert_eq!(planned_variation(&model), None);
    }

    #[test]
    fn a_skipped_entry_keeps_the_variation_it_was_planned_for() {
        // The plan outlives the skip: the entry still says which variation it
        // was meant to practise. It records no play, so it contributes nothing
        // to per-variation history and the stats stay clean.
        let mut model = model_with_library();
        give_exercise_a_ladder(&mut model);
        let now = Utc::now();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        for id in ["exercise-1", "piece-1"] {
            update(
                &mut model,
                Event::Session(SessionEvent::AddToSetlist {
                    item_id: id.to_string(),
                }),
            );
        }

        let entry_id = building_entries(&model)[0].id.clone();
        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id,
                variant_id: Some("v-c".to_string()),
            }),
        );
        assert!(model.last_error.is_none());

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem {
                now: now + chrono::Duration::seconds(5),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: now + chrono::Duration::seconds(60),
            }),
        );

        let SessionStatus::Summary(ref s) = model.session_status else {
            panic!("Expected Summary state");
        };
        assert_eq!(
            s.entries[0].status,
            EntryStatus::Skipped,
            "fixture: exercise was skipped"
        );
        assert_eq!(
            s.entries[0].planned_variation_id.as_deref(),
            Some("v-c"),
            "the plan survives a skip"
        );
        assert!(
            s.entries[0].plays.is_empty(),
            "a skipped entry records no play, so it scores no variation"
        );
    }

    #[test]
    fn set_entry_variant_flows_into_the_saved_session() {
        let (mut model, entry_id) = model_with_exercise_building();
        let now = Utc::now();
        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id,
                variant_id: Some("v-c".to_string()),
            }),
        );

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: now + chrono::Duration::seconds(60),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::SaveSession {
                now: now + chrono::Duration::seconds(65),
            }),
        );

        assert_eq!(model.sessions.len(), 1);
        let saved = &model.sessions[0].entries[0];
        assert_eq!(
            saved.planned_variation_id.as_deref(),
            Some("v-c"),
            "the chosen variation rides the persisted session"
        );
        assert_eq!(
            play_of(saved).variation_id.as_deref(),
            Some("v-c"),
            "the first play is seeded from the plan, so the record names it too"
        );
    }

    #[test]
    fn set_entry_variant_unknown_entry_surfaces_an_error() {
        let (mut model, _) = model_with_exercise_building();

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id: "no-such-entry".to_string(),
                variant_id: Some("v-c".to_string()),
            }),
        );

        assert!(model.last_error.is_some());
    }

    // --- UpdateEntryTempo Tests ---

    // --- Tempo evidence (#1420, roadmap Q3) ---

    fn tempo_entry_id(model: &Model) -> String {
        match model.session_status {
            SessionStatus::Summary(ref s) => s.entries[0].id.clone(),
            _ => panic!("Expected Summary state"),
        }
    }

    fn achieved_tempo(model: &Model, entry_id: &str) -> Option<u16> {
        match model.session_status {
            SessionStatus::Summary(ref s) => {
                let entry = s.entries.iter().find(|e| e.id == entry_id).unwrap();
                // Without this the negative tests would also pass against a
                // skipped entry, which the handler rejects for another reason.
                assert_eq!(entry.status, EntryStatus::Completed);
                play_of(entry).achieved_tempo
            }
            _ => panic!("Expected Summary state"),
        }
    }

    fn seven_eight_on_group_starts() -> ClickState {
        ClickState {
            metre: Metre {
                beats: 7,
                unit: 8,
                groups: Some(vec![3, 2, 2]),
            },
            sounding: 0b0101001,
        }
    }

    fn click_pattern(model: &Model, entry_id: &str) -> Option<ClickState> {
        match model.session_status {
            SessionStatus::Summary(ref s) => {
                let entry = s.entries.iter().find(|e| e.id == entry_id).unwrap();
                play_of(entry).click_pattern.clone()
            }
            _ => panic!("Expected Summary state"),
        }
    }

    /// The row read `♪ = 168` in 7/8; the trend must see 84 crotchets, and the
    /// pattern that earned it rides alongside (#1499, spec questions 2 and 3).
    #[test]
    fn a_quaver_tempo_is_stored_as_crotchets_with_its_click_pattern() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(168),
                observed: TempoObservation {
                    user_set: false,
                    click_sounding: true,
                },
                click: Some(seven_eight_on_group_starts()),
            }),
        );

        assert_eq!(achieved_tempo(&model, &entry_id), Some(84));
        assert_eq!(
            click_pattern(&model, &entry_id),
            Some(seven_eight_on_group_starts())
        );
    }

    /// A sparse pattern never divides the bpm: the click on beat 4 at 120 is
    /// still 120 (T19).
    #[test]
    fn a_sparse_pattern_leaves_a_crotchet_tempo_alone() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: false,
                    click_sounding: true,
                },
                click: Some(ClickState {
                    metre: Metre::default(),
                    sounding: 0b1000,
                }),
            }),
        );

        assert_eq!(achieved_tempo(&model, &entry_id), Some(120));
    }

    /// A silent click is not evidence of a pattern, even when the user set the
    /// number themselves; the unit still names what the row displayed.
    #[test]
    fn a_silent_click_normalises_the_unit_but_records_no_pattern() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(169),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: Some(seven_eight_on_group_starts()),
            }),
        );

        assert_eq!(achieved_tempo(&model, &entry_id), Some(85));
        assert_eq!(click_pattern(&model, &entry_id), None);
    }

    #[test]
    fn clearing_the_tempo_clears_the_pattern_with_it() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);
        let sounding = TempoObservation {
            user_set: false,
            click_sounding: true,
        };
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(168),
                observed: sounding,
                click: Some(seven_eight_on_group_starts()),
            }),
        );
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: None,
                observed: sounding,
                click: Some(seven_eight_on_group_starts()),
            }),
        );

        assert_eq!(achieved_tempo(&model, &entry_id), None);
        assert_eq!(click_pattern(&model, &entry_id), None);
    }

    #[test]
    fn a_click_that_sounds_no_beat_is_rejected_and_writes_nothing() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: false,
                    click_sounding: true,
                },
                click: Some(ClickState {
                    metre: Metre::default(),
                    sounding: 0,
                }),
            }),
        );

        assert!(model.last_error.is_some());
        assert_eq!(achieved_tempo(&model, &entry_id), None);
    }

    #[test]
    fn tempo_the_user_set_themselves_is_recorded() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        assert_eq!(achieved_tempo(&model, &entry_id), Some(120));
    }

    #[test]
    fn tempo_played_to_a_sounding_click_is_recorded() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: false,
                    click_sounding: true,
                },
                click: None,
            }),
        );

        assert_eq!(achieved_tempo(&model, &entry_id), Some(120));
    }

    #[test]
    fn an_untouched_default_is_not_recorded() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(96),
                observed: TempoObservation {
                    user_set: false,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        assert_eq!(
            achieved_tempo(&model, &entry_id),
            None,
            "a pre-fill nobody looked at is not a measurement"
        );
    }

    #[test]
    fn an_untouched_default_does_not_erase_a_measured_tempo() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(96),
                observed: TempoObservation {
                    user_set: false,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        assert_eq!(
            achieved_tempo(&model, &entry_id),
            Some(120),
            "a report that is not a measurement must not destroy one that was"
        );
    }

    #[test]
    fn clearing_the_tempo_needs_no_evidence() {
        let mut model = model_with_summary();
        let entry_id = tempo_entry_id(&model);

        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: None,
                observed: TempoObservation {
                    user_set: false,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        assert_eq!(achieved_tempo(&model, &entry_id), None);
    }

    #[test]
    fn update_entry_tempo_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(Event::Session(SessionEvent::UpdateEntryTempo {
            entry_id: "entry-1".to_string(),
            play_id: "play-1".to_string(),
            tempo: Some(132),
            observed: TempoObservation {
                user_set: true,
                click_sounding: true,
            },
            click: None,
        }));
    }

    #[test]
    fn test_update_entry_tempo_none_clears() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        // Set tempo to 120
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        // Clear tempo by setting to None
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: None,
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).achieved_tempo, None);
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_update_entry_tempo_rejected_on_skipped() {
        // Build a summary with a skipped entry: skip item 1, complete item 2
        let (mut model, start) = model_with_active_session(2);
        let t1 = start + chrono::Duration::seconds(10);
        let t2 = t1 + chrono::Duration::seconds(30);

        // Skip first item
        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem { now: t1 }),
        );
        // Finish session (completes second item, transitions to summary)
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t2 }),
        );

        // Find the skipped entry
        let (skipped_entry_id, practised_entry_id) =
            if let SessionStatus::Summary(ref s) = model.session_status {
                let skipped = s
                    .entries
                    .iter()
                    .find(|e| e.status == EntryStatus::Skipped)
                    .expect("Should have a skipped entry");
                let practised = s
                    .entries
                    .iter()
                    .find(|e| e.status == EntryStatus::Completed)
                    .expect("Should have a completed entry");
                (skipped.id.clone(), practised.id.clone())
            } else {
                panic!("Expected Summary state");
            };

        // A skipped entry keeps no play of its own (#1739 decision 3), so the
        // sheet can only ever send a play id from the practised item.
        let play_id = first_play_id(&model, &practised_entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: skipped_entry_id.clone(),
                play_id,
                tempo: Some(100),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            let skipped = s.entries.iter().find(|e| e.id == skipped_entry_id).unwrap();
            assert!(skipped.plays.is_empty(), "no play means no tempo recorded");
        }
    }

    #[test]
    fn test_update_entry_tempo_rejected_out_of_range() {
        let mut model = model_with_summary();

        let entry_id = if let SessionStatus::Summary(ref s) = model.session_status {
            s.entries[0].id.clone()
        } else {
            panic!("Expected Summary state");
        };

        // Tempo 0 — out of range
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(0),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).achieved_tempo, None);
        }

        // Tempo 501 — out of range
        let play_id = first_play_id(&model, &entry_id);
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryTempo {
                entry_id: entry_id.clone(),
                play_id,
                tempo: Some(501),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).achieved_tempo, None);
        }
    }

    // --- format_duration_display Tests ---

    #[test]
    fn test_format_duration_seconds_only() {
        assert_eq!(format_duration_display(0), "0s");
        assert_eq!(format_duration_display(45), "45s");
        assert_eq!(format_duration_display(59), "59s");
    }

    #[test]
    fn test_format_duration_minutes_and_seconds() {
        assert_eq!(format_duration_display(60), "1m 0s");
        assert_eq!(format_duration_display(90), "1m 30s");
        assert_eq!(format_duration_display(3599), "59m 59s");
    }

    #[test]
    fn test_format_duration_hours() {
        assert_eq!(format_duration_display(3600), "1h 0m 0s");
        assert_eq!(format_duration_display(3661), "1h 1m 1s");
        assert_eq!(format_duration_display(7200), "2h 0m 0s");
    }

    // --- format_duration_summary Tests ---

    #[test]
    fn test_format_duration_summary() {
        assert_eq!(format_duration_summary(0), "0m");
        assert_eq!(format_duration_summary(45), "0m");
        assert_eq!(format_duration_summary(1800), "30m");
        assert_eq!(format_duration_summary(2700), "45m");
        assert_eq!(format_duration_summary(3600), "1h 0m");
        assert_eq!(format_duration_summary(8100), "2h 15m");
    }

    // --- SessionsData Serialization Test ---

    #[test]
    fn test_sessions_data_serialization() {
        use crate::domain::types::SessionsData;

        let data = SessionsData { sessions: vec![] };
        let json = serde_json::to_string(&data).unwrap();
        let parsed: SessionsData = serde_json::from_str(&json).unwrap();
        assert!(parsed.sessions.is_empty());
    }

    // --- Intention Tests ---

    #[test]
    fn test_set_entry_intention() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            b.entries[0].id.clone()
        } else {
            panic!("Expected Building state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryIntention {
                entry_id,
                intention: Some("Work on left hand".to_string()),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(
                b.entries[0].intention,
                Some("Work on left hand".to_string())
            );
        } else {
            panic!("Expected Building state");
        }
    }

    #[test]
    fn test_set_entry_variant_tags_the_rung_while_building() {
        let mut model = model_with_library();
        give_exercise_a_ladder(&mut model);
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "exercise-1".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(
                b.entries[0].planned_variation_id, None,
                "entries start with no rung"
            );
            b.entries[0].id.clone()
        } else {
            panic!("Expected Building state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id: entry_id.clone(),
                variant_id: Some("v-c".to_string()),
            }),
        );
        assert!(model.last_error.is_none());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(b.entries[0].planned_variation_id, Some("v-c".to_string()));
        } else {
            panic!("Expected Building state");
        }

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id,
                variant_id: None,
            }),
        );
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(
                b.entries[0].planned_variation_id, None,
                "None clears the rung"
            );
        } else {
            panic!("Expected Building state");
        }
    }

    #[test]
    fn test_set_entry_variant_unknown_entry_surfaces_error() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id: "nope".to_string(),
                variant_id: Some("var-1".to_string()),
            }),
        );
        assert!(model.last_error.is_some());
    }

    // --- Rep Counter Tests ---

    const TAP_AT: &str = "2026-09-03T09:00:00Z";

    fn tap_at() -> DateTime<Utc> {
        TAP_AT.parse().expect("fixed timestamp")
    }

    fn got_it() -> Event {
        Event::Session(SessionEvent::RepGotIt { now: tap_at() })
    }

    fn missed() -> Event {
        Event::Session(SessionEvent::RepMissed { now: tap_at() })
    }

    fn actions(entry: &SetlistEntry) -> Option<Vec<RepAction>> {
        play_of(entry)
            .rep_history
            .as_ref()
            .map(|h| h.iter().map(|e| e.action).collect())
    }

    fn active_entry(model: &Model, index: usize) -> &SetlistEntry {
        let SessionStatus::Active(ref a) = model.session_status else {
            panic!("Expected Active state");
        };
        &a.entries[index]
    }

    /// Helper: create an active session with a rep target on the first item.
    fn model_with_active_session_and_rep(target: u8) -> (Model, DateTime<Utc>) {
        let mut model = model_with_library();
        let now = Utc::now();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-2".to_string(),
            }),
        );

        // Set rep target on first entry during building
        if let SessionStatus::Building(ref mut b) = model.session_status {
            b.entries[0].planned_rep_target = Some(target);
        } else {
            panic!("Expected Building state");
        }

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        (model, now)
    }

    /// An untouched counter records nothing (T19): a builder target alone must
    /// not bank a zero and an empty history on session start.
    #[test]
    fn test_start_session_does_not_bank_rep_state() {
        let (model, _now) = model_with_active_session_and_rep(5);

        let targeted = active_entry(&model, 0);
        assert_eq!(play_of(targeted).rep_target, Some(5));
        assert_eq!(play_of(targeted).rep_count, None);
        assert_eq!(play_of(targeted).rep_target_reached, None);
        assert_eq!(play_of(targeted).rep_history, None);

        let untouched = active_entry(&model, 1);
        assert!(
            untouched.plays.is_empty(),
            "an item not yet reached has opened no play, so it banks nothing"
        );
    }

    #[test]
    fn test_rep_got_it_increments() {
        let (mut model, _now) = model_with_active_session_and_rep(5);

        update(&mut model, got_it());
        update(&mut model, got_it());
        update(&mut model, got_it());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(3));
            assert_eq!(play_of(&a.entries[0]).rep_target_reached, Some(false));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_got_it_reaches_target() {
        let (mut model, _now) = model_with_active_session_and_rep(3);

        update(&mut model, got_it());
        update(&mut model, got_it());
        update(&mut model, got_it());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(3));
            assert_eq!(play_of(&a.entries[0]).rep_target_reached, Some(true));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_got_it_frozen_after_target_reached() {
        let (mut model, _now) = model_with_active_session_and_rep(3);

        // Reach target
        for _ in 0..3 {
            update(&mut model, got_it());
        }

        // Additional got-it should not increase count
        update(&mut model, got_it());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(3));
            assert_eq!(play_of(&a.entries[0]).rep_target_reached, Some(true));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_missed_decrements() {
        let (mut model, _now) = model_with_active_session_and_rep(5);

        update(&mut model, got_it());
        update(&mut model, got_it());
        update(&mut model, got_it());

        update(&mut model, missed());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(2));
            assert_eq!(play_of(&a.entries[0]).rep_target_reached, Some(false));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_missed_floor_zero() {
        let (mut model, _now) = model_with_active_session_and_rep(5);

        // Miss with count at 0
        update(&mut model, missed());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(0));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_missed_frozen_after_target_reached() {
        let (mut model, _now) = model_with_active_session_and_rep(3);

        // Reach target
        for _ in 0..3 {
            update(&mut model, got_it());
        }

        // Miss should not decrement after target reached
        update(&mut model, missed());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(3));
            assert_eq!(play_of(&a.entries[0]).rep_target_reached, Some(true));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_first_got_it_on_untouched_entry_writes_all_four_fields() {
        let (mut model, _now) = model_with_active_session(2);
        assert_eq!(play_of(active_entry(&model, 0)).rep_target, None);

        update(&mut model, got_it());

        let entry = active_entry(&model, 0);
        assert_eq!(
            play_of(entry).rep_target,
            Some(validation::DEFAULT_REP_TARGET)
        );
        assert_eq!(play_of(entry).rep_count, Some(1));
        assert_eq!(play_of(entry).rep_target_reached, Some(false));
        assert_eq!(
            play_of(entry).rep_history,
            Some(vec![RepEvent {
                action: RepAction::Success,
                at: tap_at()
            }])
        );
    }

    #[test]
    fn test_first_missed_on_untouched_entry_records_the_miss_at_zero() {
        let (mut model, _now) = model_with_active_session(2);

        update(&mut model, missed());

        let entry = active_entry(&model, 0);
        assert_eq!(
            play_of(entry).rep_target,
            Some(validation::DEFAULT_REP_TARGET)
        );
        assert_eq!(play_of(entry).rep_count, Some(0));
        assert_eq!(play_of(entry).rep_target_reached, Some(false));
        assert_eq!(actions(entry), Some(vec![RepAction::Missed]));
    }

    #[test]
    fn test_first_tap_keeps_a_builder_target() {
        let (mut model, _now) = model_with_active_session_and_rep(7);

        update(&mut model, got_it());

        let entry = active_entry(&model, 0);
        assert_eq!(play_of(entry).rep_target, Some(7));
        assert_eq!(play_of(entry).rep_count, Some(1));
    }

    #[test]
    fn test_rep_history_carries_each_taps_time_in_order() {
        let (mut model, _now) = model_with_active_session(2);
        let first = tap_at();
        let second = first + chrono::Duration::seconds(40);
        let third = second + chrono::Duration::seconds(55);

        update(
            &mut model,
            Event::Session(SessionEvent::RepGotIt { now: first }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::RepMissed { now: second }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::RepGotIt { now: third }),
        );

        assert_eq!(
            play_of(active_entry(&model, 0)).rep_history,
            Some(vec![
                RepEvent {
                    action: RepAction::Success,
                    at: first
                },
                RepEvent {
                    action: RepAction::Missed,
                    at: second
                },
                RepEvent {
                    action: RepAction::Success,
                    at: third
                },
            ])
        );
    }

    #[test]
    fn test_rep_state_frozen_on_next_item() {
        let (mut model, start) = model_with_active_session_and_rep(5);

        // Got-it 3 times (partial progress)
        update(&mut model, got_it());
        update(&mut model, got_it());
        update(&mut model, got_it());

        let now = start + chrono::Duration::seconds(30);
        update(&mut model, Event::Session(SessionEvent::NextItem { now }));

        if let SessionStatus::Active(ref a) = model.session_status {
            // First entry frozen: 3/5, target not reached
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(3));
            assert_eq!(play_of(&a.entries[0]).rep_target_reached, Some(false));
            // Now on second item
            assert_eq!(a.current_index, 1);
        } else {
            panic!("Expected Active state");
        }
    }

    /// Repetitions banked before a skip are a record of practice and survive
    /// it, frozen, as they did before plays existed. What a skip discards is
    /// the play that recorded nothing (#1739 decision 3).
    #[test]
    fn test_rep_state_frozen_on_skip_item() {
        let (mut model, start) = model_with_active_session_and_rep(5);

        // Got-it once
        update(&mut model, got_it());

        let now = start + chrono::Duration::seconds(10);
        update(&mut model, Event::Session(SessionEvent::SkipItem { now }));

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(a.entries[0].status, EntryStatus::Skipped);
            assert_eq!(a.entries[0].plays.len(), 1);
            assert_eq!(a.entries[0].plays[0].rep_count, Some(1));
            assert_eq!(a.entries[0].plays[0].rep_target, Some(5));
            assert_eq!(a.entries[0].plays[0].rep_target_reached, Some(false));
            assert_eq!(a.entries[0].planned_rep_target, Some(5));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_state_in_summary_after_finish() {
        let (mut model, start) = model_with_active_session_and_rep(3);

        // Reach target
        for _ in 0..3 {
            update(&mut model, got_it());
        }

        let now = start + chrono::Duration::seconds(60);
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(play_of(&s.entries[0]).rep_target, Some(3));
            assert_eq!(play_of(&s.entries[0]).rep_count, Some(3));
            assert_eq!(play_of(&s.entries[0]).rep_target_reached, Some(true));
        } else {
            panic!("Expected Summary state");
        }
    }

    #[test]
    fn test_rep_state_persisted_through_save() {
        let (mut model, start) = model_with_active_session_and_rep(3);

        // Reach target
        for _ in 0..3 {
            update(&mut model, got_it());
        }

        let t1 = start + chrono::Duration::seconds(60);
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: t1 }),
        );

        let t2 = t1 + chrono::Duration::seconds(5);
        update(
            &mut model,
            Event::Session(SessionEvent::SaveSession { now: t2 }),
        );

        assert_eq!(model.sessions.len(), 1);
        assert_eq!(play_of(&model.sessions[0].entries[0]).rep_target, Some(3));
        assert_eq!(play_of(&model.sessions[0].entries[0]).rep_count, Some(3));
        assert_eq!(
            play_of(&model.sessions[0].entries[0]).rep_target_reached,
            Some(true)
        );
    }

    #[test]
    fn test_a_tap_touches_only_the_current_entry() {
        let (mut model, _now) = model_with_active_session(2);

        update(&mut model, got_it());

        let other = active_entry(&model, 1);
        assert!(
            other.plays.is_empty(),
            "the tap opened no play on an item that is not current"
        );
    }

    #[test]
    fn test_rep_got_it_capped_at_target() {
        let (mut model, _now) = model_with_active_session_and_rep(3);

        // Try to go beyond target
        for _ in 0..10 {
            update(&mut model, got_it());
        }

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_count, Some(3)); // capped at target
            assert_eq!(play_of(&a.entries[0]).rep_target_reached, Some(true));
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_state_frozen_on_end_session_early() {
        let (mut model, now) = model_with_active_session_and_rep(5);

        // Increment rep count twice on item 1
        update(&mut model, got_it());
        update(&mut model, got_it());

        // End session early (item 2 is never reached)
        let t1 = now + chrono::Duration::seconds(30);
        update(
            &mut model,
            Event::Session(SessionEvent::EndSessionEarly { now: t1 }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            // Item 1: rep state frozen — 2/5, not reached
            assert_eq!(play_of(&s.entries[0]).rep_target, Some(5));
            assert_eq!(play_of(&s.entries[0]).rep_count, Some(2));
            assert_eq!(play_of(&s.entries[0]).rep_target_reached, Some(false));
            assert_eq!(s.entries[0].status, EntryStatus::Completed);

            // Item 2: never reached, so it records nothing at all
            assert!(s.entries[1].plays.is_empty());
            assert_eq!(s.entries[1].status, EntryStatus::NotAttempted);
        } else {
            panic!("Expected Summary state");
        }
    }

    // ── SetRepTarget (Building phase) tests ──────────────────────────

    #[test]
    fn test_set_rep_target_in_building() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            b.entries[0].id.clone()
        } else {
            panic!("Expected Building state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::SetRepTarget {
                entry_id: entry_id.clone(),
                target: Some(7),
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(b.entries[0].planned_rep_target, Some(7));
            assert!(
                b.entries[0].plays.is_empty(),
                "a target is a plan: it banks no progress"
            );
        } else {
            panic!("Expected Building state");
        }
    }

    #[test]
    fn test_set_rep_target_clear() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            b.entries[0].id.clone()
        } else {
            panic!("Expected Building state");
        };

        // Set target first
        update(
            &mut model,
            Event::Session(SessionEvent::SetRepTarget {
                entry_id: entry_id.clone(),
                target: Some(5),
            }),
        );

        // Then clear it
        update(
            &mut model,
            Event::Session(SessionEvent::SetRepTarget {
                entry_id,
                target: None,
            }),
        );

        assert!(model.last_error.is_none());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(b.entries[0].planned_rep_target, None);
        } else {
            panic!("Expected Building state");
        }
    }

    #[test]
    fn test_set_rep_target_invalid_value() {
        let mut model = model_with_library();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            b.entries[0].id.clone()
        } else {
            panic!("Expected Building state");
        };

        // Target below minimum (3)
        update(
            &mut model,
            Event::Session(SessionEvent::SetRepTarget {
                entry_id: entry_id.clone(),
                target: Some(1),
            }),
        );

        assert!(model.last_error.is_some());
        if let SessionStatus::Building(ref b) = model.session_status {
            assert_eq!(b.entries[0].planned_rep_target, None); // unchanged
        } else {
            panic!("Expected Building state");
        }

        // Target above maximum (10)
        model.last_error = None;
        update(
            &mut model,
            Event::Session(SessionEvent::SetRepTarget {
                entry_id,
                target: Some(15),
            }),
        );

        assert!(model.last_error.is_some());
    }

    #[test]
    fn test_set_rep_target_flows_to_active() {
        let mut model = model_with_library();
        let now = Utc::now();
        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "piece-1".to_string(),
            }),
        );

        let entry_id = if let SessionStatus::Building(ref b) = model.session_status {
            b.entries[0].id.clone()
        } else {
            panic!("Expected Building state");
        };

        update(
            &mut model,
            Event::Session(SessionEvent::SetRepTarget {
                entry_id,
                target: Some(8),
            }),
        );

        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        let entry = active_entry(&model, 0);
        assert_eq!(play_of(entry).rep_target, Some(8));
        assert_eq!(
            play_of(entry).rep_count,
            None,
            "nothing is banked before the first tap"
        );
        assert_eq!(play_of(entry).rep_target_reached, None);
    }

    #[test]
    fn test_set_rep_target_no_op_outside_building() {
        let (mut model, _now) = model_with_active_session_and_rep(5);

        // SetRepTarget should no-op in Active state
        update(
            &mut model,
            Event::Session(SessionEvent::SetRepTarget {
                entry_id: "whatever".to_string(),
                target: Some(10),
            }),
        );

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(play_of(&a.entries[0]).rep_target, Some(5)); // unchanged
        } else {
            panic!("Expected Active state");
        }
    }

    // --- Rep History Tests (US1) ---

    #[test]
    fn test_rep_history_appended_on_got_it() {
        let (mut model, _now) = model_with_active_session_and_rep(5);

        update(&mut model, got_it());
        update(&mut model, got_it());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(
                actions(&a.entries[0]),
                Some(vec![RepAction::Success, RepAction::Success])
            );
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_history_appended_on_missed() {
        let (mut model, _now) = model_with_active_session_and_rep(5);

        update(&mut model, got_it());
        update(&mut model, missed());

        if let SessionStatus::Active(ref a) = model.session_status {
            assert_eq!(
                actions(&a.entries[0]),
                Some(vec![RepAction::Success, RepAction::Missed])
            );
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_rep_history_frozen_on_next_item() {
        let (mut model, start) = model_with_active_session_and_rep(5);

        // Record some actions
        update(&mut model, got_it());
        update(&mut model, missed());
        update(&mut model, got_it());

        // Move to next item
        let next_time = start + chrono::Duration::seconds(60);
        update(
            &mut model,
            Event::Session(SessionEvent::NextItem { now: next_time }),
        );

        if let SessionStatus::Active(ref a) = model.session_status {
            // First entry's history should be frozen with the recorded actions
            assert_eq!(
                actions(&a.entries[0]),
                Some(vec![
                    RepAction::Success,
                    RepAction::Missed,
                    RepAction::Success
                ])
            );
        } else {
            panic!("Expected Active state");
        }
    }

    #[test]
    fn test_update_session_score_sets_and_validates() {
        let mut model = model_with_summary();

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateSessionScore { score: Some(8) }),
        );
        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(s.session_score, Some(8));
        } else {
            panic!("Expected Summary state");
        }

        // Out of range is rejected, leaving the prior value intact.
        update(
            &mut model,
            Event::Session(SessionEvent::UpdateSessionScore { score: Some(11) }),
        );
        assert!(model.last_error.is_none());
        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(s.session_score, Some(8));
        }
    }

    #[test]
    fn test_rep_history_persisted_through_save() {
        let (mut model, start) = model_with_active_session_and_rep(3);

        // Hit got it 3 times to reach target
        update(&mut model, got_it());
        update(&mut model, got_it());
        update(&mut model, got_it());

        // Finish session
        let end_time = start + chrono::Duration::seconds(120);
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession { now: end_time }),
        );

        if let SessionStatus::Summary(ref s) = model.session_status {
            assert_eq!(
                actions(&s.entries[0]),
                Some(vec![
                    RepAction::Success,
                    RepAction::Success,
                    RepAction::Success
                ])
            );
        } else {
            panic!("Expected Summary state");
        }
    }

    /// `group_id` rides `SetlistEntry` across the bincode FFI wire (in the
    /// persisted `PracticeSession` and the ViewModel). It is the sole input to
    /// the B1 context derivation, so a silent drop on the wire would erase every
    /// piece context. Guard the whole entry, with `group_id` set, against the
    /// #846 class.
    #[test]
    fn setlist_entry_with_group_id_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(SetlistEntry {
            id: "e1".to_string(),
            item_id: "ex-1".to_string(),
            item_title: "Scales".to_string(),
            item_type: ItemKind::Exercise,
            position: 0,
            duration_secs: 300,
            status: EntryStatus::Completed,
            notes: Some("warm up".to_string()),
            intention: Some("even tone".to_string()),
            planned_duration_secs: Some(300),
            group_id: Some("g1".to_string()),
            planned_variation_id: Some("v-1".to_string()),
            planned_rep_target: Some(5),
            plays: vec![VariationPlay {
                id: "e1-play".to_string(),
                variation_id: Some("v-1".to_string()),
                started_at: tap_at(),
                seconds: 300,
                rep_target: Some(5),
                rep_count: Some(5),
                rep_target_reached: Some(true),
                rep_history: Some(vec![
                    RepEvent {
                        action: RepAction::Success,
                        at: tap_at(),
                    },
                    RepEvent {
                        action: RepAction::Missed,
                        at: tap_at(),
                    },
                ]),
                achieved_tempo: Some(96),
                click_pattern: None,
                score: Some(6),
            }],
        });
    }

    fn pinned_active_session() -> ActiveSession {
        let started: DateTime<Utc> = "2026-09-03T08:47:00Z".parse().expect("fixed");
        let mut touched = create_entry("p1", "Clair de Lune", ItemKind::Piece, 0);
        touched.id = "e1".to_string();
        touched.status = EntryStatus::Completed;
        touched.duration_secs = 300;
        touched.notes = Some("phrasing".to_string());
        touched.intention = Some("evenness".to_string());
        touched.planned_duration_secs = Some(300);
        touched.group_id = Some("g1".to_string());
        touched.planned_variation_id = Some("v-1".to_string());
        touched.planned_rep_target = Some(10);
        touched.plays = vec![VariationPlay {
            id: "e1-play".to_string(),
            variation_id: Some("v-1".to_string()),
            started_at: tap_at(),
            seconds: 300,
            rep_target: Some(10),
            rep_count: Some(1),
            rep_target_reached: Some(false),
            rep_history: Some(vec![
                RepEvent {
                    action: RepAction::Success,
                    at: tap_at(),
                },
                RepEvent {
                    action: RepAction::Missed,
                    at: tap_at() + chrono::Duration::seconds(40),
                },
                RepEvent {
                    action: RepAction::Success,
                    at: tap_at() + chrono::Duration::seconds(95),
                },
            ]),
            achieved_tempo: Some(120),
            click_pattern: Some(seven_eight_on_group_starts()),
            score: Some(4),
        }];
        let mut untouched = create_entry("x1", "Scales", ItemKind::Exercise, 1);
        untouched.id = "e2".to_string();
        ActiveSession {
            id: "s1".to_string(),
            entries: vec![touched, untouched],
            current_index: 1,
            current_item_started_at: tap_at(),
            session_started_at: started,
        }
    }

    const PINNED_ACTIVE_SESSION_HEX: &str = concat!(
        "02000000000000007331020000000000000002000000000000006531020000000000000070310d",
        "00000000000000436c616972206465204c756e650000000000000000000000002c010000000000",
        "00000000000108000000000000007068726173696e670108000000000000006576656e6e657373",
        "012c0100000102000000000000006731010300000000000000762d31010a010000000000000007",
        "0000000000000065312d706c6179010300000000000000762d311400000000000000323032362d",
        "30392d30335430393a30303a30305a2c01000000000000010a0101010001030000000000000001",
        "0000001400000000000000323032362d30392d30335430393a30303a30305a0000000014000000",
        "00000000323032362d30392d30335430393a30303a34305a010000001400000000000000323032",
        "362d30392d30335430393a30313a33355a01780001070801030000000000000003020229000104",
        "020000000000000065320200000000000000783106000000000000005363616c65730100000001",
        "000000000000000000000000000000020000000000000000000000000000000000010000000000",
        "00001400000000000000323032362d30392d30335430393a30303a30305a140000000000000032",
        "3032362d30392d30335430383a34373a30305a",
    );

    /// `AppEffect::SaveSessionInProgress(ActiveSession)` is positional bincode
    /// written by one build and read by the next, so any change to this graph
    /// must bump `Store.sessionInProgressKey` in the shell or an old blob
    /// decodes into a valid-looking wrong session (#1345). When this fails:
    /// bump the key, then paste the new hex. Never just paste the hex.
    #[test]
    fn active_session_blob_wire_is_pinned() {
        use crux_core::bridge::{BincodeFfiFormat, FfiFormat};
        let session = pinned_active_session();
        let mut bytes = Vec::new();
        BincodeFfiFormat::serialize(&mut bytes, &session).expect("serialize");
        let hex: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
        assert_eq!(
            hex, PINNED_ACTIVE_SESSION_HEX,
            "the crash-recovery blob changed shape: bump Store.sessionInProgressKey, then re-pin"
        );
        let back: ActiveSession =
            BincodeFfiFormat::deserialize(&bytes).expect("must decode on the FFI wire (#846)");
        assert_eq!(back, session);
    }

    /// The timestamped tap events and the history they write cross the bridge
    /// (#846 class); pinned before any screen sends the new payloads.
    #[test]
    fn rep_tap_events_round_trip_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(got_it());
        crate::domain::types::assert_round_trips(missed());
        crate::domain::types::assert_round_trips(pinned_active_session());
    }

    /// The extended tempo payload crosses the bridge with the click state on
    /// both its `Some` and `None` sides (#846 class), pinned before any screen
    /// sends it.
    #[test]
    fn update_entry_tempo_with_click_state_round_trips_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(Event::Session(SessionEvent::UpdateEntryTempo {
            entry_id: "e1".to_string(),
            play_id: "play-1".to_string(),
            tempo: Some(168),
            observed: TempoObservation {
                user_set: false,
                click_sounding: true,
            },
            click: Some(seven_eight_on_group_starts()),
        }));
        crate::domain::types::assert_round_trips(Event::Session(SessionEvent::UpdateEntryTempo {
            entry_id: "e1".to_string(),
            play_id: "play-1".to_string(),
            tempo: None,
            observed: TempoObservation {
                user_set: true,
                click_sounding: false,
            },
            click: None,
        }));
    }

    /// The variation tag (#1083, #1739) is the sole input to per-variation
    /// score derivation, and it now rides the wire twice: as the entry's plan
    /// and as the play's record. A silent drop on either would unscore every
    /// variation. Guard both, and the event that writes the plan, against the
    /// #846 class.
    #[test]
    fn set_entry_variant_payloads_round_trip_on_ffi_bincode_wire() {
        crate::domain::types::assert_round_trips(SetlistEntry {
            id: "e1".to_string(),
            item_id: "ex-1".to_string(),
            item_title: "Scales".to_string(),
            item_type: ItemKind::Exercise,
            position: 0,
            duration_secs: 300,
            status: EntryStatus::Completed,
            notes: None,
            intention: None,
            planned_duration_secs: None,
            group_id: None,
            planned_variation_id: Some("v1".to_string()),
            planned_rep_target: None,
            plays: vec![VariationPlay {
                id: "e1-play".to_string(),
                variation_id: Some("v1".to_string()),
                started_at: tap_at(),
                seconds: 300,
                score: Some(8),
                ..VariationPlay::fixture()
            }],
        });

        crate::domain::types::assert_round_trips(crate::app::Event::Session(
            SessionEvent::SetEntryVariant {
                entry_id: "e1".to_string(),
                variant_id: Some("v1".to_string()),
            },
        ));
    }

    // ── Variations and plays (#1739) ───────────────────────────────────

    /// An exercise with two live variations and one tombstoned, in a session
    /// that has already started. `v-gone` is the dead one.
    fn model_with_variations() -> (Model, DateTime<Utc>) {
        let (model, now) = building_with_variations();
        let mut model = model;
        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );
        (model, now)
    }

    fn building_with_variations() -> (Model, DateTime<Utc>) {
        use crate::domain::variant::Variant;

        let mut model = model_with_library();
        let now = Utc::now();
        let exercise = model
            .items
            .iter_mut()
            .find(|i| i.id == "exercise-1")
            .expect("the library fixture has exercise-1");
        exercise.variants = vec![
            Variant {
                id: "v-c".to_string(),
                label: "C".to_string(),
                position: 0,
                updated_at: now,
                deleted_at: None,
            },
            Variant {
                id: "v-d".to_string(),
                label: "D".to_string(),
                position: 1,
                updated_at: now,
                deleted_at: None,
            },
            Variant {
                id: "v-gone".to_string(),
                label: "E flat".to_string(),
                position: 2,
                updated_at: now,
                deleted_at: Some(now),
            },
        ];

        update(&mut model, Event::Session(SessionEvent::StartBuilding));
        update(
            &mut model,
            Event::Session(SessionEvent::AddToSetlist {
                item_id: "exercise-1".to_string(),
            }),
        );
        (model, now)
    }

    fn only_entry(model: &Model) -> &SetlistEntry {
        &session_entries(model)[0]
    }

    #[test]
    fn starting_a_session_opens_one_play_seeded_from_the_plan() {
        let (mut model, now) = building_with_variations();
        let entry_id = only_entry(&model).id.clone();

        update(
            &mut model,
            Event::Session(SessionEvent::SetEntryVariant {
                entry_id,
                variant_id: Some("v-c".to_string()),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::StartSession { now }),
        );

        let entry = only_entry(&model);
        assert_eq!(entry.plays.len(), 1);
        assert_eq!(play_of(entry).variation_id.as_deref(), Some("v-c"));
        assert_eq!(entry.planned_variation_id.as_deref(), Some("v-c"));
    }

    #[test]
    fn a_piece_records_exactly_one_unattributed_play() {
        let (model, _) = model_with_active_session(1);

        let entry = only_entry(&model);
        assert_eq!(entry.item_type, ItemKind::Piece);
        assert_eq!(entry.plays.len(), 1);
        assert_eq!(play_of(entry).variation_id, None);
    }

    #[test]
    fn switching_mid_item_closes_the_open_play_and_opens_another() {
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();
        let switched_at = start + chrono::Duration::seconds(180);

        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id,
                variation_id: Some("v-d".to_string()),
                now: switched_at,
            }),
        );

        assert!(model.last_error.is_none());
        let entry = only_entry(&model);
        assert_eq!(entry.plays.len(), 2);
        assert_eq!(entry.plays[0].seconds, 180);
        assert_eq!(entry.plays[1].variation_id.as_deref(), Some("v-d"));
        assert_eq!(entry.plays[1].seconds, 0);
    }

    #[test]
    fn switching_to_the_variation_already_open_writes_nothing() {
        // StartSession seeds the open play with v-c, the first live variation
        // (#1758), so the genuine switch under test is to v-d; switching to
        // v-c here would itself be a no-op rather than exercising one.
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();
        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id: entry_id.clone(),
                variation_id: Some("v-d".to_string()),
                now: start + chrono::Duration::seconds(60),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::RepGotIt {
                now: start + chrono::Duration::seconds(70),
            }),
        );

        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id,
                variation_id: Some("v-d".to_string()),
                now: start + chrono::Duration::seconds(80),
            }),
        );

        let entry = only_entry(&model);
        assert_eq!(entry.plays.len(), 2, "the stray tap opened nothing");
        assert_eq!(
            play_of(entry).rep_count,
            Some(1),
            "the stray tap did not clear the dots"
        );
    }

    #[test]
    fn repetitions_and_tempo_land_on_the_open_play_and_reset_on_a_switch() {
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();

        update(
            &mut model,
            Event::Session(SessionEvent::RepGotIt {
                now: start + chrono::Duration::seconds(10),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::RepGotIt {
                now: start + chrono::Duration::seconds(20),
            }),
        );
        assert_eq!(play_of(only_entry(&model)).rep_count, Some(2));

        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id,
                variation_id: Some("v-d".to_string()),
                now: start + chrono::Duration::seconds(30),
            }),
        );

        let entry = only_entry(&model);
        assert_eq!(
            entry.plays[0].rep_count,
            Some(2),
            "the first play keeps its"
        );
        assert_eq!(play_of(entry).rep_count, None, "the new play starts empty");
    }

    #[test]
    fn scoring_names_the_play_it_marks() {
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();
        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id: entry_id.clone(),
                variation_id: Some("v-d".to_string()),
                now: start + chrono::Duration::seconds(60),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: start + chrono::Duration::seconds(600),
            }),
        );
        let first = only_entry(&model).plays[0].id.clone();

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id,
                play_id: first,
                score: Some(7),
            }),
        );

        let entry = only_entry(&model);
        assert_eq!(entry.plays[0].score, Some(7));
        assert_eq!(entry.plays[1].score, None, "only the named play is marked");
    }

    #[test]
    fn a_play_id_from_another_entry_is_rejected() {
        let (mut model, start) = model_with_active_session(2);
        update(
            &mut model,
            Event::Session(SessionEvent::NextItem {
                now: start + chrono::Duration::seconds(300),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: start + chrono::Duration::seconds(600),
            }),
        );
        let first_entry = session_entries(&model)[0].id.clone();
        let second_entry = session_entries(&model)[1].id.clone();
        let foreign = first_play_id(&model, &second_entry);

        update(
            &mut model,
            Event::Session(SessionEvent::UpdateEntryScore {
                entry_id: first_entry.clone(),
                play_id: foreign,
                score: Some(7),
            }),
        );

        assert!(model.last_error.is_some());
        let entry = session_entries(&model)
            .iter()
            .find(|e| e.id == first_entry)
            .expect("the entry is there");
        assert!(entry.plays.iter().all(|p| p.score.is_none()));
    }

    #[test]
    fn switching_to_a_dead_variation_is_rejected() {
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();

        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id,
                variation_id: Some("v-gone".to_string()),
                now: start + chrono::Duration::seconds(60),
            }),
        );

        assert!(model.last_error.is_some());
        assert_eq!(only_entry(&model).plays.len(), 1);
    }

    #[test]
    fn an_entry_stops_at_the_play_cap() {
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();

        // Alternate, so every switch is a real one rather than a no-op.
        for i in 0..validation::MAX_PLAYS_PER_ENTRY + 4 {
            let variation = if i % 2 == 0 { "v-d" } else { "v-c" };
            update(
                &mut model,
                Event::Session(SessionEvent::SwitchVariation {
                    entry_id: entry_id.clone(),
                    variation_id: Some(variation.to_string()),
                    now: start + chrono::Duration::seconds(60 * (i as i64 + 1)),
                }),
            );
        }

        assert_eq!(
            only_entry(&model).plays.len(),
            validation::MAX_PLAYS_PER_ENTRY
        );
        assert!(model.last_error.is_some());
    }

    #[test]
    fn finishing_drops_a_play_that_recorded_nothing() {
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();
        let opened = only_entry(&model).plays[0].id.clone();
        // A stray tap on the picker, two seconds before the end.
        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id,
                variation_id: Some("v-d".to_string()),
                now: start + chrono::Duration::seconds(298),
            }),
        );

        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: start + chrono::Duration::seconds(300),
            }),
        );

        let entry = only_entry(&model);
        assert_eq!(entry.plays.len(), 1);
        assert_eq!(
            entry.plays[0].id, opened,
            "the stray tap's play went, not the real one"
        );
    }

    /// The drop must never empty a practised entry, or the item-complete sheet
    /// would hold a `play_id` the core has just deleted and every mark it sent
    /// would be refused (decision 3's invariant).
    #[test]
    fn finishing_keeps_the_only_play_however_short() {
        let (mut model, start) = model_with_variations();
        let opened = only_entry(&model).plays[0].id.clone();

        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: start + chrono::Duration::seconds(2),
            }),
        );

        let entry = only_entry(&model);
        assert_eq!(entry.status, EntryStatus::Completed);
        assert_eq!(entry.plays.len(), 1);
        assert_eq!(entry.plays[0].id, opened);
    }

    #[test]
    fn moving_off_an_item_keeps_its_only_play_however_short() {
        let (mut model, start) = model_with_active_session(2);
        let entry_id = session_entries(&model)[0].id.clone();
        let opened = session_entries(&model)[0].plays[0].id.clone();

        update(
            &mut model,
            Event::Session(SessionEvent::NextItem {
                now: start + chrono::Duration::seconds(2),
            }),
        );

        let entry = session_entries(&model)
            .iter()
            .find(|e| e.id == entry_id)
            .expect("the entry is still in the session");
        assert_eq!(entry.plays.len(), 1);
        assert_eq!(entry.plays[0].id, opened);
    }

    #[test]
    fn finishing_keeps_a_short_play_that_banked_a_repetition() {
        let (mut model, start) = model_with_variations();
        let entry_id = only_entry(&model).id.clone();
        update(
            &mut model,
            Event::Session(SessionEvent::SwitchVariation {
                entry_id,
                variation_id: Some("v-d".to_string()),
                now: start + chrono::Duration::seconds(298),
            }),
        );
        update(
            &mut model,
            Event::Session(SessionEvent::RepGotIt {
                now: start + chrono::Duration::seconds(299),
            }),
        );

        update(
            &mut model,
            Event::Session(SessionEvent::FinishSession {
                now: start + chrono::Duration::seconds(300),
            }),
        );

        let entry = only_entry(&model);
        assert_eq!(entry.plays.len(), 2);
        assert_eq!(entry.plays[1].rep_count, Some(1));
    }

    #[test]
    fn a_skipped_entry_keeps_a_play_that_banked_repetitions() {
        let (mut model, start) = model_with_variations();
        update(
            &mut model,
            Event::Session(SessionEvent::RepGotIt {
                now: start + chrono::Duration::seconds(30),
            }),
        );

        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem {
                now: start + chrono::Duration::seconds(60),
            }),
        );

        let entry = only_entry(&model);
        assert_eq!(entry.status, EntryStatus::Skipped);
        assert_eq!(entry.plays.len(), 1);
        assert_eq!(entry.plays[0].rep_count, Some(1));
    }

    #[test]
    fn a_skipped_entry_that_recorded_nothing_keeps_no_play() {
        let (mut model, start) = model_with_variations();

        update(
            &mut model,
            Event::Session(SessionEvent::SkipItem {
                now: start + chrono::Duration::seconds(60),
            }),
        );

        assert!(only_entry(&model).plays.is_empty());
    }

    #[test]
    fn score_summary_is_the_mean_of_the_plays_that_carry_a_mark() {
        let mut entry = SetlistEntry::fixture();
        entry.plays = vec![
            VariationPlay {
                score: Some(8),
                ..VariationPlay::fixture()
            },
            VariationPlay {
                score: Some(5),
                ..VariationPlay::fixture()
            },
            VariationPlay {
                score: None,
                ..VariationPlay::fixture()
            },
        ];

        assert_eq!(entry.score_summary(), Some(7), "13 over 2 rounds to 7");
    }

    #[test]
    fn score_summary_is_none_when_no_play_carries_a_mark() {
        let mut entry = SetlistEntry::fixture();
        entry.plays = vec![VariationPlay::fixture()];

        assert_eq!(entry.score_summary(), None);
    }

    #[test]
    fn switch_variation_and_the_play_id_events_round_trip_on_the_bincode_wire() {
        crate::domain::types::assert_round_trips(crate::app::Event::Session(
            SessionEvent::SwitchVariation {
                entry_id: "e1".to_string(),
                variation_id: Some("v-d".to_string()),
                now: tap_at(),
            },
        ));
        crate::domain::types::assert_round_trips(crate::app::Event::Session(
            SessionEvent::UpdateEntryScore {
                entry_id: "e1".to_string(),
                play_id: "e1-play".to_string(),
                score: Some(7),
            },
        ));
        crate::domain::types::assert_round_trips(crate::app::Event::Session(
            SessionEvent::UpdateEntryTempo {
                entry_id: "e1".to_string(),
                play_id: "e1-play".to_string(),
                tempo: Some(120),
                observed: TempoObservation {
                    user_set: true,
                    click_sounding: false,
                },
                click: None,
            },
        ));
    }
}
