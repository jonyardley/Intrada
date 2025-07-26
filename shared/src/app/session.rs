use crate::app::error::SessionError;
use crate::app::model::Model;
use crate::app::study_session::StudySession;
use chrono::DateTime;
use crux_core::Command;
use facet::Facet;
use serde::{Deserialize, Serialize};

/// Macro to simplify session data access patterns.
///
/// # Purpose
/// This macro provides a unified way to access data fields from a `PracticeSession` enum,
/// regardless of its state (`NotStarted`, `Started`, or `Ended`).
///
/// # Parameters
/// - `$session`: The `PracticeSession` instance to access.
/// - `$accessor`: The method or field to access on the `data` field of the session.
///
/// # Example
/// ```ignore
/// let session = PracticeSession::Started(started_session);
/// let goal_ids = session_data_access!(session, goal_ids);
/// ```
macro_rules! session_data_access {
    ($session:expr, $accessor:ident) => {
        match $session {
            PracticeSession::NotStarted(s) => s.data.$accessor(),
            PracticeSession::Started(s) => s.data.$accessor(),
            PracticeSession::Ended(s) => s.data.$accessor(),
        }
    };
}

/// Macro to simplify mutable session data access patterns.
///
/// # Purpose
/// This macro provides a convenient way to access mutable fields of the `data` property
/// within different states of a `PracticeSession` (e.g., `NotStarted`, `Started`, `Ended`).
///
/// # Parameters
/// - `$session`: The `PracticeSession` instance to access.
/// - `$accessor`: The name of the method or field to access on the `data` property.
///
/// # Example
/// ```ignore
/// let mut session = PracticeSession::Started(started_session);
/// session_data_access_mut!(session, some_mutable_field) = new_value;
/// ```
macro_rules! session_data_access_mut {
    ($session:expr, $accessor:ident) => {
        match $session {
            PracticeSession::NotStarted(s) => s.data.$accessor(),
            PracticeSession::Started(s) => s.data.$accessor(),
            PracticeSession::Ended(s) => s.data.$accessor(),
        }
    };
}

// Common session data that all session states share
#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct SessionData {
    id: String,
    pub goal_ids: Vec<String>,
    pub intention: String,
    pub notes: Option<String>,
    pub study_sessions: Vec<StudySession>,
}

pub fn session_view_model(session: &PracticeSession) -> PracticeSessionView {
    PracticeSessionView {
        id: session.id().to_string(),
        goal_ids: session.goal_ids().clone(),
        intention: session.intention().clone(),
        state: session.state(),
        notes: session.notes().clone(),
        study_sessions: session.study_sessions().clone(),
        duration: session.duration(),
        start_time: session.start_time().map(std::string::ToString::to_string),
        end_time: session.end_time().map(std::string::ToString::to_string),
        is_ended: session.is_ended(),
    }
}

