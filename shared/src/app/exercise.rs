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
