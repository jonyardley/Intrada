//! Tool implementations.
//!
//! Each handler:
//! - Takes the typed arguments parsed from the JSON-RPC `arguments` object.
//! - Calls into `crate::services::*` (the same layer HTTP routes use).
//! - Returns the result as `serde_json::Value` for the dispatcher to wrap
//!   in MCP's `content: [{ type: "text", text: "<JSON>" }]` shape.
//!
//! Date-range filtering on `list_sessions` happens here rather than in the
//! service layer to keep this PR scoped — pushing the filter down is a
//! follow-up refactor.

use chrono::{DateTime, Utc};
use libsql::Connection;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use intrada_core::domain::item::ItemKind;
use intrada_core::domain::types::{CreateItem, UpdateItem};
use intrada_core::validation;

use crate::auth::AuthSource;
use crate::db::sets::{CreateSetEntry, CreateSetRequest, UpdateSetRequest};
use crate::error::ApiError;
use crate::services;

// ── list_items ─────────────────────────────────────────────────────────

#[derive(Debug, Deserialize, Default)]
pub struct ListItemsArgs {
    #[serde(default)]
    pub kind: Option<String>,
}

pub async fn list_items(
    conn: &Connection,
    user_id: &str,
    args: ListItemsArgs,
) -> Result<Value, ApiError> {
    let kind_filter = match args.kind.as_deref() {
        None => None,
        Some("piece") => Some(ItemKind::Piece),
        Some("exercise") => Some(ItemKind::Exercise),
        Some(other) => {
            return Err(ApiError::Validation(format!(
                "Invalid kind: {other:?} (expected \"piece\" or \"exercise\")"
            )))
        }
    };
    let items = services::items::list_items(conn, user_id).await?;
    let filtered: Vec<_> = items
        .into_iter()
        .filter(|i| kind_filter.is_none() || Some(i.kind.clone()) == kind_filter)
        .collect();
    serde_json::to_value(filtered).map_err(|e| ApiError::Internal(format!("serialize items: {e}")))
}

// ── get_item ───────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct GetItemArgs {
    pub id: String,
}

pub async fn get_item(
    conn: &Connection,
    user_id: &str,
    args: GetItemArgs,
) -> Result<Value, ApiError> {
    let item = services::items::get_item(conn, &args.id, user_id).await?;
    serde_json::to_value(item).map_err(|e| ApiError::Internal(format!("serialize item: {e}")))
}

// ── list_sets ──────────────────────────────────────────────────────────

pub async fn list_sets(conn: &Connection, user_id: &str) -> Result<Value, ApiError> {
    let sets = services::sets::list_sets(conn, user_id).await?;
    serde_json::to_value(sets).map_err(|e| ApiError::Internal(format!("serialize sets: {e}")))
}

// ── get_set ────────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct GetSetArgs {
    pub id: String,
}

pub async fn get_set(
    conn: &Connection,
    user_id: &str,
    args: GetSetArgs,
) -> Result<Value, ApiError> {
    let set = services::sets::get_set(conn, &args.id, user_id).await?;
    serde_json::to_value(set).map_err(|e| ApiError::Internal(format!("serialize set: {e}")))
}

// ── list_sessions ──────────────────────────────────────────────────────

#[derive(Debug, Deserialize, Default)]
pub struct ListSessionsArgs {
    #[serde(default)]
    pub start: Option<DateTime<Utc>>,
    #[serde(default)]
    pub end: Option<DateTime<Utc>>,
}

pub async fn list_sessions(
    conn: &Connection,
    user_id: &str,
    args: ListSessionsArgs,
) -> Result<Value, ApiError> {
    let sessions = services::sessions::list_sessions(conn, user_id).await?;
    let filtered: Vec<_> = sessions
        .into_iter()
        .filter(|s| in_range(s.started_at, args.start, args.end))
        .collect();
    serde_json::to_value(filtered)
        .map_err(|e| ApiError::Internal(format!("serialize sessions: {e}")))
}

fn in_range(when: DateTime<Utc>, start: Option<DateTime<Utc>>, end: Option<DateTime<Utc>>) -> bool {
    if let Some(s) = start {
        if when < s {
            return false;
        }
    }
    if let Some(e) = end {
        if when > e {
            return false;
        }
    }
    true
}

// ── get_session ────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct GetSessionArgs {
    pub id: String,
}

pub async fn get_session(
    conn: &Connection,
    user_id: &str,
    args: GetSessionArgs,
) -> Result<Value, ApiError> {
    let session = services::sessions::get_session(conn, &args.id, user_id).await?;
    serde_json::to_value(session).map_err(|e| ApiError::Internal(format!("serialize session: {e}")))
}

// ── get_practice_summary ───────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct GetPracticeSummaryArgs {
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
}

