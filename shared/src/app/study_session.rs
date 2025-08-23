use crate::app::model::Model;
use crux_core::Command;
use facet::Facet;
use serde::{Deserialize, Serialize};

#[cfg(test)]
use crate::app::repository::Repository;
#[cfg(test)]
use crate::app::session::PracticeSession;

#[derive(Facet, Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct StudySession {
    pub id: String,
    pub study_id: String,
    pub session_id: String,
    pub score: Option<u32>, // out of 10
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum StudySessionEvent {
    AddStudySession(StudySession),
    UpdateStudySession(StudySession),
}

impl StudySession {
    pub fn new(study_id: String, session_id: String) -> Self {
        Self {
            id: crate::app::generate_id(),
            study_id,
            session_id,
            score: None,
        }
    }
}

// Note: add_study_session and update_study_session removed - use direct repository access and method calls

pub fn get_study_sessions<'a>(model: &'a Model, study_id: &str) -> Vec<&'a StudySession> {
    model
        .sessions
        .iter()
        .flat_map(|session| session.study_sessions.iter())
        .filter(|session| session.study_id == study_id)
        .collect()
}

pub fn get_study_sessions_for_session<'a>(
    model: &'a Model,
    session_id: &str,
) -> Vec<&'a StudySession> {
    model
        .sessions
        .iter()
        .find(|session| session.id == session_id)
        .map(|session| session.study_sessions.iter().collect())
        .unwrap_or_else(Vec::new)
}

pub fn handle_event(
    event: StudySessionEvent,
    model: &mut Model,
) -> Command<super::Effect, super::Event> {
    match event {
        StudySessionEvent::AddStudySession(session) => {
            if let Some(practice_session) = model
                .sessions
                .iter_mut()
                .find(|s| s.id == session.session_id)
            {
                practice_session.push_study_session(session);
            }
        }
        StudySessionEvent::UpdateStudySession(session) => {
            if let Some(practice_session) = model
                .sessions
                .iter_mut()
                .find(|s| s.id == session.session_id)
            {
                practice_session.update_study_session(session);
            }
        }
    }

    crux_core::render::render()
}

// *************
// TESTS
// *************

#[test]
fn test_add_study_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    let session_id = session.id.clone();
    model.sessions().add(session);

    let study_session = StudySession::new("Study 1".to_string(), session_id);
    if let Some(practice_session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == study_session.session_id)
    {
        practice_session.push_study_session(study_session);
    }

    let session = model.sessions.first().unwrap();
    assert_eq!(session.study_sessions.len(), 1);
}

#[test]
fn test_update_study_session() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    let session_id = session.id.clone();
    model.sessions().add(session);

    let study_session = StudySession::new("Study 1".to_string(), session_id.clone());
    let session_id_copy = study_session.id.clone();
    if let Some(practice_session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == study_session.session_id)
    {
        practice_session.push_study_session(study_session);
    }

    let mut updated_session = StudySession::new("Study 1".to_string(), session_id);
    updated_session.id = session_id_copy;
    updated_session.score = Some(8);
    if let Some(practice_session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == updated_session.session_id)
    {
        practice_session.update_study_session(updated_session);
    }

    let session = model.sessions.first().unwrap();
    let study_session = session.study_sessions.first().unwrap();
    assert_eq!(study_session.score, Some(8));
}
