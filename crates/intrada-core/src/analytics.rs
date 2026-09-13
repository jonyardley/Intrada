//! Analytics computations. All functions are pure and take a `LocalClock`
//! (rather than reading the clock) so they're deterministic under test.

use std::cmp::Reverse;
use std::collections::{HashMap, HashSet};

use chrono::{DateTime, Datelike, NaiveDate, NaiveDateTime, Timelike, Utc};
use serde::{Deserialize, Serialize};

use crate::domain::item::{Item, ItemKind};
use crate::domain::session::PracticeSession;
use crate::model::ItemPracticeSummary;
use crate::staleness;

// ── Analytics View Model Types ───────────────────────────────────────

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
#[serde(rename_all = "lowercase")]
pub enum Direction {
    Up,
    Down,
    #[default]
    Same,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct NeglectedItem {
    pub item_id: String,
    pub item_title: String,
    /// Days since last practised; `None` means never practised.
    pub days_since_practice: Option<u32>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ScoreChange {
    pub item_id: String,
    pub item_title: String,
    /// Latest score before this week; `None` if scored for the first time.
    pub previous_score: Option<u8>,
    pub current_score: u8,
    /// Signed change (current − previous); 0 for newly scored items.
    pub delta: i8,
    pub is_new: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct AnalyticsView {
    pub weekly_summary: WeeklySummary,
    pub streak: PracticeStreak,
    pub daily_totals: Vec<DailyPracticeTotal>,
    pub top_items: Vec<ItemRanking>,
    pub score_trends: Vec<ItemScoreTrend>,
    pub neglected_items: Vec<NeglectedItem>,
    pub score_changes: Vec<ScoreChange>,
}

/// Aggregated stats for the current and previous ISO weeks (Monday–Sunday).
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct WeeklySummary {
    pub total_minutes: u32,
    pub session_count: usize,
    pub items_covered: usize,
    pub prev_total_minutes: u32,
    pub prev_session_count: usize,
    pub prev_items_covered: usize,
    pub time_direction: Direction,
    pub sessions_direction: Direction,
    pub items_direction: Direction,
    pub has_prev_week_data: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct PracticeStreak {
    pub current_days: u32,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct DailyPracticeTotal {
    pub date: String,
    pub minutes: u32,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ItemRanking {
    pub item_id: String,
    pub item_title: String,
    pub item_type: ItemKind,
    pub total_minutes: u32,
    pub session_count: usize,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ItemScoreTrend {
    pub item_id: String,
    pub item_title: String,
    pub scores: Vec<ScorePoint>,
    pub latest_score: u8,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ScorePoint {
    pub date: String,
    pub score: u8,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct LastPractisedView {
    /// What the session was mostly about: the item it spent longest on.
    pub item_title: String,
    /// The day on its own: `Today`, `Yesterday`, a weekday inside the past
    /// week, otherwise `7 Aug` (with the year once it is a different one).
    pub relative_day: String,
    /// The same day as a full line: `Last practised Tuesday`.
    pub label: String,
}

// ── Local Clock ──────────────────────────────────────────────────────

/// The user's calendar context: which day is "today" and the UTC offset that
/// turns a stored UTC instant into the day the user experienced it. Without
/// the offset, days turn over at midnight UTC, so a 00:30 BST session counted
/// toward the previous day's streak (#1330).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct LocalClock {
    pub today: NaiveDate,
    pub utc_offset_minutes: i32,
}

impl LocalClock {
    pub fn from_now(now: DateTime<Utc>, utc_offset_minutes: i32) -> Self {
        let clock = LocalClock {
            today: now.date_naive(),
            utc_offset_minutes,
        };
        LocalClock {
            today: clock.day_of(now),
            ..clock
        }
    }

    /// The user-local calendar day of a UTC instant.
    pub fn day_of(&self, instant: DateTime<Utc>) -> NaiveDate {
        self.local(instant).date()
    }

    /// The user-local hour (0 to 23) of a UTC instant.
    pub fn hour_of(&self, instant: DateTime<Utc>) -> u32 {
        self.local(instant).hour()
    }

    fn local(&self, instant: DateTime<Utc>) -> NaiveDateTime {
        (instant + chrono::Duration::minutes(self.utc_offset_minutes as i64)).naive_utc()
    }
}

// ── Computation Functions ────────────────────────────────────────────

pub fn compute_analytics(
    sessions: &[PracticeSession],
    items: &[Item],
    summaries: &HashMap<String, ItemPracticeSummary>,
    clock: LocalClock,
) -> AnalyticsView {
    AnalyticsView {
        weekly_summary: compute_weekly_summary(sessions, clock),
        streak: compute_streak(sessions, clock),
        daily_totals: compute_daily_totals(sessions, clock),
        top_items: compute_top_items(sessions),
        score_trends: compute_score_trends(sessions, clock),
        neglected_items: compute_neglected_items(summaries, items, clock),
        score_changes: compute_score_changes(sessions, clock),
    }
}

/// Uses ISO week numbering (Monday = start of week).
pub fn compute_weekly_summary(sessions: &[PracticeSession], clock: LocalClock) -> WeeklySummary {
    let today_iso_week = clock.today.iso_week();
    let prev_week_date = clock.today - chrono::Duration::days(7);
    let prev_iso_week = prev_week_date.iso_week();

    let mut total_secs: u64 = 0;
    let mut session_count: usize = 0;
    let mut current_item_ids: HashSet<String> = HashSet::new();

    let mut prev_secs: u64 = 0;
    let mut prev_session_count: usize = 0;
    let mut prev_item_ids: HashSet<String> = HashSet::new();

    for session in sessions {
        let session_date = clock.day_of(session.started_at);
        let session_week = session_date.iso_week();

        if session_week == today_iso_week {
            total_secs += session.total_duration_secs;
            session_count += 1;
            for entry in &session.entries {
                current_item_ids.insert(entry.item_id.clone());
            }
        } else if session_week == prev_iso_week {
            prev_secs += session.total_duration_secs;
            prev_session_count += 1;
            for entry in &session.entries {
                prev_item_ids.insert(entry.item_id.clone());
            }
        }
    }

    let total_minutes = (total_secs / 60) as u32;
    let prev_total_minutes = (prev_secs / 60) as u32;
    let items_covered = current_item_ids.len();
    let prev_items_covered = prev_item_ids.len();
    let has_prev_week_data = prev_session_count > 0;

    fn direction(current: usize, previous: usize) -> Direction {
        if current > previous {
            Direction::Up
        } else if current < previous {
            Direction::Down
        } else {
            Direction::Same
        }
    }

    WeeklySummary {
        total_minutes,
        session_count,
        items_covered,
        prev_total_minutes,
        prev_session_count,
        prev_items_covered,
        time_direction: direction(total_minutes as usize, prev_total_minutes as usize),
        sessions_direction: direction(session_count, prev_session_count),
        items_direction: direction(items_covered, prev_items_covered),
        has_prev_week_data,
    }
}

/// Counts backwards from `today` (or yesterday if today has no session) as long
/// as each day has at least one session.
pub fn compute_streak(sessions: &[PracticeSession], clock: LocalClock) -> PracticeStreak {
    if sessions.is_empty() {
        return PracticeStreak { current_days: 0 };
    }

    let session_dates: HashSet<NaiveDate> = sessions
        .iter()
        .map(|s| clock.day_of(s.started_at))
        .collect();

    let mut current = clock.today;
    if !session_dates.contains(&current) {
        current = clock.today - chrono::Duration::days(1);
    }

    let mut streak: u32 = 0;
    while session_dates.contains(&current) {
        streak += 1;
        current -= chrono::Duration::days(1);
    }

    PracticeStreak {
        current_days: streak,
    }
}

/// Returns exactly 28 entries, oldest first (today − 27 days through today).
pub fn compute_daily_totals(
    sessions: &[PracticeSession],
    clock: LocalClock,
) -> Vec<DailyPracticeTotal> {
    let mut secs_by_date: HashMap<NaiveDate, u64> = HashMap::new();
    for session in sessions {
        let date = clock.day_of(session.started_at);
        *secs_by_date.entry(date).or_default() += session.total_duration_secs;
    }

    (0..28)
        .rev()
        .map(|days_ago| {
            let date = clock.today - chrono::Duration::days(days_ago);
            let minutes = (secs_by_date.get(&date).copied().unwrap_or(0) / 60) as u32;
            DailyPracticeTotal {
                date: date.format("%Y-%m-%d").to_string(),
                minutes,
            }
        })
        .collect()
}

/// Top 10 items by total time practised.
pub fn compute_top_items(sessions: &[PracticeSession]) -> Vec<ItemRanking> {
    let mut items: HashMap<String, (String, ItemKind, u64, HashSet<String>)> = HashMap::new();

    for session in sessions {
        for entry in &session.entries {
            let record = items.entry(entry.item_id.clone()).or_insert_with(|| {
                (
                    entry.item_title.clone(),
                    entry.item_type.clone(),
                    0,
                    HashSet::new(),
                )
            });
            record.2 += entry.duration_secs;
            record.3.insert(session.id.clone());
        }
    }

    let mut rankings: Vec<ItemRanking> = items
        .into_iter()
        .map(
            |(item_id, (title, item_type, total_secs, session_ids))| ItemRanking {
                item_id,
                item_title: title,
                item_type,
                total_minutes: (total_secs / 60) as u32,
                session_count: session_ids.len(),
            },
        )
        .collect();

    rankings.sort_by_key(|r| (Reverse(r.total_minutes), r.item_id.clone()));
    rankings.truncate(10);
    rankings
}

/// The 5 most recently scored items, each with a chronological score series.
pub fn compute_score_trends(
    sessions: &[PracticeSession],
    clock: LocalClock,
) -> Vec<ItemScoreTrend> {
    let mut scored: HashMap<String, (String, Vec<(NaiveDate, u8)>)> = HashMap::new();

    for session in sessions {
        let session_date = clock.day_of(session.started_at);
        for entry in &session.entries {
            if let Some(score) = entry.score_summary() {
                let record = scored
                    .entry(entry.item_id.clone())
                    .or_insert_with(|| (entry.item_title.clone(), Vec::new()));
                record.1.push((session_date, score));
            }
        }
    }

    if scored.is_empty() {
        return Vec::new();
    }

    let mut trends: Vec<ItemScoreTrend> = scored
        .into_iter()
        .map(|(item_id, (title, mut score_points))| {
            score_points.sort_by_key(|(date, _)| *date);

            let latest_score = score_points.last().map(|(_, s)| *s).unwrap_or(0);

            let scores = score_points
                .iter()
                .map(|(date, score)| ScorePoint {
                    date: date.format("%Y-%m-%d").to_string(),
                    score: *score,
                })
                .collect();

            ItemScoreTrend {
                item_id,
                item_title: title,
                scores,
                latest_score,
            }
        })
        .collect();

    trends.sort_by(|a, b| {
        let a_latest = a.scores.last().map(|s| s.date.as_str()).unwrap_or("");
        let b_latest = b.scores.last().map(|s| s.date.as_str()).unwrap_or("");
        b_latest.cmp(a_latest)
    });

    trends.truncate(5);
    trends
}

/// Items the library has left behind: never practised, or past the return
/// interval their own history earns them (#1416). Up to 5, furthest through
/// that interval first. Graded rather than a flat 14-day cut, and over the same
/// `staleness` estimate the Up next reasons read, so the core has one opinion
/// about how cold something is rather than two.
pub fn compute_neglected_items(
    summaries: &HashMap<String, ItemPracticeSummary>,
    items: &[Item],
    clock: LocalClock,
) -> Vec<NeglectedItem> {
    let mut neglected: Vec<(u32, NeglectedItem)> = items
        .iter()
        .filter_map(|item| {
            let practice = summaries.get(&item.id);
            let staleness =
                staleness::assess(practice, practice.and_then(|p| p.latest_score), clock);
            (!staleness.is_fresh()).then(|| {
                (
                    staleness.overdue_key(),
                    NeglectedItem {
                        item_id: item.id.clone(),
                        item_title: item.title.clone(),
                        days_since_practice: staleness.days(),
                    },
                )
            })
        })
        .collect();

    // Ties are the rule, not the exception: every never-practised item shares
    // the sentinel key, so the id decides rather than the library's own order.
    neglected
        .sort_by(|(a_key, a), (b_key, b)| b_key.cmp(a_key).then_with(|| a.item_id.cmp(&b.item_id)));
    neglected.truncate(5);
    neglected.into_iter().map(|(_, item)| item).collect()
}

/// This week's latest score vs the latest before it, per item. Up to 5, largest
/// absolute delta first.
pub fn compute_score_changes(sessions: &[PracticeSession], clock: LocalClock) -> Vec<ScoreChange> {
    let today_iso_week = clock.today.iso_week();

    let mut this_week: HashMap<String, (u8, NaiveDate, String)> = HashMap::new();
    let mut prev: HashMap<String, (u8, NaiveDate)> = HashMap::new();

    for session in sessions {
        let session_date = clock.day_of(session.started_at);
        for entry in &session.entries {
            if let Some(score) = entry.score_summary() {
                if session_date.iso_week() == today_iso_week {
                    let existing = this_week.get(&entry.item_id);
                    if !matches!(existing, Some(e) if session_date < e.1) {
                        this_week.insert(
                            entry.item_id.clone(),
                            (score, session_date, entry.item_title.clone()),
                        );
                    }
                } else {
                    let existing = prev.get(&entry.item_id);
                    if !matches!(existing, Some(e) if session_date < e.1) {
                        prev.insert(entry.item_id.clone(), (score, session_date));
                    }
                }
            }
        }
    }

    let mut changes: Vec<ScoreChange> = Vec::new();

    for (item_id, (current_score, _date, item_title)) in &this_week {
        let previous = prev.get(item_id);

        match previous {
            Some((prev_score, _)) if *prev_score == *current_score => {
                continue;
            }
            Some((prev_score, _)) => {
                changes.push(ScoreChange {
                    item_id: item_id.clone(),
                    item_title: item_title.clone(),
                    previous_score: Some(*prev_score),
                    current_score: *current_score,
                    delta: *current_score as i8 - *prev_score as i8,
                    is_new: false,
                });
            }
            None => {
                changes.push(ScoreChange {
                    item_id: item_id.clone(),
                    item_title: item_title.clone(),
                    previous_score: None,
                    current_score: *current_score,
                    delta: 0,
                    is_new: true,
                });
            }
        }
    }

    changes.sort_by_key(|c| (Reverse(c.delta.unsigned_abs()), c.item_id.clone()));

    changes.truncate(5);
    changes
}

// ── Last practised ───────────────────────────────────────────────────

/// What the Practice screen leads with: the last thing played and when. Both
/// the hero and the header subtitle read this one projection, and the day is
/// resolved on the user's clock rather than UTC (#1330).
pub fn compute_last_practised(
    sessions: &[PracticeSession],
    clock: LocalClock,
) -> Option<LastPractisedView> {
    let session = sessions
        .iter()
        .filter(|s| !s.entries.is_empty())
        .max_by_key(|s| s.started_at)?;

    // The longest entry, not the first: a session that opens with five minutes
    // of scales and spends twenty on the piece was about the piece.
    let headline = session
        .entries
        .iter()
        .max_by_key(|e| (e.duration_secs, Reverse(e.position)))?;

    let (relative_day, in_sentence) = relative_day(clock.day_of(session.started_at), clock.today);
    Some(LastPractisedView {
        item_title: headline.item_title.clone(),
        relative_day,
        label: format!("Last practised {in_sentence}"),
    })
}

/// `(standalone, mid-sentence)`: `Today` heads a line of its own but reads
/// `Last practised today` inside one; weekdays and dates are capitalised in both.
fn relative_day(day: NaiveDate, today: NaiveDate) -> (String, String) {
    match (today - day).num_days() {
        0 => ("Today".to_string(), "today".to_string()),
        1 => ("Yesterday".to_string(), "yesterday".to_string()),
        // Seven days back repeats today's weekday, so the name stops being a date.
        2..=6 => {
            let weekday = day.format("%A").to_string();
            (weekday.clone(), weekday)
        }
        _ => {
            let pattern = if day.year() == today.year() {
                "%-d %b"
            } else {
                "%-d %b %Y"
            };
            let date = day.format(pattern).to_string();
            (date.clone(), date)
        }
    }
}

// ── Tests ────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session::{
        CompletionStatus, EntryStatus, PracticeSession, SetlistEntry, VariationPlay,
    };
    use chrono::{NaiveDate, TimeZone, Utc};

    fn clock(today: NaiveDate) -> LocalClock {
        LocalClock {
            today,
            utc_offset_minutes: 0,
        }
    }

    fn make_session(
        id: &str,
        date: NaiveDate,
        total_secs: u64,
        entries: Vec<SetlistEntry>,
    ) -> PracticeSession {
        let started = Utc.from_utc_datetime(&date.and_hms_opt(10, 0, 0).expect("valid time"));
        make_session_at(id, started, total_secs, entries)
    }

    fn make_session_at(
        id: &str,
        started: chrono::DateTime<Utc>,
        total_secs: u64,
        entries: Vec<SetlistEntry>,
    ) -> PracticeSession {
        let finished = started + chrono::Duration::seconds(total_secs as i64);
        PracticeSession {
            id: id.to_string(),
            started_at: started,
            completed_at: finished,
            total_duration_secs: total_secs,
            completion_status: CompletionStatus::Completed,
            session_notes: None,
            entries,
            session_score: None,
        }
    }

    fn make_entry(
        item_id: &str,
        title: &str,
        item_type: ItemKind,
        duration_secs: u64,
        score: Option<u8>,
    ) -> SetlistEntry {
        let id = format!("entry-{item_id}-{duration_secs}");
        SetlistEntry {
            plays: vec![VariationPlay {
                id: format!("{id}-play"),
                seconds: duration_secs,
                score,
                ..VariationPlay::fixture()
            }],
            id,
            item_id: item_id.to_string(),
            item_title: title.to_string(),
            item_type,
            position: 0,
            duration_secs,
            status: EntryStatus::Completed,
            ..SetlistEntry::fixture()
        }
    }

    // ── Weekly Summary Tests ──────────────────────────────────────────

    #[test]
    fn test_weekly_summary_basic() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap(); // Wednesday
        let mon = NaiveDate::from_ymd_opt(2026, 2, 16).unwrap(); // Monday (same week)
        let tue = NaiveDate::from_ymd_opt(2026, 2, 17).unwrap();

        let sessions = vec![
            make_session("s1", mon, 1800, vec![]),  // 30 min
            make_session("s2", tue, 2700, vec![]),  // 45 min
            make_session("s3", today, 600, vec![]), // 10 min
        ];

        let summary = compute_weekly_summary(&sessions, clock(today));
        assert_eq!(summary.total_minutes, 85); // 30 + 45 + 10
        assert_eq!(summary.session_count, 3);
    }

    #[test]
    fn test_weekly_summary_excludes_previous_week() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap(); // Wednesday
        let last_week = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap(); // previous Wed

        let sessions = vec![
            make_session("s1", last_week, 3600, vec![]), // 60 min (previous week)
            make_session("s2", today, 1200, vec![]),     // 20 min (this week)
        ];

        let summary = compute_weekly_summary(&sessions, clock(today));
        assert_eq!(summary.total_minutes, 20);
        assert_eq!(summary.session_count, 1);
    }

    #[test]
    fn test_weekly_summary_empty() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let summary = compute_weekly_summary(&[], clock(today));
        assert_eq!(summary.total_minutes, 0);
        assert_eq!(summary.session_count, 0);
    }

    // ── Week-over-week comparison tests ────────────────────────────────

    #[test]
    fn test_weekly_summary_comparison_both_weeks() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap(); // Wed, week 8
        let this_mon = NaiveDate::from_ymd_opt(2026, 2, 16).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap(); // Wed, week 7
        let last_thu = NaiveDate::from_ymd_opt(2026, 2, 12).unwrap();

        let sessions = vec![
            // This week: 2 sessions, 50 min, 2 items
            make_session(
                "s1",
                this_mon,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
            ),
            make_session(
                "s2",
                today,
                1200,
                vec![make_entry("p2", "Scales", ItemKind::Exercise, 1200, None)],
            ),
            // Last week: 3 sessions, 90 min, 1 item
            make_session(
                "s3",
                last_wed,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
            ),
            make_session(
                "s4",
                last_wed,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
            ),
            make_session(
                "s5",
                last_thu,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
            ),
        ];

        let summary = compute_weekly_summary(&sessions, clock(today));
        assert_eq!(summary.total_minutes, 50);
        assert_eq!(summary.session_count, 2);
        assert_eq!(summary.items_covered, 2);
        assert_eq!(summary.prev_total_minutes, 90);
        assert_eq!(summary.prev_session_count, 3);
        assert_eq!(summary.prev_items_covered, 1);
        assert_eq!(summary.time_direction, Direction::Down);
        assert_eq!(summary.sessions_direction, Direction::Down);
        assert_eq!(summary.items_direction, Direction::Up);
        assert!(summary.has_prev_week_data);
    }

    #[test]
    fn test_weekly_summary_this_week_only() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![make_session(
            "s1",
            today,
            1800,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
        )];

        let summary = compute_weekly_summary(&sessions, clock(today));
        assert_eq!(summary.total_minutes, 30);
        assert_eq!(summary.session_count, 1);
        assert_eq!(summary.items_covered, 1);
        assert_eq!(summary.prev_total_minutes, 0);
        assert_eq!(summary.prev_session_count, 0);
        assert_eq!(summary.prev_items_covered, 0);
        assert!(!summary.has_prev_week_data);
    }

    #[test]
    fn test_weekly_summary_last_week_only() {
        // Monday morning — no sessions this week, sessions last week
        let today = NaiveDate::from_ymd_opt(2026, 2, 16).unwrap(); // Monday
        let last_fri = NaiveDate::from_ymd_opt(2026, 2, 13).unwrap();

        let sessions = vec![make_session(
            "s1",
            last_fri,
            3600,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 3600, None)],
        )];

