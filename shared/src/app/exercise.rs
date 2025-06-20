use crate::app::exercise_record::ExerciseRecord;
use crate::app::model::Model;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct Exercise {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
}

impl Exercise {
    pub fn new(name: String, description: Option<String>) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            description,
        }
    }

    pub fn get_session_records<'a>(&self, model: &'a Model) -> Vec<&'a ExerciseRecord> {
        model
            .sessions
            .iter()
            .flat_map(|session| &session.exercise_records)
            .filter(|record| record.exercise_id == self.id)
            .collect()
    }
}

pub fn add_exercise(exercise: Exercise, model: &mut Model) {
    model.exercises.push(exercise);
}

pub fn edit_exercise(exercise: Exercise, model: &mut Model) {
    let index = model.exercises.iter().position(|e| e.id == exercise.id);
    if let Some(index) = index {
        model.exercises[index] = exercise;
    }
}

// *************
// TESTS
// *************

#[test]
fn test_add_exercise() {
    let mut model = Model::default();
    let exercise = Exercise::new("Exercise 1".to_string(), None);
    add_exercise(exercise, &mut model);
    assert_eq!(model.exercises.len(), 1);
}

#[test]
fn test_edit_exercise() {
    let mut model = Model::default();
    let exercise = Exercise::new("Exercise 1".to_string(), None);
    add_exercise(exercise.clone(), &mut model);

    let mut edited_exercise = exercise;
    edited_exercise.name = "Exercise 2".to_string();
    edit_exercise(edited_exercise, &mut model);

    assert_eq!(model.exercises.len(), 1);
    assert_eq!(model.exercises[0].name, "Exercise 2");
}

#[test]
fn test_exercise_records() {
    let mut model = Model::default();

    // Create an exercise
    let exercise = Exercise::new("Test Exercise".to_string(), None);
    let exercise_id = exercise.id.clone();
    add_exercise(exercise.clone(), &mut model);

    // Create a session
    let session = crate::app::session::PracticeSession::new(
        vec!["Goal 1".to_string()],
        "Test Session".to_string(),
    );
    let session_id = session.id.clone();
    crate::app::session::add_session(session, &mut model);

    // Add exercise records
    let record1 =
        crate::app::exercise_record::ExerciseRecord::new(exercise_id.clone(), session_id.clone());
    let record2 =
        crate::app::exercise_record::ExerciseRecord::new(exercise_id.clone(), session_id.clone());
    crate::app::exercise_record::add_exercise_record(record1, &mut model);
    crate::app::exercise_record::add_exercise_record(record2, &mut model);

    // Test get_session_records
    let records = exercise.get_session_records(&model);
    assert_eq!(records.len(), 2);
}
