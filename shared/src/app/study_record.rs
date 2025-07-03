use crate::app::model::Model;
use serde::{Deserialize, Serialize};

#[cfg(test)]
use crate::app::session::{add_session, PracticeSession};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct StudyRecord {
    pub id: String,
    pub study_id: String,
    pub session_id: String,
    pub score: Option<u32>, // out of 10
}

impl StudyRecord {
    pub fn new(study_id: String, session_id: String) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            study_id,
            session_id,
            score: None,
        }
    }
}

pub fn add_study_record(record: StudyRecord, model: &mut Model) {
    if let Some(session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id() == record.session_id)
    {
        session.push_study_record(record);
    }
}

pub fn update_study_record(record: StudyRecord, model: &mut Model) {
    if let Some(session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id() == record.session_id)
    {
        session.update_study_record(record);
    }
}

pub fn get_study_records<'a>(model: &'a Model, study_id: &str) -> Vec<&'a StudyRecord> {
    model
        .sessions
        .iter()
        .flat_map(|session| session.study_records().iter())
        .filter(|record| record.study_id == study_id)
        .collect()
}

pub fn get_study_records_for_session<'a>(
    model: &'a Model,
    session_id: &str,
) -> Vec<&'a StudyRecord> {
    model
        .sessions
        .iter()
        .find(|session| session.id() == session_id)
        .map(|session| session.study_records().iter().collect())
        .unwrap_or_default()
}

// *************
// TESTS
// *************

#[test]
fn test_add_study_record() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    let session_id = session.id().to_string();
    add_session(session, &mut model);

    let record = StudyRecord::new("Study 1".to_string(), session_id);
    add_study_record(record, &mut model);

    let session = model.sessions.first().unwrap();
    assert_eq!(session.study_records().len(), 1);
}

#[test]
fn test_update_study_record() {
    let mut model = Model::default();
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string());
    let session_id = session.id().to_string();
    add_session(session, &mut model);

    let record = StudyRecord::new("Study 1".to_string(), session_id.clone());
    let record_id = record.id.clone();
    add_study_record(record, &mut model);

    let mut updated_record = StudyRecord::new("Study 1".to_string(), session_id);
    updated_record.id = record_id;
    updated_record.score = Some(8);
    update_study_record(updated_record, &mut model);

    let session = model.sessions.first().unwrap();
    let record = session.study_records().first().unwrap();
    assert_eq!(record.score, Some(8));
}