/// Wide-view aggregation. Pre-joins sessions + entries so the agent
/// doesn't need 10 round trips to answer "how was my week?".
pub async fn get_practice_summary(
    conn: &Connection,
    user_id: &str,
    args: GetPracticeSummaryArgs,
) -> Result<Value, ApiError> {
    let sessions = services::sessions::list_sessions(conn, user_id).await?;
    let in_window: Vec<_> = sessions
        .into_iter()
        .filter(|s| in_range(s.started_at, Some(args.start), Some(args.end)))
        .collect();

    let sessions_count = in_window.len();
    // Sum seconds first, divide once at the end — dividing per-session
    // would drop sub-minute remainders. With 10 × 90s sessions the
    // per-session approach reads as 10min instead of the correct 15.
    let total_secs: u64 = in_window.iter().map(|s| s.total_duration_secs).sum();
    let total_minutes = total_secs / 60;

    let mut item_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
    let mut score_sum: u32 = 0;
    let mut score_count: u32 = 0;
    let mut entry_count: u32 = 0;

    // Per-item aggregations: total minutes + count + average score.
    use std::collections::HashMap;
    #[derive(Default)]
    struct ItemAcc {
        title: String,
        kind: String,
        total_secs: u64,
        entry_count: u32,
        score_sum: u32,
        score_count: u32,
    }
    let mut per_item: HashMap<String, ItemAcc> = HashMap::new();

    for session in &in_window {
        for entry in &session.entries {
            entry_count += 1;
            item_ids.insert(entry.item_id.clone());
            if let Some(score) = entry.score_summary() {
                score_sum += u32::from(score);
                score_count += 1;
            }
            let acc = per_item.entry(entry.item_id.clone()).or_default();
            acc.title = entry.item_title.clone();
            acc.kind = match entry.item_type {
                ItemKind::Piece => "piece".to_string(),
                ItemKind::Exercise => "exercise".to_string(),
            };
            acc.total_secs += entry.duration_secs;
            acc.entry_count += 1;
            if let Some(score) = entry.score_summary() {
                acc.score_sum += u32::from(score);
                acc.score_count += 1;
            }
        }
    }

    let avg_score = if score_count > 0 {
        Some(score_sum as f32 / score_count as f32)
    } else {
        None
    };

    let mut items: Vec<_> = per_item
        .into_iter()
        .map(|(id, acc)| {
            json!({
                "item_id": id,
                "title": acc.title,
                "kind": acc.kind,
                "total_minutes": acc.total_secs / 60,
                "session_appearances": acc.entry_count,
                "average_score": if acc.score_count > 0 {
                    Some(acc.score_sum as f32 / acc.score_count as f32)
                } else {
                    None
                },
            })
        })
        .collect();
    // Sort by total time descending — most-practiced first is what an
    // agent reading this summary will want.
    items.sort_by(|a, b| {
        let a_min = a["total_minutes"].as_u64().unwrap_or(0);
        let b_min = b["total_minutes"].as_u64().unwrap_or(0);
        b_min.cmp(&a_min)
    });

    Ok(json!({
        "start": args.start,
        "end": args.end,
        "sessions_count": sessions_count,
        "total_minutes": total_minutes,
        "items_practiced": item_ids.len(),
        "entries_count": entry_count,
        "average_score": avg_score,
        "items": items,
    }))
}

// ── Write tools (Phase 4) ──────────────────────────────────────────────

// ── create_item ────────────────────────────────────────────────────────

pub async fn create_item(
    conn: &Connection,
    user_id: &str,
    args: CreateItem,
) -> Result<Value, ApiError> {
    let item = services::items::create_item(conn, user_id, &args).await?;
    serde_json::to_value(item).map_err(|e| ApiError::Internal(format!("serialize item: {e}")))
}

// ── update_item ────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct UpdateItemArgs {
    pub id: String,
    /// PATCH-style partial. `None` field = unchanged. `Some(None)` = clear.
    #[serde(flatten)]
    pub patch: UpdateItem,
}

pub async fn update_item(
    conn: &Connection,
    user_id: &str,
    args: UpdateItemArgs,
) -> Result<Value, ApiError> {
    let item = services::items::update_item(conn, &args.id, user_id, &args.patch).await?;
    serde_json::to_value(item).map_err(|e| ApiError::Internal(format!("serialize item: {e}")))
}

// ── delete_item ────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct DeleteItemArgs {
    pub id: String,
}

pub async fn delete_item(
    conn: &Connection,
    user_id: &str,
    args: DeleteItemArgs,
) -> Result<Value, ApiError> {
    services::items::delete_item(conn, &args.id, user_id).await?;
    Ok(json!({ "deleted": args.id }))
}

// ── create_set ─────────────────────────────────────────────────────────

