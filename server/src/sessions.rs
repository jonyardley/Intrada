use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    routing::get,
    Router,
};
use serde::Deserialize;
use shared::session::{session_from_view_model, session_view_model, SessionState};
use shared::{PracticeSession, PracticeSessionView};
use sqlx::FromRow;
use std::sync::Arc;

use crate::{
    repository::{Database, RepositoryError, RepositoryResult},
    ApiError,
};

// Database row struct - flattened representation for storage
#[derive(FromRow)]
pub struct SessionRow {
    #[allow(dead_code)]
    pub id: String,
    pub goal_ids: String, // JSON string
    pub intention: String,
    pub notes: Option<String>,
    pub session_state: String, // "NotStarted", "Started", "Ended"
    pub start_time: Option<String>,
    pub end_time: Option<String>,
}

impl SessionRow {
    pub fn into_session(self) -> RepositoryResult<PracticeSession> {
        let goal_ids: Vec<String> = serde_json::from_str(&self.goal_ids)?;

        // Create SessionData with the original database ID using the view model approach
        let session_view = PracticeSessionView {
            id: self.id,
            goal_ids,
            intention: self.intention,
            state: match self.session_state.as_str() {
                "NotStarted" => SessionState::NotStarted,
                "Started" => SessionState::Started {
                    start_time: self.start_time.clone().unwrap_or_default(),
                },
                "PendingReflection" => SessionState::PendingReflection {
                    start_time: self.start_time.clone().unwrap_or_default(),
                    end_time: self.end_time.clone().unwrap_or_default(),
                },
                "Ended" => SessionState::Ended {
                    start_time: self.start_time.clone().unwrap_or_default(),
                    end_time: self.end_time.clone().unwrap_or_default(),
                },
                _ => SessionState::NotStarted,
            },
            notes: self.notes.clone(),
            study_sessions: Vec::new(),
            duration: None,
            start_time: self.start_time.clone(),
            end_time: self.end_time.clone(),
            is_ended: self.session_state == "Ended",
        };

        // Use the existing session_from_view_model function to preserve the ID
        let session = session_from_view_model(session_view);
        Ok(session)
    }
}

// Request types
#[derive(Debug, Deserialize)]
pub struct CreateSessionRequest {
    pub goal_ids: Vec<String>,
    pub intention: String,
    #[allow(dead_code)]
    pub notes: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateSessionRequest {
    #[allow(dead_code)]
    pub goal_ids: Option<Vec<String>>,
    #[allow(dead_code)]
    pub intention: Option<String>,
    #[allow(dead_code)]
    pub notes: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct StartSessionRequest {
    pub start_time: String,
}

#[derive(Debug, Deserialize)]
pub struct EndSessionRequest {
    pub end_time: String,
}

#[derive(Deserialize)]
pub struct CompleteReflectionRequest {
    pub notes: Option<String>,
}

// Simple Session repository - following goals/studies pattern
pub struct SessionRepository {
    db: Database,
}

impl SessionRepository {
    pub fn new(pool: crate::repository::DbPool) -> Self {
        Self {
            db: Database::new(pool),
        }
    }

    fn session_to_row_data(
        session: &PracticeSession,
    ) -> RepositoryResult<(String, String, Option<String>, Option<String>)> {
        let goal_ids_json = serde_json::to_string(session.goal_ids())?;

        let (state_str, start_time, end_time) = match session {
            PracticeSession::NotStarted(_) => ("NotStarted".to_string(), None, None),
            PracticeSession::Started(s) => {
                ("Started".to_string(), Some(s.start_time.clone()), None)
            }
            PracticeSession::Ended(s) => (
                "Ended".to_string(),
                Some(s.start_time.clone()),
                Some(s.end_time.clone()),
            ),
            PracticeSession::PendingReflection(s) => (
                "PendingReflection".to_string(),
                Some(s.start_time.clone()),
                Some(s.end_time.clone()),
            ),
        };

        Ok((goal_ids_json, state_str, start_time, end_time))
    }

    pub async fn create(&self, session: &PracticeSession) -> RepositoryResult<()> {
        let (goal_ids_json, state_str, start_time, end_time) = Self::session_to_row_data(session)?;

        sqlx::query(
            "INSERT INTO sessions (id, goal_ids, intention, notes, session_state, start_time, end_time) 
             VALUES ($1, $2, $3, $4, $5, $6, $7)"
        )
        .bind(session.id())
        .bind(&goal_ids_json)
        .bind(session.intention())
        .bind(session.notes())
        .bind(&state_str)
        .bind(&start_time)
        .bind(&end_time)
        .execute(&self.db.pool)
        .await?;

        Ok(())
    }

    pub async fn find_by_id(&self, id: &str) -> RepositoryResult<Option<PracticeSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            "SELECT id, goal_ids, intention, notes, session_state, start_time, end_time 
             FROM sessions WHERE id = $1",
        )
        .bind(id)
        .fetch_optional(&self.db.pool)
        .await?;

        match row {
            Some(row) => Ok(Some(row.into_session()?)),
            None => Ok(None),
        }
    }