pub fn session_from_view_model(view: PracticeSessionView) -> PracticeSession {
    let session_data = SessionData {
        id: view.id,
        goal_ids: view.goal_ids,
        intention: view.intention,
        notes: view.notes,
        study_sessions: view.study_sessions,
    };

    match view.state {
        SessionState::NotStarted => {
            PracticeSession::NotStarted(NotStartedSession { data: session_data })
        }
        SessionState::Started { start_time } => PracticeSession::Started(StartedSession {
            data: session_data,
            start_time,
        }),
        SessionState::Ended {
            start_time,
            end_time,
        } => PracticeSession::Ended(EndedSession {
            data: session_data,
            start_time,
            end_time,
        }),
    }
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum SessionEvent {
    FetchSessions,
    #[serde(skip)]
    #[facet(skip)]
    SetSessions(
        crate::HttpResult<crux_http::Response<Vec<PracticeSessionView>>, crux_http::HttpError>,
    ),
    CreateSession(PracticeSession),
    #[serde(skip)]
    #[facet(skip)]
    SessionCreated(
        crate::HttpResult<crux_http::Response<PracticeSessionView>, crux_http::HttpError>,
    ),
    UpdateSession(PracticeSession),
    #[serde(skip)]
    #[facet(skip)]
    SessionUpdated(
        crate::HttpResult<crux_http::Response<PracticeSessionView>, crux_http::HttpError>,
    ),
    AddSession(PracticeSession),
    EditSessionFields {
        session_id: String,
        goal_ids: Vec<String>,
        intention: String,
        notes: Option<String>,
    },
    StartSession(String, String),
    #[serde(skip)]
    #[facet(skip)]
    SessionStarted(
        crate::HttpResult<crux_http::Response<PracticeSessionView>, crux_http::HttpError>,
    ),
    EndSession(String, String),
    #[serde(skip)]
    #[facet(skip)]
    SessionEnded(crate::HttpResult<crux_http::Response<PracticeSessionView>, crux_http::HttpError>),
    EditSessionNotes(String, String),
    RemoveSession(String),
    // Optimistic local events
    CreateSessionOptimistic(PracticeSession),
    UpdateSessionOptimistic(PracticeSession),
    StartSessionOptimistic(String, String),
    EndSessionOptimistic(String, String),
}

impl SessionData {
    pub fn new(goal_ids: Vec<String>, intention: String) -> Self {
        Self {
            id: crate::app::generate_id(),
            goal_ids,
            intention,
            notes: None,
            study_sessions: Vec::new(),
        }
    }

    pub fn id(&self) -> &str {
        &self.id
    }
    pub fn goal_ids(&self) -> &Vec<String> {
        &self.goal_ids
    }
    pub fn intention(&self) -> &String {
        &self.intention
    }
    pub fn notes(&self) -> &Option<String> {
        &self.notes
    }
    pub fn study_sessions(&self) -> &Vec<StudySession> {
        &self.study_sessions
    }
    pub fn goal_ids_mut(&mut self) -> &mut Vec<String> {
        &mut self.goal_ids
    }
    pub fn intention_mut(&mut self) -> &mut String {
        &mut self.intention
    }
    pub fn notes_mut(&mut self) -> &mut Option<String> {
        &mut self.notes
    }
    pub fn study_sessions_mut(&mut self) -> &mut Vec<StudySession> {
        &mut self.study_sessions
    }
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub struct NotStartedSession {
    pub data: SessionData,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct StartedSession {
    pub data: SessionData,
    pub start_time: String,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct EndedSession {
    pub data: SessionData,
    pub start_time: String,
    pub end_time: String,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum PracticeSession {
    NotStarted(NotStartedSession),
    Started(StartedSession),
    Ended(EndedSession),
}

impl NotStartedSession {
    pub fn new(goal_ids: Vec<String>, intention: String) -> Self {
        Self {
            data: SessionData::new(goal_ids, intention),
        }
    }

    pub fn id(&self) -> &str {
        self.data.id()
    }

    pub fn start(self, start_time: String) -> StartedSession {
        StartedSession {
            data: self.data,
            start_time,
        }
    }
}

impl StartedSession {
    pub fn id(&self) -> &str {
        self.data.id()
    }

    pub fn end(self, end_time: String) -> EndedSession {
        EndedSession {
            data: self.data,
            start_time: self.start_time,
            end_time,
        }
    }
}

impl EndedSession {
    pub fn id(&self) -> &str {
        self.data.id()
    }
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[repr(C)]
pub enum SessionState {
    #[default]
    NotStarted,
    Started {
        start_time: String,
    },
    Ended {
        start_time: String,
        end_time: String,
    },
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct PracticeSessionView {
    pub id: String,
    pub goal_ids: Vec<String>,
    pub intention: String,
    pub state: SessionState,
    pub notes: Option<String>,
    pub study_sessions: Vec<StudySession>,
    pub duration: Option<String>,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub is_ended: bool,
}

impl PracticeSession {
    pub fn new(goal_ids: Vec<String>, intention: String) -> Self {
        Self::NotStarted(NotStartedSession::new(goal_ids, intention))
    }

    // Delegate common methods to the SessionData through the variants using macros
    pub fn id(&self) -> &str {
        session_data_access!(self, id)
    }

    pub fn goal_ids(&self) -> &Vec<String> {
        session_data_access!(self, goal_ids)
    }

    pub fn intention(&self) -> &String {
        session_data_access!(self, intention)
    }

    pub fn notes(&self) -> &Option<String> {
        session_data_access!(self, notes)
    }

    pub fn study_sessions(&self) -> &Vec<StudySession> {
        session_data_access!(self, study_sessions)
    }

    pub fn study_sessions_mut(&mut self) -> &mut Vec<StudySession> {
        session_data_access_mut!(self, study_sessions_mut)
    }

    pub fn start(&mut self, timestamp: String) -> Result<(), SessionError> {
        match std::mem::replace(
            self,
            PracticeSession::NotStarted(NotStartedSession::new(vec![], String::new())),
        ) {
            PracticeSession::NotStarted(session) => {
                *self = PracticeSession::Started(session.start(timestamp));
                Ok(())
            }
            PracticeSession::Started(session) => {
                *self = PracticeSession::Started(session);
                Err(SessionError::AlreadyStarted)
            }
            PracticeSession::Ended(session) => {
                *self = PracticeSession::Ended(session);
                Err(SessionError::AlreadyEnded)
            }
        }
    }

    pub fn end(&mut self, timestamp: String) -> Result<(), SessionError> {
        match std::mem::replace(
            self,
            PracticeSession::NotStarted(NotStartedSession::new(vec![], String::new())),
        ) {
            PracticeSession::Started(session) => {
                *self = PracticeSession::Ended(session.end(timestamp));
                Ok(())
            }
            PracticeSession::NotStarted(session) => {
                *self = PracticeSession::NotStarted(session);
                Err(SessionError::NotActive)
            }
            PracticeSession::Ended(session) => {
                *self = PracticeSession::Ended(session);
                Err(SessionError::AlreadyEnded)
            }
        }
    }

    // Helper methods for backward compatibility with iOS
    pub fn is_active(&self) -> bool {
        matches!(self, PracticeSession::Started(_))
    }

    pub fn is_ended(&self) -> bool {
        matches!(self, PracticeSession::Ended(_))
    }

    // Backward compatibility properties for iOS
    pub fn start_time(&self) -> Option<&str> {
        match self {
            PracticeSession::Started(session) => Some(session.start_time.as_str()),
            PracticeSession::Ended(session) => Some(session.start_time.as_str()),
            PracticeSession::NotStarted(_) => None,
        }
    }

    pub fn end_time(&self) -> Option<&str> {
        match self {
            PracticeSession::Ended(session) => Some(session.end_time.as_str()),
            PracticeSession::NotStarted(_) | PracticeSession::Started(_) => None,
        }
    }

    pub fn duration(&self) -> Option<String> {
        match self {
            PracticeSession::Ended(session) => {
                calculate_duration(session.start_time.as_str(), session.end_time.as_str())
            }
            PracticeSession::NotStarted(_) | PracticeSession::Started(_) => None,
        }
    }

    pub fn state(&self) -> SessionState {
        match self {
            PracticeSession::NotStarted(_) => SessionState::NotStarted,
            PracticeSession::Started(s) => SessionState::Started {
                start_time: s.start_time.clone(),
            },
            PracticeSession::Ended(s) => SessionState::Ended {
                start_time: s.start_time.clone(),
                end_time: s.end_time.clone(),
            },
        }
    }

    // Mutator: push a StudySession
    pub fn push_study_session(&mut self, session: StudySession) {
        self.study_sessions_mut().push(session);
    }

    // Mutator: update a StudySession by id
    pub fn update_study_session(&mut self, session: StudySession) {
        if let Some(existing) = self
            .study_sessions_mut()
            .iter_mut()
            .find(|r| r.id == session.id)
        {
            *existing = session;
        }
    }
}

// Public duration calculation function for use by viewmodel
#[allow(clippy::cast_precision_loss, clippy::cast_possible_truncation)]
pub fn calculate_duration(start_time: &str, end_time: &str) -> Option<String> {
    let start = DateTime::parse_from_rfc3339(start_time).ok()?;
    let end = DateTime::parse_from_rfc3339(end_time).ok()?;
    let duration = end - start;
    let minutes = (duration.num_seconds() as f64 / 60.0).round() as i64;
    Some(format!("{minutes}m"))
}

fn get_session_by_id<'a>(
    session_id: &str,
    model: &'a mut Model,
) -> Option<&'a mut PracticeSession> {
    model.sessions.iter_mut().find(|s| s.id() == session_id)
}

pub fn add_session(session: PracticeSession, model: &mut Model) {
    // Simply add the session to the model
    // No need for active session logic - sessions start as NotStarted
    model.sessions.push(session);
}

/// Remove a session from the model
pub fn remove_session(session_id: &str, model: &mut Model) -> bool {
    // Remove the session
    let original_len = model.sessions.len();
    model.sessions.retain(|s| s.id() != session_id);
    model.sessions.len() < original_len
}

/// Get the currently started session, if any
pub fn get_started_session(model: &Model) -> Option<&PracticeSession> {
    model.sessions.iter().find(|s| s.is_active())
}

/// Get the currently started session mutably, if any
pub fn get_started_session_mut(model: &mut Model) -> Option<&mut PracticeSession> {
    model.sessions.iter_mut().find(|s| s.is_active())
}

/// Check if a specific session is currently started
pub fn is_session_started(session_id: &str, model: &Model) -> bool {
    model
        .sessions
        .iter()
        .any(|s| s.id() == session_id && s.is_active())
}

/// Get all not started sessions
pub fn get_not_started_sessions(model: &Model) -> Vec<&PracticeSession> {
    model
        .sessions
        .iter()
        .filter(|s| matches!(s, PracticeSession::NotStarted(_)))
        .collect()
}

/// Get all ended sessions
pub fn get_ended_sessions(model: &Model) -> Vec<&PracticeSession> {
    model
        .sessions
        .iter()
        .filter(|s| matches!(s, PracticeSession::Ended(_)))
        .collect()
}

pub fn start_session(
    session_id: &str,
    timestamp: String,
    model: &mut Model,
) -> Result<(), SessionError> {
    // Ensure only one session can be started at a time
    // If there's already a started session, end it first
    if let Some(current_started) = get_started_session_mut(model) {
        let current_id = current_started.id().to_string();
        if current_id != session_id {
            // End the currently started session
            current_started.end(timestamp.clone())?;
        }
    }

    if let Some(session) = get_session_by_id(session_id, model) {
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
    if let Some(session) = get_session_by_id(session_id, model) {
        session.end(timestamp)?;
        Ok(())
    } else {
        Err(SessionError::NotFound)
    }
}

pub fn edit_session_notes(session_id: &str, notes: String, model: &mut Model) {
    if let Some(session) = model.sessions.iter_mut().find(|s| s.id() == session_id) {
        *session_data_access_mut!(session, notes_mut) = Some(notes);
    }
}

// Clean implementation using the SessionData and macros
pub fn edit_session_fields(
    session_id: &str,
    goal_ids: Vec<String>,
    intention: String,
    notes: Option<String>,
    model: &mut Model,
) {
    if let Some(session) = model.sessions.iter_mut().find(|s| s.id() == session_id) {
        *session_data_access_mut!(session, goal_ids_mut) = goal_ids;
        *session_data_access_mut!(session, intention_mut) = intention;
        *session_data_access_mut!(session, notes_mut) = notes;
    }
}

pub fn handle_event(
    event: SessionEvent,
    model: &mut Model,
) -> Command<super::Effect, super::Event> {
    match event {
        SessionEvent::FetchSessions => {
            let api = crate::app::ApiConfig::default();
            return api.get("/api/sessions", |response| {
                super::Event::Session(SessionEvent::SetSessions(response))
            });
        }
        SessionEvent::SetSessions(crate::HttpResult::Ok(mut response)) => {
            let session_views = response.take_body().unwrap();
            model.sessions = session_views
                .into_iter()
                .map(session_from_view_model)
                .collect();
        }
        SessionEvent::SetSessions(crate::HttpResult::Err(e)) => {
            return crate::app::handle_http_error(e, "fetch sessions");
        }

        SessionEvent::CreateSession(session) => {
            // Transform PracticeSession to create request format
            let create_request = serde_json::json!({
                "goal_ids": session.goal_ids(),
                "intention": session.intention(),
                "notes": session.notes()
            });

            let api = crate::app::ApiConfig::default();
            return api.post("/api/sessions", &create_request, |response| {
                super::Event::Session(SessionEvent::SessionCreated(response))
            });
        }
        SessionEvent::SessionCreated(crate::HttpResult::Ok(mut response)) => {
            let _session_view = response.take_body().unwrap();
            // Refresh the entire sessions list from server after creation
            return Command::event(super::Event::Session(SessionEvent::FetchSessions));
        }
        SessionEvent::SessionCreated(crate::HttpResult::Err(e)) => {
            return crate::app::handle_http_error(e, "create session");
        }

        SessionEvent::UpdateSession(session) => {
            let api = crate::app::ApiConfig::default();
            return api.put(
                &format!("/api/sessions/{}", session.id()),
                &session_view_model(&session),
                |response| super::Event::Session(SessionEvent::SessionUpdated(response)),
            );
        }
        SessionEvent::SessionUpdated(crate::HttpResult::Ok(mut response)) => {
            let _session_view = response.take_body().unwrap();
            // Refresh the entire sessions list from server after update
            return Command::event(super::Event::Session(SessionEvent::FetchSessions));
        }
        SessionEvent::SessionUpdated(crate::HttpResult::Err(e)) => {
            return crate::app::handle_http_error(e, "update session");
        }

        SessionEvent::StartSession(session_id, timestamp) => {
            let start_request = serde_json::json!({
                "start_time": timestamp
            });

            let api = crate::app::ApiConfig::default();
            return api.post(
                &format!("/api/sessions/{session_id}/start"),
                &start_request,
                |response| super::Event::Session(SessionEvent::SessionStarted(response)),
            );
        }
        SessionEvent::SessionStarted(crate::HttpResult::Ok(mut response)) => {
            let _session_view = response.take_body().unwrap();
            // Refresh the entire sessions list from server after starting
            return Command::event(super::Event::Session(SessionEvent::FetchSessions));
        }
        SessionEvent::SessionStarted(crate::HttpResult::Err(e)) => {
            return crate::app::handle_http_error(e, "start session");
        }

        SessionEvent::EndSession(session_id, timestamp) => {
            let end_request = serde_json::json!({
                "end_time": timestamp
            });

            let api = crate::app::ApiConfig::default();
            return api.post(
                &format!("/api/sessions/{session_id}/end"),
                &end_request,
                |response| super::Event::Session(SessionEvent::SessionEnded(response)),
            );
        }
        SessionEvent::SessionEnded(crate::HttpResult::Ok(mut response)) => {
            let _session_view = response.take_body().unwrap();
            // Refresh the entire sessions list from server after ending
            return Command::event(super::Event::Session(SessionEvent::FetchSessions));
        }
        SessionEvent::SessionEnded(crate::HttpResult::Err(e)) => {
            return crate::app::handle_http_error(e, "end session");
        }

        // Local-only events (backward compatibility)
        SessionEvent::AddSession(session) => add_session(session, model),
        SessionEvent::EditSessionFields {
            session_id,
            goal_ids,
            intention,
            notes,
        } => edit_session_fields(&session_id, goal_ids, intention, notes, model),
        SessionEvent::EditSessionNotes(session_id, notes) => {
            edit_session_notes(&session_id, notes, model);
        }
        SessionEvent::RemoveSession(session_id) => {
            remove_session(&session_id, model);
        }

        // Optimistic local events - apply immediately, trigger sync later
        SessionEvent::CreateSessionOptimistic(session) => {
            add_session(session.clone(), model);
            // Trigger background sync
            let api = crate::app::ApiConfig::default();
            return api.post("/api/sessions", &session_view_model(&session), |response| {
                super::Event::Session(SessionEvent::SessionCreated(response))
            });
        }
        SessionEvent::UpdateSessionOptimistic(session) => {
            // Update local session by ID
            if let Some(existing) = model.sessions.iter_mut().find(|s| s.id() == session.id()) {
                *existing = session.clone();
            }
            // Trigger background sync
            let api = crate::app::ApiConfig::default();
            return api.put(
                &format!("/api/sessions/{}", session.id()),
                &session_view_model(&session),
                |response| super::Event::Session(SessionEvent::SessionUpdated(response)),
            );
        }
        SessionEvent::StartSessionOptimistic(session_id, timestamp) => {
            // Apply optimistically to local model
            if let Err(e) = start_session(&session_id, timestamp.clone(), model) {
                model.last_error = Some(format!("Failed to start session: {e:?}"));
                return crux_core::render::render();
            }
            
            // Trigger background sync
            let start_request = serde_json::json!({ "start_time": timestamp });
            let api = crate::app::ApiConfig::default();
            return api.post(
                &format!("/api/sessions/{session_id}/start"),
                &start_request,
                |response| super::Event::Session(SessionEvent::SessionStarted(response)),
            );
        }
        SessionEvent::EndSessionOptimistic(session_id, timestamp) => {
            // Apply optimistically to local model
            if let Err(e) = end_session(&session_id, timestamp.clone(), model) {
                model.last_error = Some(format!("Failed to end session: {e:?}"));
                return crux_core::render::render();
            }
            
            // Trigger background sync
            let end_request = serde_json::json!({ "end_time": timestamp });
            let api = crate::app::ApiConfig::default();
            return api.post(
                &format!("/api/sessions/{session_id}/end"),
                &end_request,
                |response| super::Event::Session(SessionEvent::SessionEnded(response)),
            );
        }
    }

    crux_core::render::render()
}

// *************
// TESTS
// *************

#[test]
fn test_add_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    add_session(session, &mut model);
    assert_eq!(model.sessions.len(), 1);
}

#[test]
fn test_edit_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    add_session(session, &mut model);
    assert_eq!(model.sessions.len(), 1);
}

#[test]
fn test_start_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    add_session(session, &mut model);
    assert_eq!(model.sessions.len(), 1);
}

#[test]
fn test_end_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    let session_id = session.id().to_string();
    add_session(session, &mut model);

    // Start the session
    start_session(&session_id, "2025-05-01T12:00:00Z".to_string(), &mut model).unwrap();

    // Verify session is active
    assert!(model.sessions[0].is_active());
    assert!(get_started_session(&model).is_some());
    assert_eq!(get_started_session(&model).unwrap().id(), session_id);

    // End the session 30 minutes later
    end_session(&session_id, "2025-05-01T12:30:00Z".to_string(), &mut model).unwrap();

    // Verify session exists and duration is calculated on-demand
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].duration(), Some("30m".to_string())); // Now returns Option<String>
    assert!(model.sessions[0].is_ended());
    assert!(get_started_session(&model).is_none());
}

