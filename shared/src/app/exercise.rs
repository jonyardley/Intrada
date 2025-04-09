use crate::app::model::Model;
use serde::{Deserialize, Serialize};

// *************
// EXERCISES
// *************
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
