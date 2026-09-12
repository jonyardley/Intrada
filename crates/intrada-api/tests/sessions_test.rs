mod common;

use axum::http::StatusCode;
use intrada_core::domain::session::PracticeSession;
use serde_json::json;

fn sample_session_body() -> serde_json::Value {
    json!({
        "entries": [
            {
                "id": "entry-001",
                "item_id": "piece-001",
                "item_title": "Clair de Lune",
                "item_type": "piece",
                "position": 0,
                "duration_secs": 600,
                "status": "Completed",
                "notes": "Focused on dynamics"
            },
            {
                "id": "entry-002",
                "item_id": "exercise-001",
                "item_title": "Hanon No. 1",
                "item_type": "exercise",
                "position": 1,
                "duration_secs": 300,
                "status": "Skipped",
                "notes": null
            }
        ],
        "session_notes": "Good practice session",
        "started_at": "2026-02-16T10:00:00Z",
        "completed_at": "2026-02-16T10:15:00Z",
        "total_duration_secs": 900,
        "completion_status": "Completed"
    })
}

#[tokio::test]
async fn list_sessions_empty() {
    let app = common::setup_test_app().await;
    let (status, body) = common::get(app, "/api/sessions").await;

    assert_eq!(status, StatusCode::OK);
    let sessions: Vec<PracticeSession> = common::json(&body);
    assert!(sessions.is_empty());
}

#[tokio::test]
async fn save_session_valid() {
    let app = common::setup_test_app().await;
    let (status, body) = common::post_json(app, "/api/sessions", sample_session_body()).await;

    assert_eq!(status, StatusCode::CREATED);
    let session: PracticeSession = common::json(&body);
    assert!(!session.id.is_empty());
    assert_eq!(session.entries.len(), 2);
    assert_eq!(
        session.session_notes.as_deref(),
        Some("Good practice session")
    );
    assert_eq!(session.total_duration_secs, 900);
}

/// Invariant 6, consciously scoped (#1083): the online server has no step
/// support yet. A session whose entries carry a `variant_id` must still save —
/// the field is silently dropped (as `group_id` is), never a 400. Server step
/// tables arrive with the sync engine.
#[tokio::test]
async fn save_session_with_variant_id_on_entries_drops_it_gracefully() {
    let app = common::setup_test_app().await;
    let body = json!({
        "entries": [{
            "id": "entry-001",
            "item_id": "exercise-001",
            "item_title": "Scales",
            "item_type": "exercise",
            "position": 0,
            "duration_secs": 300,
            "status": "Completed",
            "notes": null,
            "score": 8,
            "variant_id": "variant-abc"
        }],
        "started_at": "2026-02-16T10:00:00Z",
        "completed_at": "2026-02-16T10:15:00Z",
        "total_duration_secs": 300,
        "completion_status": "Completed"
    });

    let (status, resp) = common::post_json(app, "/api/sessions", body).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "unknown step field is not rejected"
    );
    let session: PracticeSession = common::json(&resp);
    assert_eq!(session.entries.len(), 1);
    assert_eq!(
        session.entries[0].planned_variation_id, None,
        "server drops the planned variation until the sync engine ships"
    );
    assert_eq!(
        session.entries[0]
            .plays
            .first()
            .and_then(|p| p.variation_id.clone()),
        None,
        "server drops the played variation until the sync engine ships"
    );
    assert_eq!(
        session.entries[0].score_summary(),
        Some(8),
        "known fields still persist"
    );
}

