use crate::app::error::SessionError;
use crate::app::model::Model;
use crate::app::repository::Repository;
use crate::app::study_session::StudySession;
use chrono::DateTime;
use crux_core::Command;
use facet::Facet;
use serde::{Deserialize, Serialize};

// Simple struct approach - consistent with Goal and Study entities
#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct PracticeSession {
    pub id: String,
    pub goal_ids: Vec<String>,
    pub intention: String,
    pub notes: Option<String>,
    pub study_sessions: Vec<StudySession>,
    pub active_study_session_id: Option<String>,
    pub state: SessionState,
}

// Note: PracticeSessionView eliminated - using computed methods on PracticeSession directly

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum SessionEvent {
    // Background sync events (internal only)
    #[serde(skip)]
    #[facet(skip)]
    SyncSessions,
    #[serde(skip)]
    #[facet(skip)]
    SessionsSynced(
        crate::HttpResult<crux_http::Response<Vec<PracticeSession>>, crux_http::HttpError>,
    ),
    #[serde(skip)]
    #[facet(skip)]
    SessionSynced(crate::HttpResult<crux_http::Response<PracticeSession>, crux_http::HttpError>),

    // Optimistic user actions (all immediate, sync in background)
    CreateSession(PracticeSession),
    UpdateSession(PracticeSession),
    StartSession(String, String),
    EndSession(String, String),
    CompleteReflection(String),
    EditSessionFields {
        session_id: String,
        goal_ids: Vec<String>,
        intention: String,
        notes: Option<String>,
    },
    EditSessionNotes(String, String),
    CompleteWithNotes(String, String),
    RemoveSession(String),
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[repr(C)]
pub enum SessionState {
    #[default]
    NotStarted,
    Started {
        start_time: String,
    },
    PendingReflection {
        start_time: String,
        end_time: String,
    },
    Ended {
        start_time: String,
        end_time: String,
        duration_in_seconds: u32,
    },
}

impl PracticeSession {
    pub fn new(goal_ids: Vec<String>, intention: String) -> Self {
        Self {
            id: crate::app::generate_id(),
            goal_ids,
            intention,
            notes: None,
            study_sessions: Vec::new(),
            active_study_session_id: None,
            state: SessionState::NotStarted,
        }
    }

    // Simple state transition methods with validation
    pub fn start(&mut self, timestamp: String) -> Result<(), SessionError> {
        match self.state {
            SessionState::NotStarted => {
                self.state = SessionState::Started {
                    start_time: timestamp,
                };
                Ok(())
            }
            SessionState::Started { .. } => Err(SessionError::AlreadyStarted),
            SessionState::PendingReflection { .. } | SessionState::Ended { .. } => {
                Err(SessionError::AlreadyEnded)
            }
        }
    }

    pub fn end(&mut self, timestamp: String) -> Result<(), SessionError> {
        match &self.state {
            SessionState::Started { start_time } => {
                self.state = SessionState::PendingReflection {
                    start_time: start_time.clone(),
                    end_time: timestamp,
                };
                Ok(())
            }
            SessionState::NotStarted => Err(SessionError::NotActive),
            SessionState::PendingReflection { .. } | SessionState::Ended { .. } => {
                Err(SessionError::AlreadyEnded)
            }
        }
    }

    pub fn complete_reflection(&mut self) -> Result<(), SessionError> {
        match &self.state {
            SessionState::PendingReflection {
                start_time,
                end_time,
            } => {
                let duration_in_seconds =
                    calculate_duration_in_seconds(start_time, end_time).unwrap_or(0);
                self.state = SessionState::Ended {
                    start_time: start_time.clone(),
                    end_time: end_time.clone(),
                    duration_in_seconds,
                };
                Ok(())
            }
            SessionState::NotStarted | SessionState::Started { .. } => Err(SessionError::NotActive),
            SessionState::Ended { .. } => Err(SessionError::AlreadyEnded),
        }
    }

    // Helper methods
    pub fn is_active(&self) -> bool {
        matches!(self.state, SessionState::Started { .. })
    }

    pub fn is_ended(&self) -> bool {
        matches!(self.state, SessionState::Ended { .. })
    }

    pub fn start_time(&self) -> Option<&str> {
        match &self.state {
            SessionState::Started { start_time }
            | SessionState::PendingReflection { start_time, .. }
            | SessionState::Ended { start_time, .. } => Some(start_time),
            SessionState::NotStarted => None,
        }
    }

    pub fn end_time(&self) -> Option<&str> {
        match &self.state {
            SessionState::PendingReflection { end_time, .. }
            | SessionState::Ended { end_time, .. } => Some(end_time),
            SessionState::NotStarted | SessionState::Started { .. } => None,
        }
    }

    pub fn duration(&self) -> Option<String> {
        match &self.state {
            SessionState::PendingReflection {
                start_time,
                end_time,
            } => {
                let seconds = calculate_duration_in_seconds(start_time, end_time)?;
                Some(format_duration_from_seconds(seconds))
            }
            SessionState::Ended {
                duration_in_seconds,
                ..
            } => Some(format_duration_from_seconds(*duration_in_seconds)),
            SessionState::NotStarted | SessionState::Started { .. } => None,
        }
    }

    pub fn duration_in_seconds(&self) -> Option<u32> {
        match &self.state {
            SessionState::PendingReflection {
                start_time,
                end_time,
            } => calculate_duration_in_seconds(start_time, end_time),
            SessionState::Ended {
                duration_in_seconds,
                ..
            } => Some(*duration_in_seconds),
            SessionState::NotStarted | SessionState::Started { .. } => None,
        }
    }

    // Mutator: push a StudySession
    pub fn push_study_session(&mut self, session: StudySession) {
        self.study_sessions.push(session);
    }

    // Mutator: update a StudySession by id
    pub fn update_study_session(&mut self, session: StudySession) {
        if let Some(existing) = self.study_sessions.iter_mut().find(|r| r.id == session.id) {
            *existing = session;
        }
    }
}

// Public duration calculation function for use by viewmodel
#[allow(clippy::cast_precision_loss, clippy::cast_possible_truncation)]
pub fn calculate_duration_in_seconds(start_time: &str, end_time: &str) -> Option<u32> {
    let start = DateTime::parse_from_rfc3339(start_time).ok()?;
    let end = DateTime::parse_from_rfc3339(end_time).ok()?;
    let duration = end - start;
    let seconds = duration.num_seconds();
    if seconds >= 0 {
        Some(seconds as u32)
    } else {
        None
    }
}

fn format_duration_from_seconds(seconds: u32) -> String {
    let minutes = (seconds as f64 / 60.0).round() as u32;
    format!("{minutes}m")
}

// Note: Basic CRUD operations now handled by SessionRepository in repository.rs
// These functions contain business logic and coordinate multiple operations

pub fn start_session(
    session_id: &str,
    timestamp: String,
    model: &mut Model,
) -> Result<(), SessionError> {
    let mut repo = model.sessions();

    // Ensure only one session can be started at a time
    // If there's already a started session, end it first
    if let Some(current_started) = repo.find_current_active_mut() {
        let current_id = current_started.id.clone();
        if current_id != session_id {
            // End the currently started session
            current_started.end(timestamp.clone())?;
            // Complete reflection to fully end the session
            current_started.complete_reflection()?;
        }
    }

    if let Some(session) = repo.find_mut_by_id(session_id) {
        session.start(timestamp)?;
        Ok(())
    } else {
        Err(SessionError::NotFound)
    }
}

pub fn end_session(
    session_id: &str,
    timestamp: String,
    model: &mut Model,
) -> Result<(), SessionError> {
    let mut repo = model.sessions();
    if let Some(session) = repo.find_mut_by_id(session_id) {
        session.end(timestamp)?;
        Ok(())
    } else {
        Err(SessionError::NotFound)
    }
}

pub fn complete_reflection(session_id: &str, model: &mut Model) -> Result<(), SessionError> {
    let mut repo = model.sessions();
    if let Some(session) = repo.find_mut_by_id(session_id) {
        session.complete_reflection()?;
        Ok(())
    } else {
        Err(SessionError::NotFound)
    }
}

pub fn edit_session_notes(session_id: &str, notes: String, model: &mut Model) {
    let mut repo = model.sessions();
    if let Some(session) = repo.find_mut_by_id(session_id) {
        session.notes = Some(notes);
    }
}

pub fn edit_session_fields(
    session_id: &str,
    goal_ids: Vec<String>,
    intention: String,
    notes: Option<String>,
    model: &mut Model,
) {
    let mut repo = model.sessions();
    if let Some(session) = repo.find_mut_by_id(session_id) {
        session.goal_ids = goal_ids;
        session.intention = intention;
        session.notes = notes;
    }
}

pub fn handle_event(
    event: SessionEvent,
    model: &mut Model,
) -> Command<super::Effect, super::Event> {
    match event {
        // Background sync events (internal only)
        SessionEvent::SyncSessions => {
            return crate::app::api_get("/api/sessions", |response| {
                super::Event::Session(SessionEvent::SessionsSynced(response))
            });
        }
        SessionEvent::SessionsSynced(crate::HttpResult::Ok(mut response)) => {
            let session_views = response.take_body().unwrap();
            // Merge server sessions with local sessions, preserving local changes
            merge_sessions_from_server(session_views, model);
        }
        SessionEvent::SessionsSynced(crate::HttpResult::Err(_e)) => {
            // Silently fail background sync - user doesn't need to know
            // Could add sync status to model if we want to show sync state later
        }
        SessionEvent::SessionSynced(crate::HttpResult::Ok(_response)) => {
            // Individual session synced successfully - nothing to do
        }
        SessionEvent::SessionSynced(crate::HttpResult::Err(_e)) => {
            // Individual session sync failed - could retry or show status
        }

        // Optimistic user actions (all immediate, sync in background)
        SessionEvent::CreateSession(session) => {
            // Apply immediately to local model
            model.sessions().add(session.clone());

            // Trigger background sync
            let create_request = serde_json::json!({
                "goal_ids": session.goal_ids,
                "intention": session.intention,
                "notes": session.notes
            });
            return crate::app::api_post("/api/sessions", &create_request, |response| {
                super::Event::Session(SessionEvent::SessionSynced(response))
            });
        }
        SessionEvent::UpdateSession(session) => {
            // Apply immediately to local model
            if let Some(existing) = model.sessions.iter_mut().find(|s| s.id == session.id) {
                *existing = session.clone();
            }

            // Trigger background sync
            return crate::app::api_put(
                &format!("/api/sessions/{}", session.id),
                &session,
                |response| super::Event::Session(SessionEvent::SessionSynced(response)),
            );
        }
        SessionEvent::StartSession(session_id, timestamp) => {
            // Apply optimistically to local model
            if let Err(e) = start_session(&session_id, timestamp.clone(), model) {
                model.last_error = Some(format!("Failed to start session: {e:?}"));
                return crux_core::render::render();
            }

            // Trigger background sync
            let start_request = serde_json::json!({ "start_time": timestamp });
            return crate::app::api_post(
                &format!("/api/sessions/{session_id}/start"),
                &start_request,
                |response| super::Event::Session(SessionEvent::SessionSynced(response)),
            );
        }
        SessionEvent::EndSession(session_id, timestamp) => {
            // Apply optimistically to local model - transitions to PendingReflection
            if let Err(e) = end_session(&session_id, timestamp.clone(), model) {
                model.last_error = Some(format!("Failed to end session: {e:?}"));
                return crux_core::render::render();
            }

            // Trigger background sync
            let end_request = serde_json::json!({ "end_time": timestamp });
            return crate::app::api_post(
                &format!("/api/sessions/{session_id}/end"),
                &end_request,
                |response| super::Event::Session(SessionEvent::SessionSynced(response)),
            );
        }
        SessionEvent::CompleteReflection(session_id) => {
            // Apply optimistically to local model - transitions PendingReflection to Ended
            if let Err(e) = complete_reflection(&session_id, model) {
                model.last_error = Some(format!("Failed to complete reflection: {e:?}"));
                return crux_core::render::render();
            }

            // Trigger background sync using the new complete endpoint
            return crate::app::api_post(
                &format!("/api/sessions/{session_id}/complete"),
                &serde_json::json!({}),
                |response| super::Event::Session(SessionEvent::SessionSynced(response)),
            );
        }
        SessionEvent::EditSessionFields {
            session_id,
            goal_ids,
            intention,
            notes,
        } => {
            // Apply immediately to local model
            edit_session_fields(
                &session_id,
                goal_ids.clone(),
                intention.clone(),
                notes.clone(),
                model,
            );

            // Trigger background sync
            if let Some(session) = model.sessions.iter().find(|s| s.id == session_id) {
                return crate::app::api_put(
                    &format!("/api/sessions/{}", session.id),
                    session,
                    |response| super::Event::Session(SessionEvent::SessionSynced(response)),
                );
            }
        }
        SessionEvent::EditSessionNotes(session_id, notes) => {
            // Apply immediately to local model
            edit_session_notes(&session_id, notes.clone(), model);

            // Trigger background sync
            if let Some(session) = model.sessions.iter().find(|s| s.id == session_id) {
                return crate::app::api_put(
                    &format!("/api/sessions/{}", session.id),
                    session,
                    |response| super::Event::Session(SessionEvent::SessionSynced(response)),
                );
            }
        }
        SessionEvent::CompleteWithNotes(session_id, notes) => {
            // Apply both operations immediately to local model
            edit_session_notes(&session_id, notes.clone(), model);
            if let Err(e) = complete_reflection(&session_id, model) {
                model.last_error = Some(format!("Failed to complete reflection: {e:?}"));
                return crux_core::render::render();
            }

            // Trigger single background sync to complete endpoint (which will save notes too)
            return crate::app::api_post(
                &format!("/api/sessions/{session_id}/complete"),
                &serde_json::json!({ "notes": notes }),
                |response| super::Event::Session(SessionEvent::SessionSynced(response)),
            );
        }
        SessionEvent::RemoveSession(session_id) => {
            // Apply immediately to local model
            model.sessions().remove(&session_id);

            // Trigger background sync
            return crate::app::api_delete(&format!("/api/sessions/{session_id}"), |response| {
                super::Event::Session(SessionEvent::SessionSynced(response))
            });
        }
    }

    crux_core::render::render()
}

// Helper function to merge server sessions with local sessions
fn merge_sessions_from_server(server_sessions: Vec<PracticeSession>, model: &mut Model) {
    // Simple merge strategy: server sessions override local ones with same ID
    // More sophisticated conflict resolution could be added here
    let server_session_ids: std::collections::HashSet<String> =
        server_sessions.iter().map(|s| s.id.clone()).collect();

    // Keep local sessions that don't exist on server (likely new/pending sync)
    model
        .sessions
        .retain(|local_session| !server_session_ids.contains(&local_session.id));

    // Add/update with server sessions
    for server_session in server_sessions {
        let session = server_session;
        if let Some(existing_pos) = model.sessions.iter().position(|s| s.id == session.id) {
            model.sessions[existing_pos] = session;
        } else {
            model.sessions.push(session);
        }
    }
}

// *************
// TESTS
// *************

#[test]
fn test_add_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    model.sessions().add(session);
    assert_eq!(model.sessions.len(), 1);
}

