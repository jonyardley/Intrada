use crate::app::model::Model;
use crate::app::repository::Repository;
use crate::HttpResult;
use crux_core::Command;
use facet::Facet;
use serde::{Deserialize, Serialize};

#[derive(Facet, Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
#[repr(C)]
pub enum GoalStatus {
    #[default]
    NotStarted,
    InProgress,
    Completed,
}

#[derive(Facet, Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct PracticeGoal {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub status: GoalStatus,
    pub start_date: Option<String>,
    pub target_date: Option<String>,
    pub study_ids: Vec<String>,
    pub tempo_target: Option<u32>,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum GoalEvent {
    FetchGoals,
    #[serde(skip)]
    #[facet(skip)]
    SetGoals(HttpResult<crux_http::Response<Vec<PracticeGoal>>, crux_http::HttpError>),
    UpdateGoals(Vec<PracticeGoal>),
    AddGoal(PracticeGoal),
    #[serde(skip)]
    #[facet(skip)]
    GoalCreated(HttpResult<crux_http::Response<PracticeGoal>, crux_http::HttpError>),
    EditGoal(PracticeGoal),
}

impl PracticeGoal {
    pub fn new(
        name: String,
        description: Option<String>,
        target_date: Option<String>,
        study_ids: Vec<String>,
        tempo_target: Option<u32>,
    ) -> Self {
        Self {
            id: crate::app::generate_id(),
            name,
            description,
            status: GoalStatus::NotStarted,
            start_date: None,
            target_date,
            study_ids,
            tempo_target,
        }
    }
}

pub fn add_goal(goal: PracticeGoal, model: &mut Model) {
    let mut repo = model.goals();
    repo.add(goal);
}

pub fn edit_goal(updated_goal: PracticeGoal, model: &mut Model) {
    let mut repo = model.goals();
    repo.update(updated_goal);
}

pub fn add_study_to_goal(goal_id: &str, study_id: &str, model: &mut Model) {
    let mut repo = model.goals();
    if let Some(goal) = repo.find_mut_by_id(goal_id) {
        if !goal.study_ids.contains(&study_id.to_string()) {
            goal.study_ids.push(study_id.to_string());
        }
    }
}

pub fn handle_event(event: GoalEvent, model: &mut Model) -> Command<super::Effect, super::Event> {
    match event {
        GoalEvent::FetchGoals => {
            let api = crate::app::ApiConfig::default();
            return api.get("/goals", |response| {
                super::Event::Goal(GoalEvent::SetGoals(response))
            });
        }
        GoalEvent::SetGoals(HttpResult::Ok(mut response)) => {
            let goals = response.take_body().unwrap();
            return Command::event(super::Event::Goal(GoalEvent::UpdateGoals(goals)));
        }
        GoalEvent::SetGoals(HttpResult::Err(e)) => {
            let _ = crate::app::handle_http_error(e, "fetch goals");
        }
        GoalEvent::UpdateGoals(goals) => model.goals = goals,
        GoalEvent::AddGoal(goal) => {
            // Transform PracticeGoal to the format the server expects
            let create_request = serde_json::json!({
                "name": goal.name,
                "description": goal.description,
                "target_date": goal.target_date,
                "study_ids": goal.study_ids,
                "tempo_target": goal.tempo_target
            });

            let api = crate::app::ApiConfig::default();
            return api.post("/goals", &create_request, |response| {
                super::Event::Goal(GoalEvent::GoalCreated(response))
            });
        }
        GoalEvent::GoalCreated(HttpResult::Ok(mut response)) => {
            let created_goal = response.take_body().unwrap();
            add_goal(created_goal, model);
        }
        GoalEvent::GoalCreated(HttpResult::Err(e)) => {
            let _ = crate::app::handle_http_error(e, "create goal");
        }
        GoalEvent::EditGoal(goal) => edit_goal(goal, model),
    }

    crux_core::render::render()
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
        vec!["Study 1".to_string()],
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
        vec!["Study 1".to_string()],
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
        study_ids: vec!["Study 2".to_string()],
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
    assert_eq!(edited_goal.study_ids, vec!["Study 2".to_string()]);
}

#[test]
fn test_add_study_to_goal() {
    let mut model = Model::default();
    let goal = PracticeGoal::new(
        "Goal 1".to_string(),
        None,
        None,
        vec!["Study 1".to_string()],
        None,
    );
    let goal_id = goal.id.clone();
    add_goal(goal, &mut model);
    add_study_to_goal(&goal_id, "Study 1", &mut model);
}
