use crate::app::{Exercise, ExerciseRecord, PracticeGoal, PracticeSession};
use serde::{Deserialize, Serialize};

#[derive(Default)]
pub struct Model {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
    pub sessions: Vec<PracticeSession>,
}

impl Model {}

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

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct ViewModel {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
    pub sessions: Vec<PracticeSession>,
}

// *************
// TESTS
// *************

#[test]
fn test_get_exercise_records() {
    let mut model = Model::default();

    // Create an exercise
    let exercise = Exercise::new("Test Exercise".to_string(), None);
    let exercise_id = exercise.id.clone();
    model.exercises.push(exercise);

    // Create a session
    let session = PracticeSession::new(vec!["Goal 1".to_string()], "Test Session".to_string());
    let session_id = session.id.clone();
    model.sessions.push(session);

    // Add exercise records
    let record1 = ExerciseRecord::new(exercise_id.clone(), session_id.clone());
    let record2 = ExerciseRecord::new(exercise_id.clone(), session_id.clone());
    model.sessions[0].exercise_records.push(record1);
    model.sessions[0].exercise_records.push(record2);

    // Test get_exercise_records
    let records = get_exercise_records(&model, &exercise_id);
    assert_eq!(records.len(), 2);

    // Test get_exercise_records_for_session

    let session_records = get_exercise_records_for_session(&model, &session_id);
    assert_eq!(session_records.len(), 2);
}
