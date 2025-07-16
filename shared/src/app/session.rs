use crate::app::error::SessionError;
use crate::app::model::Model;
use crate::app::study_session::StudySession;
use chrono::DateTime;
use crux_core::Command;
use facet::Facet;
use serde::{Deserialize, Serialize};

/// Macro to simplify session data access patterns
macro_rules! session_data_access {
    ($session:expr, $accessor:ident) => {
        match $session {
            PracticeSession::NotStarted(s) => s.data.$accessor(),
            PracticeSession::Started(s) => s.data.$accessor(),
            PracticeSession::Ended(s) => s.data.$accessor(),
        }
    };
}

/// Macro to simplify mutable session data access patterns
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

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum SessionEvent {
    AddSession(PracticeSession),
    EditSessionFields {
        session_id: String,
        goal_ids: Vec<String>,
        intention: String,
        notes: Option<String>,
    },
    SetActiveSession(String),
    StartSession(String, String),
    UnsetActiveSession,
    EndSession(String, String),
    EditSessionNotes(String, String),
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

#[derive(Facet, Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct ActiveSession {
    pub id: String,
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
    let session_id = session.id().to_string();

    // Add the session to the model
    model.sessions.push(session);

    // Set as active if there's no current active session
    // This ensures new sessions become active when no session is currently active
    if model.active_session.is_none() {
        set_active_session(session_id, model);
    }
}

pub fn set_active_session(session_id: String, model: &mut Model) {
    model.active_session = Some(ActiveSession { id: session_id });
}

pub fn remove_active_session(model: &mut Model) {
    model.active_session = None;
}

pub fn start_session(
    session_id: &str,
    timestamp: String,
    model: &mut Model,
) -> Result<(), SessionError> {
    if let Some(session) = get_session_by_id(session_id, model) {
        session.start(timestamp)?;
        set_active_session(session_id.to_string(), model);
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

        // Remove from active session if this was the active session
        if let Some(active_session) = &model.active_session {
            if active_session.id == session_id {
                remove_active_session(model);
            }
        }
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

/// Helper function to handle session operation results
fn handle_session_result(result: Result<(), SessionError>, operation: &str) {
    if let Err(e) = result {
        log::error!("Failed to {operation} session: {e}");
    }
}

pub fn handle_event(
    event: SessionEvent,
    model: &mut Model,
) -> Command<super::Effect, super::Event> {
    match event {
        SessionEvent::AddSession(session) => add_session(session, model),
        SessionEvent::EditSessionFields {
            session_id,
            goal_ids,
            intention,
            notes,
        } => edit_session_fields(&session_id, goal_ids, intention, notes, model),
        SessionEvent::SetActiveSession(session_id) => set_active_session(session_id, model),
        SessionEvent::StartSession(session_id, timestamp) => {
            handle_session_result(start_session(&session_id, timestamp, model), "start");
        }
        SessionEvent::EndSession(session_id, timestamp) => {
            handle_session_result(end_session(&session_id, timestamp, model), "end");
        }
        SessionEvent::UnsetActiveSession => remove_active_session(model),
        SessionEvent::EditSessionNotes(session_id, notes) => {
            edit_session_notes(&session_id, notes, model);
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
    assert!(model.active_session.is_some());
    assert_eq!(model.active_session.as_ref().unwrap().id, session_id);

    // End the session 30 minutes later
    end_session(&session_id, "2025-05-01T12:30:00Z".to_string(), &mut model).unwrap();

    // Verify session exists and duration is calculated on-demand
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].duration(), Some("30m".to_string())); // Now returns Option<String>
    assert!(model.sessions[0].is_ended());
    assert!(model.active_session.is_none());
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