        let summary = compute_weekly_summary(&sessions, clock(today));
        assert_eq!(summary.total_minutes, 0);
        assert_eq!(summary.session_count, 0);
        assert_eq!(summary.items_covered, 0);
        assert_eq!(summary.prev_total_minutes, 60);
        assert_eq!(summary.prev_session_count, 1);
        assert_eq!(summary.prev_items_covered, 1);
        assert!(summary.has_prev_week_data);
        assert_eq!(summary.time_direction, Direction::Down);
    }

    #[test]
    fn test_weekly_summary_items_covered_counts_distinct() {
        // Multiple entries for same item counted once
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![
            make_session(
                "s1",
                today,
                1800,
                vec![
                    make_entry("p1", "Sonata", ItemKind::Piece, 900, None),
                    make_entry("p1", "Sonata", ItemKind::Piece, 900, None), // same item
                ],
            ),
            make_session(
                "s2",
                today,
                600,
                vec![
                    make_entry("p1", "Sonata", ItemKind::Piece, 300, None), // same item again
                    make_entry("p2", "Scales", ItemKind::Exercise, 300, None),
                ],
            ),
        ];

        let summary = compute_weekly_summary(&sessions, clock(today));
        assert_eq!(summary.items_covered, 2); // p1 + p2, not 4
    }

    #[test]
    fn test_weekly_summary_directions() {
        // Up when current > prev, Down when current < prev, Same when equal
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap();

        let sessions = vec![
            // This week: 2 sessions, 60 min, 1 item
            make_session(
                "s1",
                today,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
            ),
            make_session(
                "s2",
                today,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
            ),
            // Last week: 2 sessions, 30 min, 1 item (sessions same, time down, items same)
            make_session(
                "s3",
                last_wed,
                900,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 900, None)],
            ),
            make_session(
                "s4",
                last_wed,
                900,
                vec![make_entry("p2", "Scales", ItemKind::Exercise, 900, None)],
            ),
        ];

        let summary = compute_weekly_summary(&sessions, clock(today));
        assert_eq!(summary.time_direction, Direction::Up); // 60 > 30
        assert_eq!(summary.sessions_direction, Direction::Same); // 2 == 2
        assert_eq!(summary.items_direction, Direction::Down); // 1 < 2
    }

    #[test]
    fn test_weekly_summary_week_boundary() {
        // Sunday 23:55 belongs to ending week, Monday 00:05 to new week
        let monday = NaiveDate::from_ymd_opt(2026, 2, 16).unwrap();
        let sunday = NaiveDate::from_ymd_opt(2026, 2, 15).unwrap(); // Previous week's Sunday

        let sun_session = {
            use chrono::TimeZone;
            let started = chrono::Utc.from_utc_datetime(&sunday.and_hms_opt(23, 55, 0).unwrap());
            PracticeSession {
                id: "sun".to_string(),
                started_at: started,
                completed_at: started + chrono::Duration::seconds(600),
                total_duration_secs: 600,
                completion_status: crate::domain::session::CompletionStatus::Completed,
                session_notes: None,
                entries: vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, None)],
                session_score: None,
            }
        };

        let mon_session = make_session(
            "mon",
            monday,
            1200,
            vec![make_entry("p2", "Scales", ItemKind::Exercise, 1200, None)],
        );

        // From Monday's perspective
        let summary = compute_weekly_summary(&[sun_session, mon_session], clock(monday));
        assert_eq!(summary.session_count, 1); // Only Monday's session in current week
        assert_eq!(summary.prev_session_count, 1); // Sunday's session in previous week
        assert_eq!(summary.items_covered, 1); // p2 only
        assert_eq!(summary.prev_items_covered, 1); // p1 only
    }

    // ── Streak Tests ──────────────────────────────────────────────────

    #[test]
    fn test_streak_consecutive_days() {
        // 3 consecutive days ending today
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let yesterday = NaiveDate::from_ymd_opt(2026, 2, 17).unwrap();
        let day_before = NaiveDate::from_ymd_opt(2026, 2, 16).unwrap();

        let sessions = vec![
            make_session("s1", day_before, 1800, vec![]),
            make_session("s2", yesterday, 1800, vec![]),
            make_session("s3", today, 1800, vec![]),
        ];

        let streak = compute_streak(&sessions, clock(today));
        assert_eq!(streak.current_days, 3);
    }

    #[test]
    fn test_streak_broken() {
        // gap in days resets streak
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let yesterday = NaiveDate::from_ymd_opt(2026, 2, 17).unwrap();
        // Skip Feb 16
        let three_days_ago = NaiveDate::from_ymd_opt(2026, 2, 15).unwrap();

        let sessions = vec![
            make_session("s1", three_days_ago, 1800, vec![]),
            make_session("s2", yesterday, 1800, vec![]),
            make_session("s3", today, 1800, vec![]),
        ];

        let streak = compute_streak(&sessions, clock(today));
        assert_eq!(streak.current_days, 2); // Only yesterday + today
    }

    #[test]
    fn test_streak_no_sessions_today() {
        // sessions on yesterday and day before, no session today
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let yesterday = NaiveDate::from_ymd_opt(2026, 2, 17).unwrap();
        let day_before = NaiveDate::from_ymd_opt(2026, 2, 16).unwrap();

        let sessions = vec![
            make_session("s1", day_before, 1800, vec![]),
            make_session("s2", yesterday, 1800, vec![]),
        ];

        let streak = compute_streak(&sessions, clock(today));
        assert_eq!(streak.current_days, 2);
    }

    #[test]
    fn test_streak_empty() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let streak = compute_streak(&[], clock(today));
        assert_eq!(streak.current_days, 0);
    }

    // ── Daily Totals Tests ────────────────────────────────────────────

    #[test]
    fn test_daily_totals_28_days() {
        // sessions across 5 different days within past 28 days
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![
            make_session("s1", today, 1800, vec![]), // 30 min
            make_session("s2", today - chrono::Duration::days(1), 2700, vec![]), // 45 min
            make_session("s3", today - chrono::Duration::days(5), 600, vec![]), // 10 min
            make_session("s4", today - chrono::Duration::days(10), 3600, vec![]), // 60 min
            make_session("s5", today - chrono::Duration::days(27), 900, vec![]), // 15 min (oldest in range)
        ];

        let totals = compute_daily_totals(&sessions, clock(today));
        assert_eq!(totals.len(), 28);

        assert_eq!(totals[0].date, "2026-01-22"); // 27 days ago
        assert_eq!(totals[0].minutes, 15); // s5

        assert_eq!(totals[27].date, "2026-02-18"); // today
        assert_eq!(totals[27].minutes, 30); // s1

        assert_eq!(totals[26].minutes, 45); // yesterday
        assert_eq!(totals[22].minutes, 10); // 5 days ago
        assert_eq!(totals[17].minutes, 60); // 10 days ago

        assert_eq!(totals[25].minutes, 0); // 2 days ago, no session
    }

    #[test]
    fn test_daily_totals_multiple_sessions_same_day() {
        // 3 sessions on the same day
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![
            make_session("s1", today, 1800, vec![]), // 30 min
            make_session("s2", today, 1200, vec![]), // 20 min
            make_session("s3", today, 600, vec![]),  // 10 min
        ];

        let totals = compute_daily_totals(&sessions, clock(today));
        assert_eq!(totals[27].minutes, 60); // 30 + 20 + 10
    }

    #[test]
    fn test_daily_totals_empty() {
        // empty sessions → 28 entries all 0
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let totals = compute_daily_totals(&[], clock(today));
        assert_eq!(totals.len(), 28);
        assert!(totals.iter().all(|t| t.minutes == 0));
    }

    // ── Top Items Tests ───────────────────────────────────────────────

    #[test]
    fn test_top_items_ranking() {
        // 5 items with varying durations, verify sorted by total_minutes descending
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![make_session(
            "s1",
            today,
            9000,
            vec![
                make_entry("p1", "Sonata", ItemKind::Piece, 3600, None), // 60 min
                make_entry("p2", "Etude", ItemKind::Piece, 1800, None),  // 30 min
                make_entry("e1", "Scales", ItemKind::Exercise, 900, None), // 15 min
                make_entry("e2", "Arps", ItemKind::Exercise, 1500, None), // 25 min
                make_entry("p3", "Nocturne", ItemKind::Piece, 1200, None), // 20 min
            ],
        )];

        let ranking = compute_top_items(&sessions);
        assert_eq!(ranking.len(), 5);
        assert_eq!(ranking[0].item_id, "p1"); // 60 min
        assert_eq!(ranking[0].total_minutes, 60);
        assert_eq!(ranking[1].item_id, "p2"); // 30 min
        assert_eq!(ranking[2].item_id, "e2"); // 25 min
        assert_eq!(ranking[3].item_id, "p3"); // 20 min
        assert_eq!(ranking[4].item_id, "e1"); // 15 min
    }

    #[test]
    fn test_top_items_ties_break_by_item_id() {
        // 3 items tied on total_minutes → order is deterministic (item_id asc),
        // not whatever order the underlying HashMap happened to iterate in.
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![make_session(
            "s1",
            today,
            5400,
            vec![
                make_entry("zeta", "Zeta", ItemKind::Piece, 1800, None),
                make_entry("alpha", "Alpha", ItemKind::Piece, 1800, None),
                make_entry("mid", "Mid", ItemKind::Piece, 1800, None),
            ],
        )];

        let ranking = compute_top_items(&sessions);
        let ids: Vec<&str> = ranking.iter().map(|r| r.item_id.as_str()).collect();
        assert_eq!(ids, vec!["alpha", "mid", "zeta"]);
    }

    #[test]
    fn test_top_items_max_10() {
        // 15 items → only top 10 returned
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let entries: Vec<SetlistEntry> = (0..15)
            .map(|i| {
                make_entry(
                    &format!("item{i}"),
                    &format!("Item {i}"),
                    ItemKind::Piece,
                    (i + 1) as u64 * 60, // 1 min, 2 min, ..., 15 min
                    None,
                )
            })
            .collect();

        let total_secs: u64 = entries.iter().map(|e| e.duration_secs).sum();
        let sessions = vec![make_session("s1", today, total_secs, entries)];

        let ranking = compute_top_items(&sessions);
        assert_eq!(ranking.len(), 10);
        // Highest should be item14 (15 min)
        assert_eq!(ranking[0].item_id, "item14");
        assert_eq!(ranking[0].total_minutes, 15);
    }

    #[test]
    fn test_top_items_session_count() {
        // same item in 3 sessions → session_count is 3
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let yesterday = today - chrono::Duration::days(1);
        let day_before = today - chrono::Duration::days(2);

        let sessions = vec![
            make_session(
                "s1",
                today,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
            ),
            make_session(
                "s2",
                yesterday,
                1200,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1200, None)],
            ),
            make_session(
                "s3",
                day_before,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, None)],
            ),
        ];

        let ranking = compute_top_items(&sessions);
        assert_eq!(ranking.len(), 1);
        assert_eq!(ranking[0].session_count, 3);
        assert_eq!(ranking[0].total_minutes, 60); // (1800+1200+600)/60 = 60
    }

    #[test]
    fn test_top_items_empty() {
        let ranking = compute_top_items(&[]);
        assert!(ranking.is_empty());
    }

    // ── Score Trends Tests ────────────────────────────────────────────

    #[test]
    fn test_score_trends_basic() {
        // 3 sessions scoring the same item with 2, 3, 4
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let d1 = today - chrono::Duration::days(2);
        let d2 = today - chrono::Duration::days(1);
        let d3 = today;

        let sessions = vec![
            make_session(
                "s1",
                d1,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, Some(2))],
            ),
            make_session(
                "s2",
                d2,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, Some(3))],
            ),
            make_session(
                "s3",
                d3,
                1800,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, Some(4))],
            ),
        ];

        let trends = compute_score_trends(&sessions, clock(today));
        assert_eq!(trends.len(), 1);
        assert_eq!(trends[0].item_id, "p1");
        assert_eq!(trends[0].latest_score, 4);
        assert_eq!(trends[0].scores.len(), 3);
        // Chronological order
        assert_eq!(trends[0].scores[0].score, 2);
        assert_eq!(trends[0].scores[1].score, 3);
        assert_eq!(trends[0].scores[2].score, 4);
    }

    #[test]
    fn test_score_trends_max_5_items() {
        // 8 items scored → only 5 most recently scored returned
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let entries: Vec<SetlistEntry> = (0..8)
            .map(|i| {
                make_entry(
                    &format!("item{i}"),
                    &format!("Item {i}"),
                    ItemKind::Piece,
                    900,
                    Some(3),
                )
            })
            .collect();

        // Create sessions on different days so each item has a different "most recent" date
        let sessions: Vec<PracticeSession> = (0..8)
            .map(|i| {
                let date = today - chrono::Duration::days(i);
                make_session(
                    &format!("s{i}"),
                    date,
                    900,
                    vec![entries[i as usize].clone()],
                )
            })
            .collect();

        let trends = compute_score_trends(&sessions, clock(today));
        assert_eq!(trends.len(), 5);
        // Most recent first: item0 (today), item1 (yesterday), ...
        assert_eq!(trends[0].item_id, "item0");
        assert_eq!(trends[4].item_id, "item4");
    }

    #[test]
    fn test_score_trends_excludes_unscored() {
        // mix of scored and unscored entries
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![make_session(
            "s1",
            today,
            3600,
            vec![
                make_entry("p1", "Sonata", ItemKind::Piece, 1800, Some(4)), // scored
                make_entry("p2", "Etude", ItemKind::Piece, 1800, None),     // unscored
            ],
        )];

        let trends = compute_score_trends(&sessions, clock(today));
        assert_eq!(trends.len(), 1);
        assert_eq!(trends[0].item_id, "p1");
    }

    #[test]
    fn test_score_trends_empty() {
        // sessions with no scored entries
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let sessions = vec![make_session(
            "s1",
            today,
            1800,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, None)],
        )];

        let trends = compute_score_trends(&sessions, clock(today));
        assert!(trends.is_empty());
    }

    // ── Neglected Items Tests ─────────────────────────────────────────

    fn make_item(id: &str, title: &str) -> Item {
        Item {
            id: id.to_string(),
            title: title.to_string(),
            kind: crate::domain::item::ItemKind::Piece,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            linked_exercise_ids: vec![],
            priority: false,
            chord_chart: None,
            variants: vec![],
            photo_id: None,
            metre: None,
        }
    }

    fn neglected(
        sessions: &[PracticeSession],
        items: &[Item],
        clock: LocalClock,
    ) -> Vec<NeglectedItem> {
        compute_neglected_items(
            &crate::app::build_practice_summaries(sessions),
            items,
            clock,
        )
    }

    #[test]
    fn test_neglected_items_basic() {
        // 10 items, 4 practised this week → 6 neglected, capped at 5
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let items: Vec<Item> = (1..=10)
            .map(|i| make_item(&format!("p{i}"), &format!("Item {i}")))
            .collect();

        // Practice 4 items within last 14 days
        let sessions = vec![
            make_session(
                "s1",
                today,
                1800,
                vec![
                    make_entry("p1", "Item 1", ItemKind::Piece, 600, None),
                    make_entry("p2", "Item 2", ItemKind::Piece, 600, None),
                ],
            ),
            make_session(
                "s2",
                today - chrono::Duration::days(5),
                1200,
                vec![
                    make_entry("p3", "Item 3", ItemKind::Piece, 600, None),
                    make_entry("p4", "Item 4", ItemKind::Piece, 600, None),
                ],
            ),
        ];

        let neglected = neglected(&sessions, &items, clock(today));
        assert_eq!(neglected.len(), 5); // capped at 5 out of 6
        for n in &neglected {
            assert!(!["p1", "p2", "p3", "p4"].contains(&n.item_id.as_str()));
        }
    }

    #[test]
    fn test_neglected_items_never_practised_sort_first() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let items = vec![
            make_item("p1", "Old Item"),
            make_item("p2", "Never Practised"),
        ];

        // p1 was practised 20 days ago, p2 never
        let sessions = vec![make_session(
            "s1",
            today - chrono::Duration::days(20),
            600,
            vec![make_entry("p1", "Old Item", ItemKind::Piece, 600, None)],
        )];

        let neglected = neglected(&sessions, &items, clock(today));
        assert_eq!(neglected.len(), 2);
        assert_eq!(neglected[0].item_id, "p2"); // never practised first
        assert!(neglected[0].days_since_practice.is_none());
        assert_eq!(neglected[1].item_id, "p1");
        assert_eq!(neglected[1].days_since_practice, Some(20));
    }

    #[test]
    fn test_neglected_items_ordered_by_days_descending() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let items = vec![
            make_item("p1", "A"),
            make_item("p2", "B"),
            make_item("p3", "C"),
        ];

        let sessions = vec![
            make_session(
                "s1",
                today - chrono::Duration::days(20),
                600,
                vec![make_entry("p1", "A", ItemKind::Piece, 600, None)],
            ),
            make_session(
                "s2",
                today - chrono::Duration::days(30),
                600,
                vec![make_entry("p2", "B", ItemKind::Piece, 600, None)],
            ),
            make_session(
                "s3",
                today - chrono::Duration::days(15),
                600,
                vec![make_entry("p3", "C", ItemKind::Piece, 600, None)],
            ),
        ];

        let neglected = neglected(&sessions, &items, clock(today));
        assert_eq!(neglected.len(), 3);
        assert_eq!(neglected[0].item_id, "p2"); // 30 days
        assert_eq!(neglected[1].item_id, "p1"); // 20 days
        assert_eq!(neglected[2].item_id, "p3"); // 15 days
    }

    #[test]
    fn test_neglected_items_all_recent() {
        // All items practised within 14 days → empty result
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let items = vec![make_item("p1", "A"), make_item("p2", "B")];

        let sessions = vec![make_session(
            "s1",
            today - chrono::Duration::days(5),
            1200,
            vec![
                make_entry("p1", "A", ItemKind::Piece, 600, None),
                make_entry("p2", "B", ItemKind::Piece, 600, None),
            ],
        )];

        let neglected = neglected(&sessions, &items, clock(today));
        assert!(neglected.is_empty());
    }

    #[test]
    fn test_neglected_items_empty_library() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let neglected = neglected(&[], &[], clock(today));
        assert!(neglected.is_empty());
    }

    #[test]
    fn test_neglected_items_deleted_item_not_included() {
        // Item in session but not in current items list → not in neglected
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let items = vec![make_item("p1", "Existing")];

        // Session references p2 which is not in items
        let sessions = vec![make_session(
            "s1",
            today - chrono::Duration::days(20),
            600,
            vec![make_entry("p2", "Deleted", ItemKind::Piece, 600, None)],
        )];

        let neglected = neglected(&sessions, &items, clock(today));
        assert_eq!(neglected.len(), 1);
        assert_eq!(neglected[0].item_id, "p1"); // only existing item
        assert!(neglected[0].days_since_practice.is_none()); // never practised
    }

    /// The flat 14-day cut is gone (#1416): one gap, two verdicts.
    #[test]
    fn neglected_grades_the_gap_against_the_items_own_history() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let gap = today - chrono::Duration::days(13);
        let items = vec![make_item("p1", "Half-learned"), make_item("p2", "Solid")];

        let mut sessions = vec![make_session(
            "s1",
            gap,
            600,
            vec![make_entry("p1", "Half-learned", ItemKind::Piece, 600, None)],
        )];
        for i in 0..12 {
            sessions.push(make_session(
                &format!("s{}", i + 2),
                gap - chrono::Duration::days(i as i64),
                600,
                vec![make_entry("p2", "Solid", ItemKind::Piece, 600, Some(9))],
            ));
        }

        let neglected = neglected(&sessions, &items, clock(today));
        assert_eq!(neglected.len(), 1);
        assert_eq!(neglected[0].item_id, "p1");
        assert_eq!(neglected[0].days_since_practice, Some(13));
    }

    #[test]
    fn neglected_breaks_a_tie_on_the_id_not_the_library_order() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let items = vec![make_item("zeta", "Zortziko"), make_item("alpha", "Aria")];

        let rows = neglected(&[], &items, clock(today));
        let ids: Vec<&str> = rows.iter().map(|n| n.item_id.as_str()).collect();

        assert_eq!(ids, vec!["alpha", "zeta"]);
    }

    #[test]
    fn neglected_reports_the_gap_it_measured() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let items = vec![make_item("p1", "Old")];

        let sessions = vec![make_session(
            "s1",
            today - chrono::Duration::days(40),
            600,
            vec![make_entry("p1", "Old", ItemKind::Piece, 600, None)],
        )];

        let neglected = neglected(&sessions, &items, clock(today));
        assert_eq!(neglected.len(), 1);
        assert_eq!(neglected[0].item_id, "p1");
        assert_eq!(neglected[0].days_since_practice, Some(40));
    }

    // ── Score Changes Tests ───────────────────────────────────────────

    #[test]
    fn test_score_changes_improvement() {
        // Item scored 2 last week, 4 this week → delta +2
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap(); // Wed, week 8
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap(); // Wed, week 7

        let sessions = vec![
            make_session(
                "s1",
                last_wed,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(2))],
            ),
            make_session(
                "s2",
                today,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(4))],
            ),
        ];

        let changes = compute_score_changes(&sessions, clock(today));
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].item_id, "p1");
        assert_eq!(changes[0].previous_score, Some(2));
        assert_eq!(changes[0].current_score, 4);
        assert_eq!(changes[0].delta, 2);
        assert!(!changes[0].is_new);
    }

    #[test]
    fn test_score_changes_decrease() {
        // Item scored 4 last week, 3 this week → delta -1
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap();

        let sessions = vec![
            make_session(
                "s1",
                last_wed,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(4))],
            ),
            make_session(
                "s2",
                today,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(3))],
            ),
        ];

        let changes = compute_score_changes(&sessions, clock(today));
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].delta, -1);
    }

    #[test]
    fn test_score_changes_newly_scored() {
        // Item scored for first time this week
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();

        let sessions = vec![make_session(
            "s1",
            today,
            600,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(3))],
        )];

        let changes = compute_score_changes(&sessions, clock(today));
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].previous_score, None);
        assert_eq!(changes[0].current_score, 3);
        assert_eq!(changes[0].delta, 0);
        assert!(changes[0].is_new);
    }

    #[test]
    fn test_score_changes_empty() {
        // No items scored this week
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap();

        let sessions = vec![make_session(
            "s1",
            last_wed,
            600,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(3))],
        )];

        let changes = compute_score_changes(&sessions, clock(today));
        assert!(changes.is_empty());
    }

    #[test]
    fn test_score_changes_capped_at_5() {
        // More than 5 score changes → capped at 5, sorted by largest absolute delta
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap();

        let mut last_entries = Vec::new();
        let mut this_entries = Vec::new();
        for i in 1..=7 {
            last_entries.push(make_entry(
                &format!("p{i}"),
                &format!("Item {i}"),
                ItemKind::Piece,
                600,
                Some(1),
            ));
            this_entries.push(make_entry(
                &format!("p{i}"),
                &format!("Item {i}"),
                ItemKind::Piece,
                600,
                Some(1 + i as u8), // deltas: 1,2,3,4,5,6,7
            ));
        }

        let sessions = vec![
            make_session("s1", last_wed, 4200, last_entries),
            make_session("s2", today, 4200, this_entries),
        ];

        let changes = compute_score_changes(&sessions, clock(today));
        assert_eq!(changes.len(), 5);
        // Should be sorted by largest absolute delta
        assert!(changes[0].delta.unsigned_abs() >= changes[1].delta.unsigned_abs());
    }

    #[test]
    fn test_score_changes_ties_break_by_item_id() {
        // 3 items tied on |delta| → order is deterministic (item_id asc), not
        // whatever order the underlying HashMap happened to iterate in.
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap();

        let last_entries = vec![
            make_entry("zeta", "Zeta", ItemKind::Piece, 600, Some(3)),
            make_entry("alpha", "Alpha", ItemKind::Piece, 600, Some(3)),
            make_entry("mid", "Mid", ItemKind::Piece, 600, Some(3)),
        ];
        let this_entries = vec![
            make_entry("zeta", "Zeta", ItemKind::Piece, 600, Some(5)),
            make_entry("alpha", "Alpha", ItemKind::Piece, 600, Some(5)),
            make_entry("mid", "Mid", ItemKind::Piece, 600, Some(5)),
        ];

        let sessions = vec![
            make_session("s1", last_wed, 1800, last_entries),
            make_session("s2", today, 1800, this_entries),
        ];

        let changes = compute_score_changes(&sessions, clock(today));
        let ids: Vec<&str> = changes.iter().map(|c| c.item_id.as_str()).collect();
        assert_eq!(ids, vec!["alpha", "mid", "zeta"]);
    }

    #[test]
    fn test_score_changes_latest_score_this_week() {
        // Item scored multiple times this week → uses latest
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let mon = NaiveDate::from_ymd_opt(2026, 2, 16).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap();

        let sessions = vec![
            make_session(
                "s1",
                last_wed,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(2))],
            ),
            make_session(
                "s2",
                mon,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(3))],
            ),
            make_session(
                "s3",
                today,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(5))],
            ),
        ];

        let changes = compute_score_changes(&sessions, clock(today));
        assert_eq!(changes.len(), 1);
        assert_eq!(changes[0].current_score, 5); // latest this week
        assert_eq!(changes[0].previous_score, Some(2));
        assert_eq!(changes[0].delta, 3);
    }

    #[test]
    fn test_score_changes_same_score_excluded() {
        // Item scored same as last week → not included
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let last_wed = NaiveDate::from_ymd_opt(2026, 2, 11).unwrap();

        let sessions = vec![
            make_session(
                "s1",
                last_wed,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(3))],
            ),
            make_session(
                "s2",
                today,
                600,
                vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(3))],
            ),
        ];

        let changes = compute_score_changes(&sessions, clock(today));
        assert!(changes.is_empty());
    }

    // ── Integration: compute_analytics ───────────────────────────────

    #[test]
    fn test_compute_analytics_populates_all_fields() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let sessions = vec![make_session(
            "s1",
            today,
            1800,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 1800, Some(4))],
        )];

        let analytics = compute_analytics(
            &sessions,
            &[],
            &crate::app::build_practice_summaries(&sessions),
            clock(today),
        );
        assert_eq!(analytics.weekly_summary.session_count, 1);
        assert_eq!(analytics.streak.current_days, 1);
        assert_eq!(analytics.daily_totals.len(), 28);
        assert_eq!(analytics.top_items.len(), 1);
        assert_eq!(analytics.score_trends.len(), 1);
    }

    // ── Edge case: ended-early sessions included ──────────────────────

    #[test]
    fn test_ended_early_sessions_included() {
        let today = NaiveDate::from_ymd_opt(2026, 2, 18).unwrap();
        let started = Utc.from_utc_datetime(&today.and_hms_opt(10, 0, 0).unwrap());

        let sessions = vec![PracticeSession {
            id: "s1".to_string(),
            started_at: started,
            completed_at: started + chrono::Duration::seconds(600),
            total_duration_secs: 600,
            completion_status: CompletionStatus::EndedEarly,
            session_notes: None,
            entries: vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(3))],
            session_score: None,
        }];

        let analytics = compute_analytics(
            &sessions,
            &[],
            &crate::app::build_practice_summaries(&sessions),
            clock(today),
        );
        assert_eq!(analytics.weekly_summary.session_count, 1);
        assert_eq!(analytics.weekly_summary.total_minutes, 10);
        assert_eq!(analytics.streak.current_days, 1);
        assert_eq!(analytics.top_items.len(), 1);
        assert_eq!(analytics.score_trends.len(), 1);
    }

    // ── Local day boundary (#1330) ───────────────────────────────────
    // A session at 00:30 BST is 23:30 UTC the previous day; the user's day,
    // not the UTC day, must drive every date attribution.

    fn bst_clock(today: NaiveDate) -> LocalClock {
        LocalClock {
            today,
            utc_offset_minutes: 60,
        }
    }

    fn utc_instant(y: i32, m: u32, d: u32, h: u32, min: u32) -> chrono::DateTime<Utc> {
        Utc.with_ymd_and_hms(y, m, d, h, min, 0).unwrap()
    }

    #[test]
    fn day_of_rolls_forward_across_local_midnight() {
        let c = bst_clock(NaiveDate::from_ymd_opt(2026, 8, 14).unwrap());
        assert_eq!(
            c.day_of(utc_instant(2026, 8, 13, 23, 30)),
            NaiveDate::from_ymd_opt(2026, 8, 14).unwrap()
        );
    }

    #[test]
    fn day_of_negative_offset_rolls_back_a_day() {
        let c = LocalClock {
            today: NaiveDate::from_ymd_opt(2026, 8, 13).unwrap(),
            utc_offset_minutes: -300,
        };
        assert_eq!(
            c.day_of(utc_instant(2026, 8, 14, 1, 30)),
            NaiveDate::from_ymd_opt(2026, 8, 13).unwrap()
        );
    }

    #[test]
    fn hour_of_is_the_local_hour_either_side_of_midnight() {
        let bst = bst_clock(NaiveDate::from_ymd_opt(2026, 8, 14).unwrap());
        assert_eq!(bst.hour_of(utc_instant(2026, 8, 13, 23, 30)), 0);
        assert_eq!(bst.hour_of(utc_instant(2026, 8, 13, 10, 59)), 11);
        assert_eq!(bst.hour_of(utc_instant(2026, 8, 13, 11, 0)), 12);
        let utc_minus_five = LocalClock {
            today: NaiveDate::from_ymd_opt(2026, 8, 13).unwrap(),
            utc_offset_minutes: -300,
        };
        assert_eq!(utc_minus_five.hour_of(utc_instant(2026, 8, 14, 3, 59)), 22);
    }

    #[test]
    fn from_now_derives_local_today() {
        let c = LocalClock::from_now(utc_instant(2026, 8, 13, 23, 30), 60);
        assert_eq!(c.today, NaiveDate::from_ymd_opt(2026, 8, 14).unwrap());
        assert_eq!(c.utc_offset_minutes, 60);
    }

    #[test]
    fn daily_totals_attribute_midnight_window_session_to_local_day() {
        let sessions = vec![make_session_at(
            "s1",
            utc_instant(2026, 8, 13, 23, 30),
            1200,
            vec![],
        )];
        let totals = compute_daily_totals(
            &sessions,
            bst_clock(NaiveDate::from_ymd_opt(2026, 8, 14).unwrap()),
        );

        let minutes_on = |date: &str| {
            totals
                .iter()
                .find(|t| t.date == date)
                .map(|t| t.minutes)
                .expect("day in 28-day window")
        };
        assert_eq!(minutes_on("2026-08-14"), 20);
        assert_eq!(minutes_on("2026-08-13"), 0);
    }

    #[test]
    fn streak_bridges_via_midnight_window_session() {
        let sessions = vec![
            make_session_at("s1", utc_instant(2026, 8, 12, 23, 30), 600, vec![]),
            make_session_at("s2", utc_instant(2026, 8, 14, 10, 0), 600, vec![]),
        ];
        let streak = compute_streak(
            &sessions,
            bst_clock(NaiveDate::from_ymd_opt(2026, 8, 14).unwrap()),
        );
        // Locally the sessions fall on Aug 13 and Aug 14: a 2-day streak.
        // UTC attribution would put the first on Aug 12 and break it at 1.
        assert_eq!(streak.current_days, 2);
    }

    #[test]
    fn weekly_summary_counts_sunday_midnight_window_in_new_week() {
        // Sunday 23:30 UTC = Monday 00:30 BST: the session belongs to the
        // new ISO week, not the one that just ended.
        let sessions = vec![make_session_at(
            "s1",
            utc_instant(2026, 8, 9, 23, 30),
            1800,
            vec![],
        )];
        let summary = compute_weekly_summary(
            &sessions,
            bst_clock(NaiveDate::from_ymd_opt(2026, 8, 10).unwrap()),
        );
        assert_eq!(summary.session_count, 1);
        assert_eq!(summary.prev_session_count, 0);
    }

    #[test]
    fn score_changes_use_local_week() {
        let sessions = vec![make_session_at(
            "s1",
            utc_instant(2026, 8, 9, 23, 30),
            600,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(5))],
        )];
        let changes = compute_score_changes(
            &sessions,
            bst_clock(NaiveDate::from_ymd_opt(2026, 8, 10).unwrap()),
        );
        assert_eq!(changes.len(), 1);
        assert!(changes[0].is_new);
    }

    #[test]
    fn neglected_gap_is_counted_in_local_days() {
        // The UTC instant falls on Jul 31, but locally it is Aug 1.
        let items = vec![make_item("p1", "Sonata")];
        let sessions = vec![make_session_at(
            "s1",
            utc_instant(2026, 7, 31, 23, 30),
            600,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, None)],
        )];
        let neglected = neglected(
            &sessions,
            &items,
            bst_clock(NaiveDate::from_ymd_opt(2026, 8, 14).unwrap()),
        );
        assert_eq!(neglected[0].days_since_practice, Some(13));
    }

    #[test]
    fn score_trend_dates_use_local_day() {
        let sessions = vec![make_session_at(
            "s1",
            utc_instant(2026, 8, 13, 23, 30),
            600,
            vec![make_entry("p1", "Sonata", ItemKind::Piece, 600, Some(6))],
        )];
        let trends = compute_score_trends(
            &sessions,
            bst_clock(NaiveDate::from_ymd_opt(2026, 8, 14).unwrap()),
        );
        assert_eq!(trends[0].scores[0].date, "2026-08-14");
    }

    // ── Last practised ───────────────────────────────────────────────

    fn day(y: i32, m: u32, d: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(y, m, d).unwrap()
    }

    #[test]
    fn last_practised_is_none_without_sessions() {
        assert_eq!(compute_last_practised(&[], clock(day(2026, 8, 14))), None);
    }

    #[test]
    fn last_practised_reads_the_most_recent_session() {
        // Newest first, so list order can't stand in for comparing the dates.
        let sessions = vec![
            make_session(
                "newer",
                day(2026, 8, 11),
                600,
                vec![make_entry(
                    "p2",
                    "Clair de Lune",
                    ItemKind::Piece,
                    600,
                    None,
                )],
            ),
            make_session(
                "older",
                day(2026, 8, 10),
                600,
                vec![make_entry(
                    "p1",
                    "Nocturne Op. 9",
                    ItemKind::Piece,
                    600,
                    None,
                )],
            ),
        ];
        let last = compute_last_practised(&sessions, clock(day(2026, 8, 14))).unwrap();
        assert_eq!(last.item_title, "Clair de Lune");
    }

    #[test]
    fn last_practised_headlines_the_longest_entry_not_the_first() {
        let sessions = vec![make_session(
            "s1",
            day(2026, 8, 11),
            1_500,
            vec![
                make_entry("e1", "Major scales", ItemKind::Exercise, 300, None),
                make_entry("p1", "Clair de Lune", ItemKind::Piece, 1_200, None),
            ],
        )];
        let last = compute_last_practised(&sessions, clock(day(2026, 8, 14))).unwrap();
        assert_eq!(last.item_title, "Clair de Lune");
    }

    #[test]
    fn last_practised_breaks_a_duration_tie_on_position() {
        // make_entry positions everything at 0, so pin them for this one.
        let mut first = make_entry("e1", "Major scales", ItemKind::Exercise, 300, None);
        first.position = 0;
        let mut second = make_entry("p1", "Clair de Lune", ItemKind::Piece, 300, None);
        second.position = 1;
        let sessions = vec![make_session(
            "s1",
            day(2026, 8, 11),
            600,
            vec![first, second],
        )];
        let last = compute_last_practised(&sessions, clock(day(2026, 8, 14))).unwrap();
        assert_eq!(last.item_title, "Major scales");
    }

    #[test]
    fn last_practised_skips_a_session_with_no_entries() {
        let sessions = vec![
            make_session(
                "played",
                day(2026, 8, 10),
                600,
                vec![make_entry(
                    "p1",
                    "Clair de Lune",
                    ItemKind::Piece,
                    600,
                    None,
                )],
            ),
            make_session("empty", day(2026, 8, 12), 0, vec![]),
        ];
        let last = compute_last_practised(&sessions, clock(day(2026, 8, 14))).unwrap();
        assert_eq!(last.item_title, "Clair de Lune");
    }

    #[test]
    fn last_practised_day_reads_relative_within_the_week() {
        let today = day(2026, 8, 14); // a Friday
        let cases = [
            (day(2026, 8, 14), "Today", "Last practised today"),
            (day(2026, 8, 13), "Yesterday", "Last practised yesterday"),
            (day(2026, 8, 11), "Tuesday", "Last practised Tuesday"),
            (day(2026, 8, 8), "Saturday", "Last practised Saturday"),
            // 7 days back repeats today's weekday, so it falls to a date.
            (day(2026, 8, 7), "7 Aug", "Last practised 7 Aug"),
            (
                day(2025, 12, 31),
                "31 Dec 2025",
                "Last practised 31 Dec 2025",
            ),
            // Clock skew, or the stored offset moving: a date reads oddly but
            // is honest, where "Today" for tomorrow would be a lie.
            (day(2026, 8, 15), "15 Aug", "Last practised 15 Aug"),
        ];
        for (session_day, relative, label) in cases {
            let sessions = vec![make_session(
                "s1",
                session_day,
                600,
                vec![make_entry(
                    "p1",
                    "Clair de Lune",
                    ItemKind::Piece,
                    600,
                    None,
                )],
            )];
            let last = compute_last_practised(&sessions, clock(today)).unwrap();
            assert_eq!(last.relative_day, relative, "for {session_day}");
            assert_eq!(last.label, label, "for {session_day}");
        }
    }

    #[test]
    fn last_practised_day_turns_over_on_the_users_clock() {
        // 23:30 UTC on the 13th is 00:30 local on the 14th (#1330).
        let sessions = vec![make_session_at(
            "s1",
            utc_instant(2026, 8, 13, 23, 30),
            600,
            vec![make_entry(
                "p1",
                "Clair de Lune",
                ItemKind::Piece,
                600,
                None,
            )],
        )];
        let last = compute_last_practised(&sessions, bst_clock(day(2026, 8, 14))).unwrap();
        assert_eq!(last.relative_day, "Today");
    }
}
