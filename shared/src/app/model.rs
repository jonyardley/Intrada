use crate::app::{ActiveSession, Exercise, PracticeGoal, PracticeSession};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct AppState {
    pub active_session: Option<ActiveSession>,
}

#[derive(Default)]
pub struct Model {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
    pub sessions: Vec<PracticeSession>,
    pub app_state: AppState,
}

impl Model {}

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct ViewModel {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
    pub sessions: Vec<PracticeSession>,
    pub app_state: AppState,
}