    pub async fn find_all(&self) -> RepositoryResult<Vec<PracticeSession>> {
        let rows = sqlx::query_as::<_, SessionRow>(
            "SELECT id, goal_ids, intention, notes, session_state, start_time, end_time 
             FROM sessions ORDER BY created_at DESC",
        )
        .fetch_all(&self.db.pool)
        .await?;

        let mut sessions = Vec::new();
        for row in rows {
            sessions.push(row.into_session()?);
        }
        Ok(sessions)
    }

    pub async fn update(&self, session: &PracticeSession) -> RepositoryResult<()> {
        let (goal_ids_json, state_str, start_time, end_time) = Self::session_to_row_data(session)?;

        let result = sqlx::query(
            "UPDATE sessions SET goal_ids = $2, intention = $3, notes = $4, session_state = $5, 
             start_time = $6, end_time = $7, updated_at = CURRENT_TIMESTAMP 
             WHERE id = $1",
        )
        .bind(session.id())
        .bind(&goal_ids_json)
        .bind(session.intention())
        .bind(session.notes())
        .bind(&state_str)
        .bind(&start_time)
        .bind(&end_time)
        .execute(&self.db.pool)
        .await?;

        if result.rows_affected() == 0 {
            return Err(RepositoryError::NotFound(format!(
                "Session with id {}",
                session.id()
            )));
        }

        Ok(())
    }

    pub async fn delete(&self, id: &str) -> RepositoryResult<bool> {
        let result = sqlx::query("DELETE FROM sessions WHERE id = $1")
            .bind(id)
            .execute(&self.db.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    // Domain-specific methods
    pub async fn _find_by_goal_id(&self, goal_id: &str) -> RepositoryResult<Vec<PracticeSession>> {
        let rows = sqlx::query_as::<_, SessionRow>(
            "SELECT id, goal_ids, intention, notes, session_state, start_time, end_time 
             FROM sessions WHERE goal_ids LIKE $1 ORDER BY created_at DESC",
        )
        .bind(format!("%\"{goal_id}\"%"))
        .fetch_all(&self.db.pool)
        .await?;

        let mut sessions = Vec::new();
        for row in rows {
            let session = row.into_session()?;
            // Double-check the goal_id is actually in the list (not just substring match)
            if session.goal_ids().contains(&goal_id.to_string()) {
                sessions.push(session);
            }
        }
        Ok(sessions)
    }

    pub async fn _find_by_state(&self, state: &str) -> RepositoryResult<Vec<PracticeSession>> {
        let rows = sqlx::query_as::<_, SessionRow>(
            "SELECT id, goal_ids, intention, notes, session_state, start_time, end_time 
             FROM sessions WHERE session_state = $1 ORDER BY created_at DESC",
        )
        .bind(state)
        .fetch_all(&self.db.pool)
        .await?;

        let mut sessions = Vec::new();
        for row in rows {
            sessions.push(row.into_session()?);
        }
        Ok(sessions)
    }
}

// HTTP Handlers
async fn create_session(
    State(session_repo): State<Arc<SessionRepository>>,
    Json(req): Json<CreateSessionRequest>,
) -> Result<Json<PracticeSessionView>, (StatusCode, Json<ApiError>)> {
    let session = PracticeSession::new(req.goal_ids, req.intention);

    // Note: For now, we'll ignore the notes field in creation
    // The session creation in shared/session.rs doesn't support initial notes
    // This would require extending the constructor or adding a separate update call

    session_repo
        .create(&session)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(session_view_model(&session)))
}

async fn get_sessions(
    State(session_repo): State<Arc<SessionRepository>>,
) -> Result<Json<Vec<PracticeSessionView>>, (StatusCode, Json<ApiError>)> {
    let sessions = session_repo
        .find_all()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    let session_views: Vec<PracticeSessionView> = sessions.iter().map(session_view_model).collect();

    Ok(Json(session_views))
}

async fn get_session(
    State(session_repo): State<Arc<SessionRepository>>,
    Path(id): Path<String>,
) -> Result<Json<PracticeSessionView>, (StatusCode, Json<ApiError>)> {
    let session = session_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    match session {
        Some(session) => Ok(Json(session_view_model(&session))),
        None => Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Session not found".to_string(),
            }),
        )),
    }
}

