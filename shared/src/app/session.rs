use crate::app::model::Model;
use chrono::DateTime;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct PracticeSession {
    pub id: String,
    pub goal_ids: Vec<String>,
    pub intention: String,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub notes: Option<String>,
    pub duration: Option<String>,
}

impl PracticeSession {
    pub fn new(goal_ids: Vec<String>, intention: String) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            goal_ids,
            intention,
            start_time: None,
            end_time: None,
            notes: None,
            duration: None,
        }
    }
}

pub fn add_session(session: PracticeSession, model: &mut Model) {
    model.sessions.push(session);
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
    }
}

pub fn end_session(session_id: String, timestamp: String, model: &mut Model) {
    let index = model.sessions.iter().position(|s| s.id == session_id);
    if let Some(index) = index {
        model.sessions[index].end_time = Some(timestamp);

        // Calculate duration if both start and end times exist
        if let (Some(start_time), Some(end_time)) = (
            &model.sessions[index].start_time,
            &model.sessions[index].end_time,
        ) {
            if let (Ok(start), Ok(end)) = (
                DateTime::parse_from_rfc3339(start_time),
                DateTime::parse_from_rfc3339(end_time),
            ) {
                let duration = end - start;
                let minutes = (duration.num_seconds() as f64 / 60.0).round() as i64;
                model.sessions[index].duration = Some(format!("{}m", minutes));
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

    // End the session 30 minutes later
    end_session(session_id, "2025-05-01T12:30:00Z".to_string(), &mut model);

    // Verify session exists and duration is set
    assert_eq!(model.sessions.len(), 1);
    assert_eq!(model.sessions[0].duration, Some("30m".to_string())); // 30 minutes = 30 minutes
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
