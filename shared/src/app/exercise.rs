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