#[tokio::test]
async fn save_session_empty_entries_returns_400() {
    let app = common::setup_test_app().await;
    let (status, _body) = common::post_json(
        app,
        "/api/sessions",
        json!({
            "entries": [],
            "started_at": "2026-02-16T10:00:00Z",
            "completed_at": "2026-02-16T10:15:00Z",
            "total_duration_secs": 900,
            "completion_status": "Completed"
        }),
    )
    .await;

    assert_eq!(status, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn get_session_existing() {
    let app = common::setup_test_app().await;

    let (_, body) = common::post_json(app.clone(), "/api/sessions", sample_session_body()).await;
    let created: PracticeSession = common::json(&body);

    let (status, body) = common::get(app, &format!("/api/sessions/{}", created.id)).await;
    assert_eq!(status, StatusCode::OK);
    let fetched: PracticeSession = common::json(&body);
    assert_eq!(fetched.id, created.id);
    assert_eq!(fetched.entries.len(), 2);
}

#[tokio::test]
async fn get_session_not_found() {
    let app = common::setup_test_app().await;
    let (status, _body) = common::get(app, "/api/sessions/nonexistent-id").await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn session_entries_ordered_by_position() {
    let app = common::setup_test_app().await;

    let (_, body) = common::post_json(app.clone(), "/api/sessions", sample_session_body()).await;
    let created: PracticeSession = common::json(&body);

    // Fetch from DB to verify ordering
    let (_, body) = common::get(app, &format!("/api/sessions/{}", created.id)).await;
    let fetched: PracticeSession = common::json(&body);

    assert_eq!(fetched.entries[0].position, 0);
    assert_eq!(fetched.entries[0].item_title, "Clair de Lune");
    assert_eq!(fetched.entries[1].position, 1);
    assert_eq!(fetched.entries[1].item_title, "Hanon No. 1");
}

#[tokio::test]
async fn delete_session_existing() {
    let app = common::setup_test_app().await;

    let (_, body) = common::post_json(app.clone(), "/api/sessions", sample_session_body()).await;
    let created: PracticeSession = common::json(&body);

    let (status, _body) =
        common::delete(app.clone(), &format!("/api/sessions/{}", created.id)).await;
    assert_eq!(status, StatusCode::OK);

    // Verify gone
    let (status, _body) = common::get(app, &format!("/api/sessions/{}", created.id)).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn delete_session_not_found() {
    let app = common::setup_test_app().await;
    let (status, _body) = common::delete(app, "/api/sessions/nonexistent-id").await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn list_sessions_includes_entries() {
    let app = common::setup_test_app().await;

    common::post_json(app.clone(), "/api/sessions", sample_session_body()).await;

    let (status, body) = common::get(app, "/api/sessions").await;
    assert_eq!(status, StatusCode::OK);
    let sessions: Vec<PracticeSession> = common::json(&body);
    assert_eq!(sessions.len(), 1);
    assert_eq!(sessions[0].entries.len(), 2);
}

#[tokio::test]
async fn session_ended_early_status() {
    let app = common::setup_test_app().await;
    let (status, body) = common::post_json(
        app,
        "/api/sessions",
        json!({
            "entries": [{
                "id": "entry-001",
                "item_id": "piece-001",
                "item_title": "Scales",
                "item_type": "exercise",
                "position": 0,
                "duration_secs": 120,
                "status": "NotAttempted",
                "notes": null
            }],
            "started_at": "2026-02-16T10:00:00Z",
            "completed_at": "2026-02-16T10:02:00Z",
            "total_duration_secs": 120,
            "completion_status": "EndedEarly"
        }),
    )
    .await;

    assert_eq!(status, StatusCode::CREATED);
    let session: PracticeSession = common::json(&body);
    assert_eq!(format!("{:?}", session.completion_status), "EndedEarly");
}

// ── Score-related tests (T014) ──────────────────────────────────────

fn sample_session_with_scores() -> serde_json::Value {
    json!({
        "entries": [
            {
                "id": "entry-s1",
                "item_id": "piece-001",
                "item_title": "Clair de Lune",
                "item_type": "piece",
                "position": 0,
                "duration_secs": 600,
                "status": "Completed",
                "notes": "Good dynamics",
                "score": 4
            },
            {
                "id": "entry-s2",
                "item_id": "exercise-001",
                "item_title": "Hanon No. 1",
                "item_type": "exercise",
                "position": 1,
                "duration_secs": 300,
                "status": "Completed",
                "notes": null,
                "score": 2
            },
            {
                "id": "entry-s3",
                "item_id": "piece-002",
                "item_title": "Moonlight Sonata",
                "item_type": "piece",
                "position": 2,
                "duration_secs": 200,
                "status": "Skipped",
                "notes": null,
                "score": null
            }
        ],
        "session_notes": "Scored session",
        "started_at": "2026-02-16T10:00:00Z",
        "completed_at": "2026-02-16T10:18:20Z",
        "total_duration_secs": 1100,
        "completion_status": "Completed"
    })
}

#[tokio::test]
async fn save_session_with_scores_returns_scores() {
    let app = common::setup_test_app().await;
    let (status, body) =
        common::post_json(app, "/api/sessions", sample_session_with_scores()).await;

    assert_eq!(status, StatusCode::CREATED);
    let session: PracticeSession = common::json(&body);
    assert_eq!(session.entries.len(), 3);
    assert_eq!(session.entries[0].score_summary(), Some(4));
    assert_eq!(session.entries[1].score_summary(), Some(2));
    assert_eq!(session.entries[2].score_summary(), None);
}

#[tokio::test]
async fn get_session_returns_scores() {
    let app = common::setup_test_app().await;

    let (_, body) =
        common::post_json(app.clone(), "/api/sessions", sample_session_with_scores()).await;
    let created: PracticeSession = common::json(&body);

    let (status, body) = common::get(app, &format!("/api/sessions/{}", created.id)).await;
    assert_eq!(status, StatusCode::OK);
    let fetched: PracticeSession = common::json(&body);
    assert_eq!(fetched.entries[0].score_summary(), Some(4));
    assert_eq!(fetched.entries[1].score_summary(), Some(2));
    assert_eq!(fetched.entries[2].score_summary(), None);
}

#[tokio::test]
async fn save_session_invalid_score_returns_400() {
    let app = common::setup_test_app().await;
    let (status, _body) = common::post_json(
        app,
        "/api/sessions",
        json!({
            "entries": [{
                "id": "entry-001",
                "item_id": "piece-001",
                "item_title": "Scales",
                "item_type": "exercise",
                "position": 0,
                "duration_secs": 120,
                "status": "Completed",
                "notes": null,
                "score": 11
            }],
            "started_at": "2026-02-16T10:00:00Z",
            "completed_at": "2026-02-16T10:02:00Z",
            "total_duration_secs": 120,
            "completion_status": "Completed"
        }),
    )
    .await;

    assert_eq!(status, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn save_session_score_zero_returns_400() {
    let app = common::setup_test_app().await;
    let (status, _body) = common::post_json(
        app,
        "/api/sessions",
        json!({
            "entries": [{
                "id": "entry-001",
                "item_id": "piece-001",
                "item_title": "Scales",
                "item_type": "exercise",
                "position": 0,
                "duration_secs": 120,
                "status": "Completed",
                "notes": null,
                "score": 0
            }],
            "started_at": "2026-02-16T10:00:00Z",
            "completed_at": "2026-02-16T10:02:00Z",
            "total_duration_secs": 120,
            "completion_status": "Completed"
        }),
    )
    .await;

    assert_eq!(status, StatusCode::BAD_REQUEST);
}

// ── Backward compatibility (T015) ───────────────────────────────────

#[tokio::test]
async fn save_session_without_scores_returns_null_scores() {
    let app = common::setup_test_app().await;

    // Use the original sample body which has no score fields
    let (status, body) = common::post_json(app, "/api/sessions", sample_session_body()).await;

    assert_eq!(status, StatusCode::CREATED);
    let session: PracticeSession = common::json(&body);
    assert_eq!(session.entries.len(), 2);
    // Both entries should have score: None when not provided
    assert_eq!(session.entries[0].score_summary(), None);
    assert_eq!(session.entries[1].score_summary(), None);
}

#[tokio::test]
async fn get_session_without_scores_returns_null_scores() {
    let app = common::setup_test_app().await;

    // Create a session without scores
    let (_, body) = common::post_json(app.clone(), "/api/sessions", sample_session_body()).await;
    let created: PracticeSession = common::json(&body);

    // Fetch it back
    let (status, body) = common::get(app, &format!("/api/sessions/{}", created.id)).await;
    assert_eq!(status, StatusCode::OK);
    let fetched: PracticeSession = common::json(&body);
    assert_eq!(fetched.entries[0].score_summary(), None);
    assert_eq!(fetched.entries[1].score_summary(), None);
}

#[tokio::test]
async fn list_sessions_without_scores_returns_null_scores() {
    let app = common::setup_test_app().await;

    // Create a session without scores
    common::post_json(app.clone(), "/api/sessions", sample_session_body()).await;

    let (status, body) = common::get(app, "/api/sessions").await;
    assert_eq!(status, StatusCode::OK);
    let sessions: Vec<PracticeSession> = common::json(&body);
    assert_eq!(sessions.len(), 1);
    // All entries should have score: None
    for entry in &sessions[0].entries {
        assert_eq!(entry.score_summary(), None);
    }
}