async fn update_session(
    State(session_repo): State<Arc<SessionRepository>>,
    Path(id): Path<String>,
    Json(req): Json<UpdateSessionRequest>,
) -> Result<Json<PracticeSessionView>, (StatusCode, Json<ApiError>)> {
    // Get existing session
    let existing_session = session_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    let mut session = match existing_session {
        Some(session) => session,
        None => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(ApiError {
                    message: "Session not found".to_string(),
                }),
            ));
        }
    };

    // Update fields if provided - update the session data in place
    // This preserves the session state while updating the core data fields
    if let Some(notes) = req.notes {
        // Update notes in the session data
        match &mut session {
            PracticeSession::NotStarted(s) => {
                *s.data.notes_mut() = Some(notes);
            }
            PracticeSession::Started(s) => {
                *s.data.notes_mut() = Some(notes);
            }
            PracticeSession::PendingReflection(s) => {
                *s.data.notes_mut() = Some(notes);
            }
            PracticeSession::Ended(s) => {
                *s.data.notes_mut() = Some(notes);
            }
        }
    }

    if let Some(intention) = req.intention {
        // Update intention in the session data
        match &mut session {
            PracticeSession::NotStarted(s) => {
                *s.data.intention_mut() = intention;
            }
            PracticeSession::Started(s) => {
                *s.data.intention_mut() = intention;
            }
            PracticeSession::PendingReflection(s) => {
                *s.data.intention_mut() = intention;
            }
            PracticeSession::Ended(s) => {
                *s.data.intention_mut() = intention;
            }
        }
    }

    if let Some(goal_ids) = req.goal_ids {
        // Update goal_ids in the session data
        match &mut session {
            PracticeSession::NotStarted(s) => {
                *s.data.goal_ids_mut() = goal_ids;
            }
            PracticeSession::Started(s) => {
                *s.data.goal_ids_mut() = goal_ids;
            }
            PracticeSession::PendingReflection(s) => {
                *s.data.goal_ids_mut() = goal_ids;
            }
            PracticeSession::Ended(s) => {
                *s.data.goal_ids_mut() = goal_ids;
            }
        }
    }

    // Save the updated session
    session_repo
        .update(&session)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(session_view_model(&session)))
}

async fn start_session(
    State(session_repo): State<Arc<SessionRepository>>,
    Path(id): Path<String>,
    Json(req): Json<StartSessionRequest>,
) -> Result<Json<PracticeSessionView>, (StatusCode, Json<ApiError>)> {
    let session = session_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    let mut session = match session {
        Some(session) => session,
        None => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(ApiError {
                    message: "Session not found".to_string(),
                }),
            ));
        }
    };

    // Start the session
    session.start(req.start_time).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                message: e.to_string(),
            }),
        )
    })?;

    session_repo
        .update(&session)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(session_view_model(&session)))
}

async fn end_session(
    State(session_repo): State<Arc<SessionRepository>>,
    Path(id): Path<String>,
    Json(req): Json<EndSessionRequest>,
) -> Result<Json<PracticeSessionView>, (StatusCode, Json<ApiError>)> {
    let session = session_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    let mut session = match session {
        Some(session) => session,
        None => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(ApiError {
                    message: "Session not found".to_string(),
                }),
            ));
        }
    };

    // End the session
    session.end(req.end_time).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                message: e.to_string(),
            }),
        )
    })?;

    session_repo
        .update(&session)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(session_view_model(&session)))
}