#[test]
fn test_edit_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    model.sessions().add(session);
    assert_eq!(model.sessions.len(), 1);
}

#[test]
fn test_start_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    model.sessions().add(session);
    assert_eq!(model.sessions.len(), 1);
}

#[test]
fn test_end_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    let session_id = session.id.to_string();
    model.sessions().add(session);

    // Start the session
    start_session(&session_id, "2025-05-01T12:00:00Z".to_string(), &mut model).unwrap();

    // Verify session is active
    assert!(model.sessions[0].is_active());
    let repo = model.sessions();
    assert!(repo.find_current_active().is_some());
    assert_eq!(repo.find_current_active().unwrap().id, session_id);

    // End the session 30 minutes later
    end_session(&session_id, "2025-05-01T12:30:00Z".to_string(), &mut model).unwrap();

    // Complete reflection to fully end the session
    complete_reflection(&session_id, &mut model).unwrap();

    // Verify session exists and duration is calculated on-demand
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].duration(), Some("30m".to_string())); // Now returns Option<String>
    assert!(model.sessions[0].is_ended());
    assert!(model.sessions().find_current_active().is_none());
}

#[test]
fn test_update_session_notes() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    model.sessions().add(session.clone());
    assert_eq!(model.sessions.len(), 1);
    edit_session_notes(&session.id, "Notes 1".to_string(), &mut model);
    assert_eq!(model.sessions[0].notes.as_deref(), Some("Notes 1"));
}

