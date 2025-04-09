use crate::app::{Exercise, PracticeGoal};
use serde::{Deserialize, Serialize};

#[derive(Default)]
pub struct Model {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
}

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct ViewModel {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
}