#[test]
fn test_update_session_notes() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    add_session(session.clone(), &mut model);
    assert_eq!(model.sessions.len(), 1);
    edit_session_notes(session.id(), "Notes 1".to_string(), &mut model);
    assert_eq!(
        model.sessions[0]
            .notes()
            .as_ref()
            .map(std::string::String::as_str),
        Some("Notes 1")
    );
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
    assert!(matches!(session, PracticeSession::NotStarted(_)));
    assert_eq!(session.start_time(), None);
    assert_eq!(session.end_time(), None);
    assert_eq!(session.duration(), None);

    // Test after starting
    session.start("2025-05-01T12:00:00Z".to_string()).unwrap();
    assert!(matches!(session, PracticeSession::Started(_)));
    assert_eq!(session.start_time(), Some("2025-05-01T12:00:00Z"));

    // Test after ending
    session.end("2025-05-01T12:30:00Z".to_string()).unwrap();
    assert!(matches!(session, PracticeSession::Ended(_)));
    assert_eq!(session.start_time(), Some("2025-05-01T12:00:00Z"));
    assert_eq!(session.end_time(), Some("2025-05-01T12:30:00Z"));
    assert_eq!(session.duration(), Some("30m".to_string()));
}

#[test]
fn test_calculate_duration_function() {
    let duration = calculate_duration("2025-05-01T12:00:00Z", "2025-05-01T12:30:00Z");
    assert_eq!(duration, Some("30m".to_string()));

    let duration = calculate_duration("2025-05-01T12:00:00Z", "2025-05-01T12:00:00Z");
    assert_eq!(duration, Some("0m".to_string()));

    let duration = calculate_duration("2025-05-01T12:00:00Z", "2025-05-01T13:15:00Z");
    assert_eq!(duration, Some("75m".to_string()));
}

