use std::collections::HashMap;

use chrono::{DateTime, Utc};
use libsql::Connection;
use serde::{Deserialize, Serialize};

use intrada_core::domain::item::ItemKind;
use intrada_core::domain::session::{
    CompletionStatus, EntryStatus, PracticeSession, RepAction, RepEvent, SetlistEntry,
    VariationPlay,
};

use super::{col, item_kind_from_str, item_kind_to_str};
use crate::error::ApiError;

/// Request body for saving a new practice session.
/// Like PracticeSession but without `id` (server generates it).
/// Entry IDs come from the client.
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SaveSessionRequest {
    pub entries: Vec<SaveSessionEntry>,
    pub session_notes: Option<String>,
    pub started_at: DateTime<Utc>,
    pub completed_at: DateTime<Utc>,
    pub total_duration_secs: u64,
    pub completion_status: CompletionStatus,
    #[serde(default)]
    pub session_intention: Option<String>,
}

/// Entry within a SaveSessionRequest.
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SaveSessionEntry {
    pub id: String,
    pub item_id: String,
    pub item_title: String,
    pub item_type: ItemKind,
    pub position: usize,
    pub duration_secs: u64,
    pub status: EntryStatus,
    pub notes: Option<String>,
    #[serde(default)]
    pub score: Option<u8>,
    #[serde(default)]
    pub intention: Option<String>,
    #[serde(default)]
    pub rep_target: Option<u8>,
    #[serde(default)]
    pub rep_count: Option<u8>,
    #[serde(default)]
    pub rep_target_reached: Option<bool>,
    #[serde(default)]
    pub rep_history: Option<Vec<RepEvent>>,
    #[serde(default)]
    pub planned_duration_secs: Option<u32>,
    #[serde(default)]
    pub achieved_tempo: Option<u16>,
}

fn completion_status_to_str(status: &CompletionStatus) -> &'static str {
    match status {
        CompletionStatus::Completed => "Completed",
        CompletionStatus::EndedEarly => "EndedEarly",
    }
}

fn completion_status_from_str(s: &str) -> Result<CompletionStatus, ApiError> {
    match s {
        "Completed" => Ok(CompletionStatus::Completed),
        "EndedEarly" => Ok(CompletionStatus::EndedEarly),
        other => Err(ApiError::Internal(format!(
            "Invalid completion_status: {other}"
        ))),
    }
}

fn entry_status_to_str(status: &EntryStatus) -> &'static str {
    match status {
        EntryStatus::Completed => "Completed",
        EntryStatus::Skipped => "Skipped",
        EntryStatus::NotAttempted => "NotAttempted",
    }
}

fn entry_status_from_str(s: &str) -> Result<EntryStatus, ApiError> {
    match s {
        "Completed" => Ok(EntryStatus::Completed),
        "Skipped" => Ok(EntryStatus::Skipped),
        "NotAttempted" => Ok(EntryStatus::NotAttempted),
        other => Err(ApiError::Internal(format!("Invalid entry_status: {other}"))),
    }
}

/// The column holds three generations: `RepEvent` objects, bare action strings
/// (`["Missed"]`) and `serde_repr` integers (`[-1, 1]`). The older two carry no
/// time, so they take `fallback_at`, the session start: honest for every tap.
fn parse_rep_history(
    json_str: &str,
    fallback_at: DateTime<Utc>,
) -> Result<Vec<RepEvent>, ApiError> {
    if let Ok(events) = serde_json::from_str::<Vec<RepEvent>>(json_str) {
        return Ok(events);
    }
    let at_fallback = |action| RepEvent {
        action,
        at: fallback_at,
    };
    if let Ok(actions) = serde_json::from_str::<Vec<RepAction>>(json_str) {
        return Ok(actions.into_iter().map(at_fallback).collect());
    }

    let integers: Vec<i8> = serde_json::from_str(json_str)
        .map_err(|e| ApiError::Internal(format!("Invalid rep_history JSON: {e}")))?;
    integers
        .into_iter()
        .map(|v| match v {
            -1 => Ok(at_fallback(RepAction::Missed)),
            1 => Ok(at_fallback(RepAction::Success)),
            other => Err(ApiError::Internal(format!(
                "Invalid legacy rep_history value: {other}"
            ))),
        })
        .collect()
}

