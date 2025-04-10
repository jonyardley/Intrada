use crate::app::model::Model;
use serde::{Deserialize, Serialize};

// *************
// GOALS
// *************
#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub enum Status {
    #[default]
    NotStarted,
    InProgress,
    Completed,
}

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct PracticeGoal {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub status: Status,
    pub start_date: Option<String>,
    pub target_date: Option<String>,
    pub exercise_ids: Vec<String>,
    pub tempo_target: Option<u32>, // This might want to be abstracted and maybe a range?
}

impl PracticeGoal {
    pub fn new(name: String, description: Option<String>, status: Option<Status>) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            description,
            status: status.unwrap_or(Status::NotStarted),
            start_date: None,
            target_date: None,
            exercise_ids: Vec::new(),
            tempo_target: None,
        }
    }
}

pub fn add_goal(goal: PracticeGoal, model: &mut Model) {
    model.goals.push(goal);
}

pub fn add_exercise_to_goal(goal_id: String, exercise_id: String, model: &mut Model) {
    if let Some(goal) = model.goals.iter_mut().find(|g| g.id == goal_id) {
        if !goal.exercise_ids.contains(&exercise_id) {
            goal.exercise_ids.push(exercise_id);
        }
    }
}

// *************
// TESTS
// *************

#[test]
fn test_add_goal() {
    let mut model = Model::default();
    let goal = PracticeGoal::new("Goal 1".to_string(), None, None);
    add_goal(goal, &mut model);
    assert_eq!(model.goals.len(), 1);
}

#[test]
fn test_add_exercise_to_goal() {
    let mut model = Model::default();
    let goal = PracticeGoal::new("Goal 1".to_string(), None, None);
    add_goal(goal, &mut model);
    add_exercise_to_goal("Goal 1".to_string(), "Exercise 1".to_string(), &mut model);
}
