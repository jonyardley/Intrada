use crate::app::model::Model;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct PracticeSession {
    pub id: String,
    pub goal_ids: Vec<String>,
    pub intention: String,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub notes: Option<String>,
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

pub fn start_session(session: PracticeSession, timestamp: String, model: &mut Model) {
    let index = model.sessions.iter().position(|s| s.id == session.id);
    if let Some(index) = index {
        model.sessions[index].start_time = Some(timestamp);
    }
}

pub fn end_session(session: PracticeSession, timestamp: String, model: &mut Model) {
    let index = model.sessions.iter().position(|s| s.id == session.id);
    if let Some(index) = index {
        model.sessions[index].end_time = Some(timestamp);
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
    add_session(session, &mut model);
    assert_eq!(model.sessions.len(), 1);
}