#[test]
fn test_session_view_model_conversion() {
    // Test NotStarted session
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Test intention".to_string());
    let view = session_view_model(&session);
    let converted_back = session_from_view_model(view);

    assert_eq!(session.id(), converted_back.id());
    assert_eq!(session.goal_ids(), converted_back.goal_ids());
    assert_eq!(session.intention(), converted_back.intention());
    assert!(matches!(converted_back, PracticeSession::NotStarted(_)));

    // Test Started session
    let mut session =
        PracticeSession::new(vec!["Goal 1".to_string()], "Test intention".to_string());
    session.start("2025-05-01T12:00:00Z".to_string()).unwrap();
    let view = session_view_model(&session);
    let converted_back = session_from_view_model(view);

    assert_eq!(session.id(), converted_back.id());
    assert_eq!(session.start_time(), converted_back.start_time());
    assert!(matches!(converted_back, PracticeSession::Started(_)));

    // Test Ended session
    session.end("2025-05-01T12:30:00Z".to_string()).unwrap();
    let view = session_view_model(&session);
    let converted_back = session_from_view_model(view);

    assert_eq!(session.id(), converted_back.id());
    assert_eq!(session.start_time(), converted_back.start_time());
    assert_eq!(session.end_time(), converted_back.end_time());
    assert_eq!(session.duration(), converted_back.duration());
    assert!(matches!(converted_back, PracticeSession::Ended(_)));
}