pub async fn create_set(
    conn: &Connection,
    user_id: &str,
    args: CreateSetRequest,
) -> Result<Value, ApiError> {
    let set = services::sets::create_set(conn, user_id, &args).await?;
    serde_json::to_value(set).map_err(|e| ApiError::Internal(format!("serialize set: {e}")))
}

// ── update_set ─────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct UpdateSetArgs {
    pub id: String,
    pub name: String,
    pub entries: Vec<CreateSetEntry>,
}

pub async fn update_set(
    conn: &Connection,
    user_id: &str,
    args: UpdateSetArgs,
) -> Result<Value, ApiError> {
    let req = UpdateSetRequest {
        name: args.name,
        entries: args.entries,
    };
    let set = services::sets::update_set(conn, &args.id, user_id, &req).await?;
    serde_json::to_value(set).map_err(|e| ApiError::Internal(format!("serialize set: {e}")))
}

// ── bulk_import_items ──────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
pub struct BulkImportItemsArgs {
    pub items: Vec<CreateItem>,
    /// `true` returns a preview without writing. The agent shows the
    /// preview to the user, gets confirmation, then re-calls with
    /// `dry_run: false`. Idiomatic MCP confirmation pattern.
    #[serde(default)]
    pub dry_run: bool,
}

#[derive(Debug, Serialize)]
struct BulkImportItemPreview {
    index: usize,
    title: String,
    valid: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

/// Pre-flight every item against `intrada_core::validation::validate_create_item`.
/// Returns per-item validation status for the preview, plus a flat
/// `valid_count` / `invalid_count` so the agent can decide whether to
/// proceed without iterating the array client-side.
fn validate_all(items: &[CreateItem]) -> (Vec<BulkImportItemPreview>, usize, usize) {
    let mut previews = Vec::with_capacity(items.len());
    let mut valid_count = 0;
    let mut invalid_count = 0;
    for (index, item) in items.iter().enumerate() {
        let (valid, error) = match validation::validate_create_item(item) {
            Ok(()) => {
                valid_count += 1;
                (true, None)
            }
            Err(e) => {
                invalid_count += 1;
                (false, Some(e.to_string()))
            }
        };
        previews.push(BulkImportItemPreview {
            index,
            title: item.title.clone(),
            valid,
            error,
        });
    }
    (previews, valid_count, invalid_count)
}

/// Bulk-import handler. Records audit internally because the dispatcher
/// can't know in advance whether `dry_run` will trigger an actual write
/// — so the audit decision lives next to the write decision.
pub async fn bulk_import_items(
    conn: &Connection,
    source: &AuthSource,
    user_id: &str,
    raw_args: &Value,
    args: BulkImportItemsArgs,
) -> Result<Value, ApiError> {
    // Normalise up front so the dry-run preview's validation + shown titles
    // match what the real write stores (parity with the core, #888).
    let items: Vec<CreateItem> = args
        .items
        .into_iter()
        .map(validation::normalize_create_item)
        .collect();
    let (previews, valid_count, invalid_count) = validate_all(&items);

    if args.dry_run {
        return Ok(json!({
            "dry_run": true,
            "valid_count": valid_count,
            "invalid_count": invalid_count,
            "items": previews,
        }));
    }

    // Validation atomicity: if ANY item is invalid, write NONE. The
    // agent should fix invalid items and retry rather than commit a
    // partial set.
    if invalid_count > 0 {
        return Err(ApiError::Validation(format!(
            "{invalid_count} of {} items failed validation; fix or omit them and retry",
            items.len()
        )));
    }

    // Sequential inserts — libsql HTTP doesn't reliably support
    // multi-statement transactions across the same connection (see the
    // `delete_all_user_data` comment for the rationale). DB-level
    // atomicity is therefore best-effort, NOT guaranteed: if a DB error
    // happens mid-loop after pre-flight validation passed, earlier
    // inserts persist. We surface the partial state in the error so the
    // agent can re-issue only the remaining items rather than
    // silently leaving the user wondering what happened.
    let mut created = Vec::with_capacity(items.len());
    for (index, item) in items.iter().enumerate() {
        match services::items::create_item(conn, user_id, item).await {
            Ok(created_item) => created.push(created_item),
            Err(e) => {
                tracing::error!(?e, index, total = items.len(), "bulk_import partial");
                return Err(ApiError::Internal(format!(
                    "Failed to insert item at index {index} ({} of {} succeeded): {e:?}",
                    created.len(),
                    items.len()
                )));
            }
        }
    }

    services::audit::record_mcp_write(conn, source, user_id, "bulk_import_items", raw_args).await;

    serde_json::to_value(json!({
        "dry_run": false,
        "created_count": created.len(),
        "items": created,
    }))
    .map_err(|e| ApiError::Internal(format!("serialize bulk_import result: {e}")))
}