/// Column list for setlist_entries SELECT queries.
const ENTRY_COLUMNS: &str = "id, item_id, item_title, item_type, position, duration_secs, status, notes, score, intention, rep_target, rep_count, rep_target_reached, rep_history, planned_duration_secs, achieved_tempo";

/// Subquery to select session IDs for a user. Shared between the parent query
/// and the batch entry query so filter clauses stay in sync (#152).
const SESSION_IDS_FOR_USER: &str = "SELECT id FROM sessions WHERE user_id = ?1";

/// The server stores one column set per entry, so it round-trips as the single
/// play a client would have recorded. An entry that was neither practised nor
/// recorded anything gets no play, which is what a skipped entry means (#1739
/// decision 3). A skipped entry that banked repetitions keeps one, the same rule
/// the shell's fold applies, so the two cannot drift.
fn single_play(entry: &SaveSessionEntry, session_started_at: DateTime<Utc>) -> Vec<VariationPlay> {
    let recorded = entry.score.is_some() || entry.rep_count.unwrap_or(0) > 0;
    if entry.status != EntryStatus::Completed && !recorded {
        return Vec::new();
    }

    vec![VariationPlay {
        id: format!("{}-play", entry.id),
        variation_id: None,
        started_at: session_started_at,
        seconds: entry.duration_secs,
        rep_target: entry.rep_target,
        rep_count: entry.rep_count,
        rep_target_reached: entry.rep_target_reached,
        rep_history: entry.rep_history.clone(),
        achieved_tempo: entry.achieved_tempo,
        click_pattern: None,
        score: entry.score,
    }]
}

/// Parse an entry row into a SetlistEntry (columns 0–14 matching [`ENTRY_COLUMNS`]).
fn row_to_entry(
    row: &libsql::Row,
    session_started_at: DateTime<Utc>,
) -> Result<SetlistEntry, ApiError> {
    let id: String = col!(row, 0)?;
    let item_id: String = col!(row, 1)?;
    let item_title: String = col!(row, 2)?;
    let item_type_str: String = col!(row, 3)?;
    let item_type = item_kind_from_str(&item_type_str)?;
    let position: i64 = col!(row, 4)?;
    let duration_secs: i64 = col!(row, 5)?;
    let status_str: String = col!(row, 6)?;
    let notes: Option<String> = col!(row, 7)?;
    let score: Option<i64> = col!(row, 8)?;
    let intention: Option<String> = col!(row, 9)?;
    let rep_target: Option<i64> = col!(row, 10)?;
    let rep_count: Option<i64> = col!(row, 11)?;
    let rep_target_reached: Option<i64> = col!(row, 12)?;
    let rep_history_raw: Option<String> = col!(row, 13)?;
    let rep_history = match rep_history_raw {
        Some(json_str) => Some(parse_rep_history(&json_str, session_started_at)?),
        None => None,
    };
    let planned_duration_secs_raw: Option<i64> = col!(row, 14)?;
    let planned_duration_secs = planned_duration_secs_raw.map(|v| v as u32);
    let achieved_tempo_raw: Option<i64> = col!(row, 15)?;
    let achieved_tempo = achieved_tempo_raw.map(|v| v as u16);

    // The server's columns are one set per entry, so they fold into the single
    // play the client would have recorded. An entry neither practised nor
    // carrying a mark or a repetition keeps none, which is what a zero-play
    // entry means (#1739 decision 3). Same rule as `single_play` and as the
    // shell's fold, so none of the three can drift.
    let status = entry_status_from_str(&status_str)?;
    let recorded = score.is_some() || rep_count.unwrap_or(0) > 0;
    let plays = if status == EntryStatus::Completed || recorded {
        vec![VariationPlay {
            id: format!("{id}-play"),
            variation_id: None,
            started_at: session_started_at,
            seconds: duration_secs as u64,
            rep_target: rep_target.map(|v| v as u8),
            rep_count: rep_count.map(|v| v as u8),
            rep_target_reached: rep_target_reached.map(|v| v != 0),
            rep_history,
            achieved_tempo,
            click_pattern: None,
            score: score.map(|s| s as u8),
        }]
    } else {
        Vec::new()
    };

    Ok(SetlistEntry {
        id,
        item_id,
        item_title,
        item_type,
        position: position as usize,
        duration_secs: duration_secs as u64,
        status,
        notes,
        intention,
        planned_duration_secs,
        group_id: None,
        planned_variation_id: None,
        planned_rep_target: None,
        plays,
    })
}