#[test]
fn test_session_helpers() {
    let mut model = Model::default();

    // Test no started session initially
    assert!(get_started_session(&model).is_none());
    assert_eq!(get_not_started_sessions(&model).len(), 0);
    assert_eq!(get_ended_sessions(&model).len(), 0);

    // Add a session - starts as NotStarted
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id().to_string();
    add_session(session1, &mut model);

    assert!(!is_session_started(&session1_id, &model));
    assert_eq!(get_not_started_sessions(&model).len(), 1);
    assert_eq!(get_ended_sessions(&model).len(), 0);

    // Add another session - both are NotStarted
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let session2_id = session2.id().to_string();
    add_session(session2, &mut model);

    assert!(!is_session_started(&session1_id, &model));
    assert!(!is_session_started(&session2_id, &model));
    assert_eq!(get_not_started_sessions(&model).len(), 2);
}

#[test]
fn test_one_session_in_play() {
    let mut model = Model::default();

    // Create two sessions
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id().to_string();
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let session2_id = session2.id().to_string();

    add_session(session1, &mut model);
    add_session(session2, &mut model);

    // Start first session
    assert!(start_session(&session1_id, "2025-05-01T12:00:00Z".to_string(), &mut model).is_ok());
    assert!(is_session_started(&session1_id, &model));
    assert!(get_started_session(&model).is_some());

    // Starting second session should automatically end the first
    assert!(start_session(&session2_id, "2025-05-01T12:01:00Z".to_string(), &mut model).is_ok());
    assert!(!is_session_started(&session1_id, &model));
    assert!(is_session_started(&session2_id, &model));
    assert!(model
        .sessions
        .iter()
        .find(|s| s.id() == session1_id)
        .unwrap()
        .is_ended());
}