async fn complete_reflection(
    State(session_repo): State<Arc<SessionRepository>>,
    Path(id): Path<String>,
    Json(req): Json<CompleteReflectionRequest>,
) -> Result<Json<PracticeSessionView>, (StatusCode, Json<ApiError>)> {
    let session = session_repo
        .find_by_id(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    let mut session = match session {
        Some(session) => session,
        None => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(ApiError {
                    message: "Session not found".to_string(),
                }),
            ));
        }
    };

    // Update notes if provided
    if let Some(notes) = req.notes {
        match &mut session {
            PracticeSession::NotStarted(s) => {
                *s.data.notes_mut() = Some(notes);
            }
            PracticeSession::Started(s) => {
                *s.data.notes_mut() = Some(notes);
            }
            PracticeSession::PendingReflection(s) => {
                *s.data.notes_mut() = Some(notes);
            }
            PracticeSession::Ended(s) => {
                *s.data.notes_mut() = Some(notes);
            }
        }
    }

    // Complete the reflection (transitions PendingReflection -> Ended)
    session.complete_reflection().map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            Json(ApiError {
                message: e.to_string(),
            }),
        )
    })?;

    session_repo
        .update(&session)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    Ok(Json(session_view_model(&session)))
}

async fn delete_session(
    State(session_repo): State<Arc<SessionRepository>>,
    Path(id): Path<String>,
) -> Result<StatusCode, (StatusCode, Json<ApiError>)> {
    let deleted = session_repo
        .delete(&id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(e.into())))?;

    if deleted {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err((
            StatusCode::NOT_FOUND,
            Json(ApiError {
                message: "Session not found".to_string(),
            }),
        ))
    }
}

pub fn routes() -> Router<Arc<SessionRepository>> {
    Router::new()
        .route("/sessions", get(get_sessions).post(create_session))
        .route(
            "/sessions/{id}",
            get(get_session).put(update_session).delete(delete_session),
        )
        .route("/sessions/{id}/start", axum::routing::post(start_session))
        .route("/sessions/{id}/end", axum::routing::post(end_session))
        .route(
            "/sessions/{id}/complete",
            axum::routing::post(complete_reflection),
        )
}

// *************
// TESTS
// *************

#[cfg(test)]
mod tests {
    use super::*;
    use shared::PracticeSession;
    use std::sync::Mutex;

    // Simple mock repository for testing
    struct MockSessionRepository {
        sessions: Mutex<Vec<PracticeSession>>,
    }

    impl MockSessionRepository {
        fn new() -> Self {
            Self {
                sessions: Mutex::new(Vec::new()),
            }
        }

        async fn create(&self, session: &PracticeSession) -> RepositoryResult<()> {
            let mut sessions = self.sessions.lock().unwrap();
            sessions.push(session.clone());
            Ok(())
        }

        async fn find_by_id(&self, id: &str) -> RepositoryResult<Option<PracticeSession>> {
            let sessions = self.sessions.lock().unwrap();
            Ok(sessions.iter().find(|s| s.id() == id).cloned())
        }

        async fn find_all(&self) -> RepositoryResult<Vec<PracticeSession>> {
            let sessions = self.sessions.lock().unwrap();
            Ok(sessions.clone())
        }

        async fn update(&self, session: &PracticeSession) -> RepositoryResult<()> {
            let mut sessions = self.sessions.lock().unwrap();
            if let Some(existing) = sessions.iter_mut().find(|s| s.id() == session.id()) {
                *existing = session.clone();
                Ok(())
            } else {
                Err(RepositoryError::NotFound(session.id().to_string()))
            }
        }

        async fn delete(&self, id: &str) -> RepositoryResult<bool> {
            let mut sessions = self.sessions.lock().unwrap();
            if let Some(pos) = sessions.iter().position(|s| s.id() == id) {
                sessions.remove(pos);
                Ok(true)
            } else {
                Ok(false)
            }
        }
    }