/// Fetch entries for a session, ordered by position.
async fn fetch_entries(
    conn: &Connection,
    session_id: &str,
    session_started_at: DateTime<Utc>,
) -> Result<Vec<SetlistEntry>, ApiError> {
    let mut rows = conn
        .query(
            &format!(
                "SELECT {ENTRY_COLUMNS} FROM setlist_entries WHERE session_id = ?1 ORDER BY position ASC"
            ),
            libsql::params![session_id],
        )
        .await?;

    let mut entries = Vec::new();
    while let Some(row) = rows
        .next()
        .await
        .map_err(|e| ApiError::Internal(e.to_string()))?
    {
        entries.push(row_to_entry(&row, session_started_at)?);
    }
    Ok(entries)
}

/// Parse a session row (without entries) into partial PracticeSession fields.
///
/// Expects columns: id, session_notes, started_at, completed_at,
///   total_duration_secs, completion_status, session_intention
fn row_to_session_without_entries(row: &libsql::Row) -> Result<PracticeSession, ApiError> {
    let id: String = col!(row, 0)?;
    let session_notes: Option<String> = col!(row, 1)?;
    let started_at_str: String = col!(row, 2)?;
    let completed_at_str: String = col!(row, 3)?;
    let total_duration_secs: i64 = col!(row, 4)?;
    let completion_status_str: String = col!(row, 5)?;
    let session_intention: Option<String> = col!(row, 6)?;

    let started_at: DateTime<Utc> = started_at_str
        .parse()
        .map_err(|e| ApiError::Internal(format!("Invalid started_at: {e}")))?;
    let completed_at: DateTime<Utc> = completed_at_str
        .parse()
        .map_err(|e| ApiError::Internal(format!("Invalid completed_at: {e}")))?;

    Ok(PracticeSession {
        id,
        entries: vec![], // filled separately
        session_notes,
        started_at,
        completed_at,
        total_duration_secs: total_duration_secs as u64,
        completion_status: completion_status_from_str(&completion_status_str)?,
        session_intention,
        session_score: None,
        reflection_improved: None,
        reflection_still_rough: None,
        reflection_next_target: None,
    })
}

pub async fn list_sessions(
    conn: &Connection,
    user_id: &str,
) -> Result<Vec<PracticeSession>, ApiError> {
    // Query 1: all sessions for this user.
    let mut rows = conn
        .query(
            "SELECT id, session_notes, started_at, completed_at,
                    total_duration_secs, completion_status, session_intention
             FROM sessions WHERE user_id = ?1
             ORDER BY started_at DESC",
            libsql::params![user_id],
        )
        .await?;

    let mut sessions: Vec<PracticeSession> = Vec::new();
    while let Some(row) = rows
        .next()
        .await
        .map_err(|e| ApiError::Internal(e.to_string()))?
    {
        sessions.push(row_to_session_without_entries(&row)?);
    }

    if sessions.is_empty() {
        return Ok(sessions);
    }

    // Query 2: all entries for those sessions in one batch.
    // session_id is appended after ENTRY_COLUMNS so row_to_entry reads columns 0–14.
    let mut entry_rows = conn
        .query(
            &format!(
                "SELECT {ENTRY_COLUMNS}, session_id FROM setlist_entries
                 WHERE session_id IN ({SESSION_IDS_FOR_USER})
                 ORDER BY session_id, position ASC"
            ),
            libsql::params![user_id],
        )
        .await?;

    let started_at_by_session: HashMap<&str, DateTime<Utc>> = sessions
        .iter()
        .map(|s| (s.id.as_str(), s.started_at))
        .collect();
    let mut entries_by_session: HashMap<String, Vec<SetlistEntry>> = HashMap::new();
    while let Some(row) = entry_rows
        .next()
        .await
        .map_err(|e| ApiError::Internal(e.to_string()))?
    {
        let session_id: String = col!(row, 16)?;
        let Some(&started_at) = started_at_by_session.get(session_id.as_str()) else {
            return Err(ApiError::Internal(format!(
                "entry row for unknown session {session_id}"
            )));
        };
        let entry = row_to_entry(&row, started_at)?;
        entries_by_session
            .entry(session_id)
            .or_default()
            .push(entry);
    }

    for session in &mut sessions {
        if let Some(entries) = entries_by_session.remove(&session.id) {
            session.entries = entries;
        }
    }

    Ok(sessions)
}

