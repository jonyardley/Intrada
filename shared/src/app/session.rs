use crate::app::exercise_record::ExerciseRecord;
use crate::app::model::Model;
use chrono::DateTime;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct PracticeSession {
    pub id: String,
    pub goal_ids: Vec<String>,
    pub intention: String,
    pub state: ActiveSessionState,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub notes: Option<String>,
    pub duration: Option<String>,
    pub exercise_records: Vec<ExerciseRecord>,
}

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub enum ActiveSessionState {
    #[default]
    NotStarted,
    Started,
    Paused,
    Ended,
}

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct ActiveSession {
    pub id: String,
}

impl PracticeSession {
    pub fn new(goal_ids: Vec<String>, intention: String) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            goal_ids,
            intention,
            state: ActiveSessionState::NotStarted,
            start_time: None,
            end_time: None,
            notes: None,
            duration: None,
            exercise_records: Vec::new(),
        }
    }

    fn calculate_duration(&self) -> Option<String> {
        let start_time = self.start_time.as_ref()?;
        let end_time = self.end_time.as_ref()?;

        let start = DateTime::parse_from_rfc3339(start_time).ok()?;
        let end = DateTime::parse_from_rfc3339(end_time).ok()?;

        let duration = end - start;
        let minutes = (duration.num_seconds() as f64 / 60.0).round() as i64;
        Some(format!("{}m", minutes))
    }
}

fn get_session_by_id<'a>(session_id: &str, model: &'a mut Model) -> Option<&'a mut PracticeSession> {
    model.sessions.iter_mut().find(|s| s.id == session_id)
}

pub fn add_session(session: PracticeSession, model: &mut Model) {
    let session_id = session.id.clone();
    
    // Check if there's an active session and end it if needed
    if let Some(active_session) = &model.app_state.active_session {
        let active_session_id = active_session.id.clone();
        if let Some(active_session) = get_session_by_id(&active_session_id, model) {
            active_session.state = ActiveSessionState::Ended;
        }
        remove_active_session(model);
    }
    
    model.sessions.push(session);
    set_active_session(session_id, model);
}

pub fn set_active_session(session_id: String, model: &mut Model) {
    model.app_state.active_session = Some(ActiveSession { id: session_id });
}

pub fn remove_active_session(model: &mut Model) {
    model.app_state.active_session = None;
}

pub fn edit_session(session: PracticeSession, model: &mut Model) {
    let index = model.sessions.iter().position(|s| s.id == session.id);
    if let Some(index) = index {
        model.sessions[index] = session;
    }
}

pub fn start_session(session_id: String, timestamp: String, model: &mut Model) {
    let index = model.sessions.iter().position(|s| s.id == session_id);
    if let Some(index) = index {
        model.sessions[index].start_time = Some(timestamp);
        model.sessions[index].state = ActiveSessionState::Started;
        set_active_session(session_id, model);
    }
}

pub fn end_session(session_id: String, timestamp: String, model: &mut Model) {
    let index = model.sessions.iter().position(|s| s.id == session_id);
    if let Some(index) = index {
        model.sessions[index].end_time = Some(timestamp);
        model.sessions[index].duration = model.sessions[index].calculate_duration();
        model.sessions[index].state = ActiveSessionState::Ended;

        // Remove from active session if this was the active session
        if let Some(active_session) = &model.app_state.active_session {
            if active_session.id == session_id {
                remove_active_session(model);
            }
        }
    }
}

pub fn edit_session_notes(session_id: String, notes: String, model: &mut Model) {
    let index = model.sessions.iter().position(|s| s.id == session_id);
    if let Some(index) = index {
        model.sessions[index].notes = Some(notes);
    }
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
    let session_id = session.id.clone();
    add_session(session, &mut model);

    // Start the session
    start_session(
        session_id.clone(),
        "2025-05-01T12:00:00Z".to_string(),
        &mut model,
    );

    // Verify session is active
    assert_eq!(model.sessions[0].state, ActiveSessionState::Started);
    assert!(model.app_state.active_session.is_some());
    assert_eq!(
        model.app_state.active_session.as_ref().unwrap().id,
        session_id
    );

    // End the session 30 minutes later
    end_session(session_id, "2025-05-01T12:30:00Z".to_string(), &mut model);

    // Verify session exists and duration is set
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].duration, Some("30m".to_string())); // 30 minutes = 30 minutes
    assert_eq!(model.sessions[0].state, ActiveSessionState::Ended);
    assert!(model.app_state.active_session.is_none());
}

#[test]
fn test_update_session_notes() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    add_session(session.clone(), &mut model);
    assert_eq!(model.sessions.len(), 1);
    edit_session_notes(session.id, "Notes 1".to_string(), &mut model); // TODO: fix this
    assert_eq!(model.sessions[0].notes, Some("Notes 1".to_string()));
}