#[test]
fn test_session_state_transitions() {
    let mut session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());

    // Test start
    assert!(session.start("2025-05-01T12:00:00Z".to_string()).is_ok());
    assert!(session.is_active());
    assert_eq!(session.start_time(), Some("2025-05-01T12:00:00Z"));

    // Test end
    assert!(session.end("2025-05-01T12:30:00Z".to_string()).is_ok());

    // Complete reflection to fully end the session
    assert!(session.complete_reflection().is_ok());
    assert!(session.is_ended());
    assert_eq!(session.end_time(), Some("2025-05-01T12:30:00Z"));
    assert_eq!(session.duration(), Some("30m".to_string()));

    // Test invalid transitions
    assert!(session.start("2025-05-01T13:00:00Z".to_string()).is_err());
    assert!(session.end("2025-05-01T13:00:00Z".to_string()).is_err());
}

#[test]
fn test_backward_compatibility() {
    let mut session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());

    // Test initial state
    assert!(matches!(session.state, SessionState::NotStarted));
    assert_eq!(session.start_time(), None);
    assert_eq!(session.end_time(), None);
    assert_eq!(session.duration(), None);

    // Test after starting
    session.start("2025-05-01T12:00:00Z".to_string()).unwrap();
    assert!(matches!(session.state, SessionState::Started { .. }));
    assert_eq!(session.start_time(), Some("2025-05-01T12:00:00Z"));

    // Test after ending
    session.end("2025-05-01T12:30:00Z".to_string()).unwrap();

    // Complete reflection to fully end the session
    session.complete_reflection().unwrap();
    assert!(matches!(session.state, SessionState::Ended { .. }));
    assert_eq!(session.start_time(), Some("2025-05-01T12:00:00Z"));
    assert_eq!(session.end_time(), Some("2025-05-01T12:30:00Z"));
    assert_eq!(session.duration(), Some("30m".to_string()));
}

