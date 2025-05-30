use crate::app::model::Model;
use serde::{Deserialize, Serialize};

// *************
// GOALS
// *************
#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub enum GoalStatus {
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
    pub status: GoalStatus,
    pub start_date: Option<String>,
    pub target_date: Option<String>,
    pub exercise_ids: Vec<String>,
    pub tempo_target: Option<u32>, // This might want to be abstracted and maybe a range?
}

impl PracticeGoal {
    pub fn new(
        name: String,
        description: Option<String>,
        target_date: Option<String>,
        exercise_ids: Vec<String>,
        tempo_target: Option<u32>,
    ) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            description,
            status: GoalStatus::NotStarted,
            start_date: None,
            target_date: target_date,
            exercise_ids,
            tempo_target,
        }
    }
}

pub fn add_goal(goal: PracticeGoal, model: &mut Model) {
    model.goals.push(goal);
}

pub fn edit_goal(updated_goal: PracticeGoal, model: &mut Model) {
    if let Some(goal) = model.goals.iter_mut().find(|g| g.id == updated_goal.id) {
        *goal = updated_goal;
    }
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
    let goal = PracticeGoal::new(
        "Goal 1".to_string(),
        None,
        None,
        vec!["Exercise 1".to_string()],
        None,
    );
    add_goal(goal, &mut model);
    assert_eq!(model.goals.len(), 1);
}

#[test]
fn test_edit_goal() {
    let mut model = Model::default();
    let goal = PracticeGoal::new(
        "Goal 1".to_string(),
        None,
        None,
        vec!["Exercise 1".to_string()],
        None,
    );
    let goal_id = goal.id.clone();
    add_goal(goal, &mut model);

    let updated_goal = PracticeGoal {
        id: goal_id.clone(),
        name: "Updated Goal".to_string(),
        description: Some("Updated description".to_string()),
        status: GoalStatus::InProgress,
        start_date: Some("2024-03-20".to_string()),
        target_date: Some("2024-04-20".to_string()),
        exercise_ids: vec!["Exercise 2".to_string()],
        tempo_target: Some(120),
    };

    edit_goal(updated_goal, &mut model);

    let edited_goal = model.goals.iter().find(|g| g.id == goal_id).unwrap();
    assert_eq!(edited_goal.name, "Updated Goal");
    assert_eq!(
        edited_goal.description,
        Some("Updated description".to_string())
    );
    assert_eq!(edited_goal.status, GoalStatus::InProgress);
    assert_eq!(edited_goal.exercise_ids, vec!["Exercise 2".to_string()]);
}

#[test]
fn test_add_exercise_to_goal() {
    let mut model = Model::default();
    let goal = PracticeGoal::new(
        "Goal 1".to_string(),
        None,
        None,
        vec!["Exercise 1".to_string()],
        None,
    );
    let goal_id = goal.id.clone();
    add_goal(goal, &mut model);
    add_exercise_to_goal(goal_id, "Exercise 1".to_string(), &mut model);
}