pub async fn get_session(
    conn: &Connection,
    id: &str,
    user_id: &str,
) -> Result<Option<PracticeSession>, ApiError> {
    let mut rows = conn
        .query(
            "SELECT id, session_notes, started_at, completed_at, total_duration_secs, completion_status, session_intention
             FROM sessions WHERE id = ?1 AND user_id = ?2",
            libsql::params![id, user_id],
        )
        .await?;

    match rows
        .next()
        .await
        .map_err(|e| ApiError::Internal(e.to_string()))?
    {
        Some(row) => {
            let mut session = row_to_session_without_entries(&row)?;
            session.entries = fetch_entries(conn, &session.id, session.started_at).await?;
            Ok(Some(session))
        }
        None => Ok(None),
    }
}

pub async fn insert_session(
    conn: &Connection,
    user_id: &str,
    input: &SaveSessionRequest,
) -> Result<PracticeSession, ApiError> {
    let id = ulid::Ulid::generate().to_string();

    let started_at_str = input.started_at.to_rfc3339();
    let completed_at_str = input.completed_at.to_rfc3339();
    let completion_status_str = completion_status_to_str(&input.completion_status);

    // Use a transaction to insert session + entries atomically
    conn.execute("BEGIN", ()).await?;

    let result: Result<PracticeSession, ApiError> = async {
        // Insert session row
        conn.execute(
            "INSERT INTO sessions (id, session_notes, started_at, completed_at, total_duration_secs, completion_status, user_id, session_intention)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            libsql::params![
                id.as_str(),
                input.session_notes.as_deref(),
                started_at_str.as_str(),
                completed_at_str.as_str(),
                input.total_duration_secs as i64,
                completion_status_str,
                user_id,
                input.session_intention.as_deref()
            ],
        )
        .await?;

        // Insert each setlist entry
        let mut entries = Vec::with_capacity(input.entries.len());
        for entry in &input.entries {
            let status_str = entry_status_to_str(&entry.status);
            // The wire shape stays one column set per entry: plays are
            // local-first until the sync engine, as `variant_id` and `group_id`
            // are (#1739, invariant 6 consciously scoped).
            let score_val: Option<i64> = entry.score.map(|s| s as i64);
            let rep_target_val: Option<i64> = entry.rep_target.map(|v| v as i64);
            let rep_count_val: Option<i64> = entry.rep_count.map(|v| v as i64);
            let rep_target_reached_val: Option<i64> =
                entry.rep_target_reached.map(|v| if v { 1 } else { 0 });
            let rep_history_json: Option<String> = entry
                .rep_history
                .as_ref()
                .map(serde_json::to_string)
                .transpose()
                .map_err(|e| ApiError::Internal(format!("Failed to serialise rep_history: {e}")))?;
            let planned_duration_secs_val: Option<i64> =
                entry.planned_duration_secs.map(|v| v as i64);
            let achieved_tempo_val: Option<i64> = entry.achieved_tempo.map(|v| v as i64);
            conn.execute(
                "INSERT INTO setlist_entries (id, session_id, item_id, item_title, item_type, position, duration_secs, status, notes, score, intention, rep_target, rep_count, rep_target_reached, rep_history, planned_duration_secs, achieved_tempo)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17)",
                libsql::params![
                    entry.id.as_str(),
                    id.as_str(),
                    entry.item_id.as_str(),
                    entry.item_title.as_str(),
                    item_kind_to_str(&entry.item_type),
                    entry.position as i64,
                    entry.duration_secs as i64,
                    status_str,
                    entry.notes.as_deref(),
                    score_val,
                    entry.intention.as_deref(),
                    rep_target_val,
                    rep_count_val,
                    rep_target_reached_val,
                    rep_history_json.as_deref(),
                    planned_duration_secs_val,
                    achieved_tempo_val
                ],
            )
            .await?;

            entries.push(SetlistEntry {
                id: entry.id.clone(),
                item_id: entry.item_id.clone(),
                item_title: entry.item_title.clone(),
                item_type: entry.item_type.clone(),
                position: entry.position,
                duration_secs: entry.duration_secs,
                status: entry.status.clone(),
                notes: entry.notes.clone(),
                intention: entry.intention.clone(),
                planned_duration_secs: entry.planned_duration_secs,
                group_id: None,
                planned_variation_id: None,
                planned_rep_target: None,
                plays: single_play(entry, input.started_at),
            });
        }

        Ok(PracticeSession {
            id: id.clone(),
            entries,
            session_notes: input.session_notes.clone(),
            started_at: input.started_at,
            completed_at: input.completed_at,
            total_duration_secs: input.total_duration_secs,
            completion_status: input.completion_status.clone(),
            session_intention: input.session_intention.clone(),
            session_score: None,
            reflection_improved: None,
            reflection_still_rough: None,
            reflection_next_target: None,
        })
    }
    .await;

    match result {
        Ok(session) => {
            conn.execute("COMMIT", ()).await?;
            Ok(session)
        }
        Err(e) => {
            let _ = conn.execute("ROLLBACK", ()).await;
            Err(e)
        }
    }
}

