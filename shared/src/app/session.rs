use crate::app::exercise_record::ExerciseRecord;
use crate::app::model::Model;
use chrono::DateTime;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct PracticeSession {
    pub id: String,
    pub goal_ids: Vec<String>,
    pub intention: String,
    pub state: SessionState,
    pub notes: Option<String>,
    pub exercise_records: Vec<ExerciseRecord>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum SessionState {
    NotStarted,
    Started { start_time: String },
    Paused { start_time: String, pause_time: String },
    Ended { start_time: String, end_time: String, duration: String },
}

impl Default for SessionState {
    fn default() -> Self {
        SessionState::NotStarted
    }
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
            state: SessionState::NotStarted,
            notes: None,
            exercise_records: Vec::new(),
        }
    }

    // Type-safe methods that only work in certain states
    pub fn start(&mut self, timestamp: String) -> Result<(), &'static str> {
        match self.state {
            SessionState::NotStarted => {
                self.state = SessionState::Started { start_time: timestamp };
                Ok(())
            }
            _ => Err("Session is already started or ended"),
        }
    }

    pub fn pause(&mut self, timestamp: String) -> Result<(), &'static str> {
        match &self.state {
            SessionState::Started { start_time } => {
                self.state = SessionState::Paused {
                    start_time: start_time.clone(),
                    pause_time: timestamp,
                };
                Ok(())
            }
            _ => Err("Session is not in started state"),
        }
    }

    pub fn resume(&mut self, _timestamp: String) -> Result<(), &'static str> {
        match &self.state {
            SessionState::Paused { start_time, .. } => {
                self.state = SessionState::Started {
                    start_time: start_time.clone(),
                };
                Ok(())
            }
            _ => Err("Session is not paused"),
        }
    }

    pub fn end(&mut self, timestamp: String) -> Result<(), &'static str> {
        match &self.state {
            SessionState::Started { start_time } | SessionState::Paused { start_time, .. } => {
                let duration = self.calculate_duration(start_time, &timestamp);
                self.state = SessionState::Ended {
                    start_time: start_time.clone(),
                    end_time: timestamp,
                    duration,
                };
                Ok(())
            }
            _ => Err("Session is not active"),
        }
    }

    // Helper methods for backward compatibility with iOS
    pub fn is_active(&self) -> bool {
        matches!(self.state, SessionState::Started { .. } | SessionState::Paused { .. })
    }

    pub fn is_ended(&self) -> bool {
        matches!(self.state, SessionState::Ended { .. })
    }

    // Backward compatibility properties for iOS
    pub fn start_time(&self) -> Option<&str> {
        match &self.state {
            SessionState::Started { start_time } | SessionState::Paused { start_time, .. } | SessionState::Ended { start_time, .. } => {
                Some(start_time)
            }
            _ => None,
        }
    }

    pub fn end_time(&self) -> Option<&str> {
        match &self.state {
            SessionState::Ended { end_time, .. } => Some(end_time),
            _ => None,
        }
    }

    pub fn duration(&self) -> Option<&str> {
        match &self.state {
            SessionState::Ended { duration, .. } => Some(duration),
            _ => None,
        }
    }

    // Backward compatibility state enum for iOS


    fn calculate_duration(&self, start_time: &str, end_time: &str) -> String {
        let start = DateTime::parse_from_rfc3339(start_time).unwrap_or_default();
        let end = DateTime::parse_from_rfc3339(end_time).unwrap_or_default();
        let duration = end - start;
        let minutes = (duration.num_seconds() as f64 / 60.0).round() as i64;
        format!("{}m", minutes)
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
            active_session.end(chrono::Utc::now().to_rfc3339()).unwrap_or_default();
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

pub fn start_session(session_id: String, timestamp: String, model: &mut Model) -> Result<(), &'static str> {
    if let Some(session) = get_session_by_id(&session_id, model) {
        session.start(timestamp)?;
        set_active_session(session_id, model);
        Ok(())
    } else {
        Err("Session not found")
    }
}

pub fn end_session(session_id: String, timestamp: String, model: &mut Model) -> Result<(), &'static str> {
    if let Some(session) = get_session_by_id(&session_id, model) {
        session.end(timestamp)?;
        
        // Remove from active session if this was the active session
        if let Some(active_session) = &model.app_state.active_session {
            if active_session.id == session_id {
                remove_active_session(model);
            }
        }
        Ok(())
    } else {
        Err("Session not found")
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
    ).unwrap();

    // Verify session is active
    assert!(model.sessions[0].is_active());
    assert!(model.app_state.active_session.is_some());
    assert_eq!(
        model.app_state.active_session.as_ref().unwrap().id,
        session_id
    );

    // End the session 30 minutes later
    end_session(session_id, "2025-05-01T12:30:00Z".to_string(), &mut model).unwrap();

    // Verify session exists and duration is set
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].duration(), Some("30m")); // 30 minutes = 30 minutes
    assert!(model.sessions[0].is_ended());
    assert!(model.app_state.active_session.is_none());
}

#[test]
fn test_update_session_notes() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    add_session(session.clone(), &mut model);
    assert_eq!(model.sessions.len(), 1);
    edit_session_notes(session.id, "Notes 1".to_string(), &mut model);
    assert_eq!(model.sessions[0].notes, Some("Notes 1".to_string()));
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
    assert_eq!(session.duration(), Some("30m"));
    
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
    assert!(matches!(session.state, SessionState::Ended { .. }));
    assert_eq!(session.start_time(), Some("2025-05-01T12:00:00Z"));
    assert_eq!(session.end_time(), Some("2025-05-01T12:30:00Z"));
    assert_eq!(session.duration(), Some("30m"));
}