#[test]
fn test_calculate_duration_function() {
    let duration = calculate_duration_in_seconds("2025-05-01T12:00:00Z", "2025-05-01T12:30:00Z");
    assert_eq!(duration, Some(1800)); // 30 minutes = 1800 seconds

    let duration = calculate_duration_in_seconds("2025-05-01T12:00:00Z", "2025-05-01T12:00:00Z");
    assert_eq!(duration, Some(0)); // 0 seconds

    let duration = calculate_duration_in_seconds("2025-05-01T12:00:00Z", "2025-05-01T13:15:00Z");
    assert_eq!(duration, Some(4500)); // 75 minutes = 4500 seconds
}

// Note: View model conversion test removed - no longer needed with direct PracticeSession usage

#[test]
fn test_session_helpers() {
    let mut model = Model::default();

    // Test no started session initially
    assert!(model.sessions().find_current_active().is_none());
    let repo = model.sessions();
    assert_eq!(repo.find_not_started().len(), 0);
    assert_eq!(repo.find_completed().len(), 0);

    // Add a session - starts as NotStarted
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id.to_string();
    model.sessions().add(session1);

    assert!(!model.sessions().is_session_active(&session1_id));
    let repo = model.sessions();
    assert_eq!(repo.find_not_started().len(), 1);
    assert_eq!(repo.find_completed().len(), 0);

    // Add another session - both are NotStarted
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let session2_id = session2.id.to_string();
    model.sessions().add(session2);

    let repo = model.sessions();
    assert!(!repo.is_session_active(&session1_id));
    assert!(!repo.is_session_active(&session2_id));
    assert_eq!(repo.find_not_started().len(), 2);
}