pub async fn delete_session(conn: &Connection, id: &str, user_id: &str) -> Result<bool, ApiError> {
    // Verify ownership first — only delete entries if the session belongs to this user.
    let rows_affected = conn
        .execute(
            "DELETE FROM sessions WHERE id = ?1 AND user_id = ?2",
            libsql::params![id, user_id],
        )
        .await?;

    if rows_affected == 0 {
        return Ok(false);
    }

    // Explicit child-row delete — FK cascade is disabled (Turso compatibility),
    // so application code owns the cleanup.
    conn.execute(
        "DELETE FROM setlist_entries WHERE session_id = ?1",
        libsql::params![id],
    )
    .await?;

    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn started() -> DateTime<Utc> {
        "2026-09-03T08:47:00Z".parse().expect("fixed")
    }

    #[test]
    fn timestamped_events_parse_with_their_own_times() {
        let at: DateTime<Utc> = "2026-09-03T09:00:00Z".parse().expect("fixed");
        let json = serde_json::to_string(&vec![RepEvent {
            action: RepAction::Missed,
            at,
        }])
        .expect("serialise");
        let parsed = parse_rep_history(&json, started()).expect("parse");
        assert_eq!(
            parsed,
            vec![RepEvent {
                action: RepAction::Missed,
                at
            }]
        );
    }

    #[test]
    fn bare_action_strings_take_the_session_start() {
        let parsed = parse_rep_history(r#"["Success","Missed"]"#, started()).expect("parse");
        assert_eq!(
            parsed.iter().map(|e| e.action).collect::<Vec<_>>(),
            vec![RepAction::Success, RepAction::Missed]
        );
        assert!(parsed.iter().all(|e| e.at == started()));
    }

    #[test]
    fn serde_repr_integers_take_the_session_start() {
        let parsed = parse_rep_history("[-1, 1]", started()).expect("parse");
        assert_eq!(
            parsed,
            vec![
                RepEvent {
                    action: RepAction::Missed,
                    at: started()
                },
                RepEvent {
                    action: RepAction::Success,
                    at: started()
                },
            ]
        );
    }

    #[test]
    fn an_unknown_integer_is_an_error_not_a_guess() {
        assert!(parse_rep_history("[2]", started()).is_err());
    }
}
