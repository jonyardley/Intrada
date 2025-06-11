use serde::{Deserialize, Serialize};
use crate::app::{model::Model, session::{add_session, PracticeSession}};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct ExerciseRecord {
    pub id: String,
    pub exercise_id: String,
    pub session_id: String,
    pub score: Option<u32>, // out of 10
}

impl ExerciseRecord {
    pub fn new(exercise_id: String, session_id: String) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            exercise_id,
            session_id,
            score: None,
        }
    }
}

pub fn add_exercise_record(record: ExerciseRecord, model: &mut Model) {
    if let Some(session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == record.session_id)
    {
        session.exercise_records.push(record);
    }
}

pub fn update_exercise_record(record: ExerciseRecord, model: &mut Model) {
    if let Some(session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == record.session_id)
    {
        if let Some(index) = session
            .exercise_records
            .iter()
            .position(|r| r.id == record.id)
        {
            session.exercise_records[index] = record;
        }
    }
}

pub fn get_exercise_records<'a>(model: &'a Model, exercise_id: &str) -> Vec<&'a ExerciseRecord> {
    model
        .sessions
        .iter()
        .flat_map(|session| session.exercise_records.iter())
        .filter(|record| record.exercise_id == exercise_id)
        .collect()
}

pub fn get_exercise_records_for_session<'a>(
    model: &'a Model,
    session_id: &str,
) -> Vec<&'a ExerciseRecord> {
    model
        .sessions
        .iter()
        .find(|session| session.id == session_id)
        .map(|session| session.exercise_records.iter().collect())
        .unwrap_or_default()
}

// *************
// TESTS
// *************

#[test]
fn test_add_exercise_record() {
    let mut model = Model::default();
    let session = PracticeSession::new(
        vec!["Goal 1".to_string()],
        "Intention 1".to_string(),
    );
    let session_id = session.id.clone();
    add_session(session, &mut model);

    let record = ExerciseRecord::new("Exercise 1".to_string(), session_id);
    add_exercise_record(record, &mut model);

    let session = model.sessions.first().unwrap();
    assert_eq!(session.exercise_records.len(), 1);
}

#[test]
fn test_update_exercise_record() {
    let mut model = Model::default();
    let session = PracticeSession::new(
        vec!["Goal 1".to_string()],
        "Intention 1".to_string(),
    );
    let session_id = session.id.clone();
    add_session(session, &mut model);

    let record = ExerciseRecord::new("Exercise 1".to_string(), session_id.clone());
    let record_id = record.id.clone();
    add_exercise_record(record, &mut model);

    let mut updated_record = ExerciseRecord::new("Exercise 1".to_string(), session_id);
    updated_record.id = record_id;
    updated_record.score = Some(8);
    update_exercise_record(updated_record, &mut model);

    let session = model.sessions.first().unwrap();
    let record = session.exercise_records.first().unwrap();
    assert_eq!(record.score, Some(8));
}