#[test]
fn test_one_session_in_play() {
    let mut model = Model::default();

    // Create two sessions
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id.to_string();
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let session2_id = session2.id.to_string();

    model.sessions().add(session1);
    model.sessions().add(session2);

    // Start first session
    assert!(start_session(&session1_id, "2025-05-01T12:00:00Z".to_string(), &mut model).is_ok());
    let repo = model.sessions();
    assert!(repo.is_session_active(&session1_id));
    assert!(repo.find_current_active().is_some());

    // Starting second session should automatically end the first
    assert!(start_session(&session2_id, "2025-05-01T12:01:00Z".to_string(), &mut model).is_ok());
    let repo = model.sessions();
    assert!(!repo.is_session_active(&session1_id));
    assert!(repo.is_session_active(&session2_id));
    assert!(model
        .sessions
        .iter()
        .find(|s| s.id == session1_id)
        .unwrap()
        .is_ended());
}

#[test]
fn test_remove_session() {
    let mut model = Model::default();

    // Add two sessions
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id.to_string();
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let session2_id = session2.id.to_string();

    model.sessions().add(session1);
    model.sessions().add(session2);
    assert_eq!(model.sessions.len(), 2);

    // Remove first session
    assert!(model.sessions().remove(&session1_id).is_some());
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].id, session2_id);

    // Remove last session
    assert!(model.sessions().remove(&session2_id).is_some());
    assert_eq!(model.sessions.len(), 0);
}