#[test]
fn test_remove_session() {
    let mut model = Model::default();

    // Add two sessions
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id().to_string();
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let session2_id = session2.id().to_string();

    add_session(session1, &mut model);
    add_session(session2, &mut model);
    assert_eq!(model.sessions.len(), 2);

    // Remove first session
    assert!(remove_session(&session1_id, &mut model));
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].id(), session2_id);

    // Remove last session
    assert!(remove_session(&session2_id, &mut model));
    assert_eq!(model.sessions.len(), 0);
}

#[test]
fn test_multiple_sessions_coexist() {
    let mut model = Model::default();

    // Add and start a session
    let session1 = PracticeSession::new(vec!["Goal 1".to_string()], "Session 1".to_string());
    let session1_id = session1.id().to_string();
    add_session(session1, &mut model);
    start_session(&session1_id, "2025-05-01T12:00:00Z".to_string(), &mut model).unwrap();

    // Session1 is now started
    assert!(is_session_started(&session1_id, &model));

    // Add new session - both sessions coexist
    let session2 = PracticeSession::new(vec!["Goal 2".to_string()], "Session 2".to_string());
    let _session2_id = session2.id().to_string();
    add_session(session2, &mut model);

    // Both sessions exist, session1 is still started, session2 is not started
    assert_eq!(model.sessions.len(), 2);
    assert!(is_session_started(&session1_id, &model));
    assert_eq!(get_not_started_sessions(&model).len(), 1);
}