    #[test]
    fn test_session_row_conversion_not_started() {
        let session_row = SessionRow {
            id: "test-id".to_string(),
            goal_ids: r#"["goal1", "goal2"]"#.to_string(),
            intention: "Test intention".to_string(),
            notes: Some("Test notes".to_string()),
            session_state: "NotStarted".to_string(),
            start_time: None,
            end_time: None,
        };

        let session = session_row.into_session().unwrap();
        // Note: Due to SessionData constructor generating new IDs, we can't preserve the original ID
        assert!(!session.id().is_empty());
        assert_eq!(
            session.goal_ids(),
            &vec!["goal1".to_string(), "goal2".to_string()]
        );
        assert_eq!(session.intention(), "Test intention");
        assert!(matches!(session, PracticeSession::NotStarted(_)));
    }

    #[test]
    fn test_session_row_conversion_started() {
        let session_row = SessionRow {
            id: "test-id".to_string(),
            goal_ids: r#"["goal1"]"#.to_string(),
            intention: "Test intention".to_string(),
            notes: None,
            session_state: "Started".to_string(),
            start_time: Some("2025-01-01T12:00:00Z".to_string()),
            end_time: None,
        };

        let session = session_row.into_session().unwrap();
        // Note: Due to SessionData constructor generating new IDs, we can't preserve the original ID
        assert!(!session.id().is_empty());
        assert!(matches!(session, PracticeSession::Started(_)));
        assert_eq!(session.start_time(), Some("2025-01-01T12:00:00Z"));
        assert_eq!(session.end_time(), None);
    }

    #[test]
    fn test_session_row_conversion_ended() {
        let session_row = SessionRow {
            id: "test-id".to_string(),
            goal_ids: r#"["goal1"]"#.to_string(),
            intention: "Test intention".to_string(),
            notes: Some("Final notes".to_string()),
            session_state: "Ended".to_string(),
            start_time: Some("2025-01-01T12:00:00Z".to_string()),
            end_time: Some("2025-01-01T13:00:00Z".to_string()),
        };

        let session = session_row.into_session().unwrap();
        // Note: Due to SessionData constructor generating new IDs, we can't preserve the original ID
        assert!(!session.id().is_empty());
        assert!(matches!(session, PracticeSession::Ended(_)));
        assert_eq!(session.start_time(), Some("2025-01-01T12:00:00Z"));
        assert_eq!(session.end_time(), Some("2025-01-01T13:00:00Z"));
        assert_eq!(session.duration(), Some("60m".to_string()));
    }

    #[test]
    fn test_create_session_request() {
        let request = CreateSessionRequest {
            goal_ids: vec!["goal1".to_string(), "goal2".to_string()],
            intention: "Test session".to_string(),
            notes: Some("Notes".to_string()),
        };

        assert_eq!(request.goal_ids, vec!["goal1", "goal2"]);
        assert_eq!(request.intention, "Test session");
        assert_eq!(request.notes, Some("Notes".to_string()));
    }

    #[tokio::test]
    async fn test_mock_repository_operations() {
        let mock_repo = MockSessionRepository::new();

        let session = PracticeSession::new(vec!["goal1".to_string()], "Test Session".to_string());
        let session_id = session.id().to_string();

        // Test create
        mock_repo.create(&session).await.unwrap();

        // Test find_by_id
        let found = mock_repo.find_by_id(&session_id).await.unwrap();
        assert!(found.is_some());
        assert_eq!(found.unwrap().intention(), "Test Session");

        // Test find_all
        let all_sessions = mock_repo.find_all().await.unwrap();
        assert_eq!(all_sessions.len(), 1);

        // Test update (start session)
        let mut updated_session = session.clone();
        updated_session
            .start("2025-01-01T12:00:00Z".to_string())
            .unwrap();
        mock_repo.update(&updated_session).await.unwrap();

        let found = mock_repo.find_by_id(&session_id).await.unwrap().unwrap();
        assert!(found.is_active());

        // Test delete
        let deleted = mock_repo.delete(&session_id).await.unwrap();
        assert!(deleted);

        let found = mock_repo.find_by_id(&session_id).await.unwrap();
        assert!(found.is_none());
    }

    #[test]
    fn test_session_to_row_data() {
        let session = PracticeSession::new(vec!["goal1".to_string()], "Test".to_string());

        let (goal_ids_json, state_str, start_time, end_time) =
            SessionRepository::session_to_row_data(&session).unwrap();

        assert_eq!(goal_ids_json, r#"["goal1"]"#);
        assert_eq!(state_str, "NotStarted");
        assert_eq!(start_time, None);
        assert_eq!(end_time, None);
    }
}
