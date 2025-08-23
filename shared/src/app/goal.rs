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
    // Background sync events (internal only)
    #[serde(skip)]
    #[facet(skip)]
    SyncGoals,
    #[serde(skip)]
    #[facet(skip)]
    GoalsSynced(HttpResult<crux_http::Response<Vec<PracticeGoal>>, crux_http::HttpError>),
    #[serde(skip)]
    #[facet(skip)]
    GoalSynced(HttpResult<crux_http::Response<PracticeGoal>, crux_http::HttpError>),

    // Optimistic user actions (all immediate, sync in background)
    CreateGoal(PracticeGoal),
    UpdateGoal(PracticeGoal),
    RemoveGoal(String),
    AddStudyToGoal {
        goal_id: String,
        study_id: String,
    },
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

// Note: add_goal and edit_goal removed - use model.goals().add() and model.goals().update() directly

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
        // Background sync events (internal only)
        GoalEvent::SyncGoals => {
            let api = crate::app::ApiConfig::default();
            return api.get("/api/goals", |response| {
                super::Event::Goal(GoalEvent::GoalsSynced(response))
            });
        }
        GoalEvent::GoalsSynced(HttpResult::Ok(mut response)) => {
            let server_goals = response.take_body().unwrap();
            // Merge server goals with local goals, preserving local changes
            merge_goals_from_server(server_goals, model);
        }
        GoalEvent::GoalsSynced(HttpResult::Err(_e)) => {
            // Silently fail background sync - user doesn't need to know
        }
        GoalEvent::GoalSynced(HttpResult::Ok(_response)) => {
            // Individual goal synced successfully - nothing to do
        }
        GoalEvent::GoalSynced(HttpResult::Err(_e)) => {
            // Individual goal sync failed - could retry or show status
        }

        // Optimistic user actions (all immediate, sync in background)
        GoalEvent::CreateGoal(goal) => {
            // Apply immediately to local model
            model.goals().add(goal.clone());

            // Trigger background sync
            let create_request = serde_json::json!({
                "name": goal.name,
                "description": goal.description,
                "target_date": goal.target_date,
                "study_ids": goal.study_ids,
                "tempo_target": goal.tempo_target
            });
            let api = crate::app::ApiConfig::default();
            return api.post("/api/goals", &create_request, |response| {
                super::Event::Goal(GoalEvent::GoalSynced(response))
            });
        }
        GoalEvent::UpdateGoal(goal) => {
            // Apply immediately to local model
            model.goals().update(goal.clone());

            // Trigger background sync
            let api = crate::app::ApiConfig::default();
            return api.put(&format!("/api/goals/{}", goal.id), &goal, |response| {
                super::Event::Goal(GoalEvent::GoalSynced(response))
            });
        }
        GoalEvent::RemoveGoal(goal_id) => {
            // Apply immediately to local model
            model.goals.retain(|g| g.id != goal_id);

            // Trigger background sync
            let api = crate::app::ApiConfig::default();
            return api.delete(&format!("/api/goals/{goal_id}"), |response| {
                super::Event::Goal(GoalEvent::GoalSynced(response))
            });
        }
        GoalEvent::AddStudyToGoal { goal_id, study_id } => {
            // Apply immediately to local model
            add_study_to_goal(&goal_id, &study_id, model);

            // Trigger background sync
            if let Some(goal) = model.goals.iter().find(|g| g.id == goal_id) {
                let api = crate::app::ApiConfig::default();
                return api.put(&format!("/api/goals/{}", goal.id), goal, |response| {
                    super::Event::Goal(GoalEvent::GoalSynced(response))
                });
            }
        }
    }

    crux_core::render::render()
}

// Helper function to merge server goals with local goals
fn merge_goals_from_server(server_goals: Vec<PracticeGoal>, model: &mut Model) {
    // Simple merge strategy: server goals override local ones with same ID
    let server_goal_ids: std::collections::HashSet<String> =
        server_goals.iter().map(|g| g.id.clone()).collect();

    // Keep local goals that don't exist on server (likely new/pending sync)
    model
        .goals
        .retain(|local_goal| !server_goal_ids.contains(&local_goal.id));

    // Add/update with server goals
    for server_goal in server_goals {
        if let Some(existing_pos) = model.goals.iter().position(|g| g.id == server_goal.id) {
            model.goals[existing_pos] = server_goal;
        } else {
            model.goals.push(server_goal);
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
        vec!["Study 1".to_string()],
        None,
    );
    model.goals().add(goal);
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
    model.goals().add(goal);

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

    model.goals().update(updated_goal);

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
    model.goals().add(goal);
    add_study_to_goal(&goal_id, "Study 1", &mut model);
}