#[test]
fn test_edit_session_fields_preserves_state() {
    let mut model = Model::default();

    // Create a session and complete it
    let session =
        PracticeSession::new(vec!["Goal 1".to_string()], "Original intention".to_string());
    let session_id = session.id().to_string();
    add_session(session, &mut model);

    // Start and end the session to make it completed
    start_session(&session_id, "2025-05-01T12:00:00Z".to_string(), &mut model).unwrap();
    end_session(&session_id, "2025-05-01T12:30:00Z".to_string(), &mut model).unwrap();

    // Verify the session is ended
    assert!(model.sessions[0].is_ended());
    assert_eq!(model.sessions[0].intention(), "Original intention");

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
    assert_eq!(model.sessions[0].intention(), "Updated intention");
    assert_eq!(
        model.sessions[0]
            .notes()
            .as_ref()
            .map(std::string::String::as_str),
        Some("Updated notes")
    );
    assert_eq!(model.sessions[0].goal_ids(), &vec!["Goal 2".to_string()]);

    // Verify the timing information is preserved
    assert_eq!(model.sessions[0].start_time(), Some("2025-05-01T12:00:00Z"));
    assert_eq!(model.sessions[0].end_time(), Some("2025-05-01T12:30:00Z"));
    assert_eq!(model.sessions[0].duration(), Some("30m".to_string()));
}
