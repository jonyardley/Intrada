use serde::{Deserialize, Serialize};

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

pub fn add_exercise_record(record: ExerciseRecord, model: &mut crate::app::model::Model) {
    if let Some(session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == record.session_id)
    {
        session.exercise_records.push(record);
    }
}

pub fn update_exercise_record(record: ExerciseRecord, model: &mut crate::app::model::Model) {
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

// *************
// TESTS
// *************

#[test]
fn test_add_exercise_record() {
    let mut model = crate::app::model::Model::default();
    let session = crate::app::session::PracticeSession::new(
        vec!["Goal 1".to_string()],
        "Intention 1".to_string(),
    );
    let session_id = session.id.clone();
    crate::app::session::add_session(session, &mut model);

    let record = ExerciseRecord::new("Exercise 1".to_string(), session_id);
    add_exercise_record(record, &mut model);

    let session = model.sessions.first().unwrap();
    assert_eq!(session.exercise_records.len(), 1);
}

#[test]
fn test_update_exercise_record() {
    let mut model = crate::app::model::Model::default();
    let session = crate::app::session::PracticeSession::new(
        vec!["Goal 1".to_string()],
        "Intention 1".to_string(),
    );
    let session_id = session.id.clone();
    crate::app::session::add_session(session, &mut model);

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