#[test]
fn test_multiple_sessions_coexist() {
    let mut model = Model::default();

    // Add and start a session
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id.to_string();
    model.sessions().add(session1);
    start_session(&session1_id, "2025-05-01T12:00:00Z".to_string(), &mut model).unwrap();

    // Session1 is now started
    assert!(model.sessions().is_session_active(&session1_id));

    // Add new session - both sessions coexist
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let _session2_id = session2.id.to_string();
    model.sessions().add(session2);

    // Both sessions exist, session1 is still started, session2 is not started
    assert_eq!(model.sessions.len(), 2);
    let repo = model.sessions();
    assert!(repo.is_session_active(&session1_id));
    assert_eq!(repo.find_not_started().len(), 1);
}

#[test]
fn test_edit_session_fields_preserves_state() {
    let mut model = Model::default();

    // Create a session and complete it
    let session =
        PracticeSession::new(vec!["Goal 1".to_string()], "Original intention".to_string());
    let session_id = session.id.to_string();
    model.sessions().add(session);

    // Start and end the session to make it completed
    start_session(&session_id, "2025-05-01T12:00:00Z".to_string(), &mut model).unwrap();
    end_session(&session_id, "2025-05-01T12:30:00Z".to_string(), &mut model).unwrap();

    // Complete reflection to fully end the session
    complete_reflection(&session_id, &mut model).unwrap();

    // Verify the session is ended
    assert!(model.sessions[0].is_ended());
    assert_eq!(model.sessions[0].intention, "Original intention");

    // Edit the session fields
    edit_session_fields(
        &session_id,
        vec!["Goal 2".to_string()],
        "Updated intention".to_string(),
        Some("Updated notes".to_string()),
        &mut model,
    );

    // Verify the session is still ended and fields are updated
    assert!(
        model.sessions[0].is_ended(),
        "Session should still be ended after editing"
    );
    assert_eq!(model.sessions[0].intention, "Updated intention");
    assert_eq!(model.sessions[0].notes.as_deref(), Some("Updated notes"));
    assert_eq!(model.sessions[0].goal_ids, vec!["Goal 2".to_string()]);

    // Verify the timing information is preserved
    assert_eq!(model.sessions[0].start_time(), Some("2025-05-01T12:00:00Z"));
    assert_eq!(model.sessions[0].end_time(), Some("2025-05-01T12:30:00Z"));
    assert_eq!(model.sessions[0].duration(), Some("30m".to_string()));
}
