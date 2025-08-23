use crate::app::model::Model;
use crate::app::repository::Repository;

use crate::app::study_session::StudySession;
use crate::HttpResult;
use crux_core::Command;
use facet::Facet;
use serde::{Deserialize, Serialize};

#[derive(Facet, Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct Study {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
}

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum StudyEvent {
    // Background sync events (internal only)
    #[serde(skip)]
    #[facet(skip)]
    SyncStudies,
    #[serde(skip)]
    #[facet(skip)]
    StudiesSynced(HttpResult<crux_http::Response<Vec<Study>>, crux_http::HttpError>),
    #[serde(skip)]
    #[facet(skip)]
    StudySynced(HttpResult<crux_http::Response<Study>, crux_http::HttpError>),

    // Optimistic user actions (all immediate, sync in background)
    CreateStudy(Study),
    UpdateStudy(Study),
    RemoveStudy(String),
}

impl Study {
    pub fn new(name: String, description: Option<String>) -> Self {
        Self {
            id: crate::app::generate_id(),
            name,
            description,
        }
    }

    pub fn get_study_sessions<'a>(&self, model: &'a Model) -> Vec<&'a StudySession> {
        model
            .sessions
            .iter()
            .flat_map(|s| &s.study_sessions)
            .filter(|session| session.study_id == self.id)
            .collect()
    }
}

// Note: add_study and edit_study removed - use model.studies().add() and model.studies().update() directly

pub fn handle_event(event: StudyEvent, model: &mut Model) -> Command<super::Effect, super::Event> {
    match event {
        // Background sync events (internal only)
        StudyEvent::SyncStudies => {
            let api = crate::app::ApiConfig::default();
            return api.get("/api/studies", |response| {
                super::Event::Study(StudyEvent::StudiesSynced(response))
            });
        }
        StudyEvent::StudiesSynced(HttpResult::Ok(mut response)) => {
            let server_studies = response.take_body().unwrap();
            // Merge server studies with local studies, preserving local changes
            merge_studies_from_server(server_studies, model);
        }
        StudyEvent::StudiesSynced(HttpResult::Err(_e)) => {
            // Silently fail background sync - user doesn't need to know
        }
        StudyEvent::StudySynced(HttpResult::Ok(_response)) => {
            // Individual study synced successfully - nothing to do
        }
        StudyEvent::StudySynced(HttpResult::Err(_e)) => {
            // Individual study sync failed - could retry or show status
        }

        // Optimistic user actions (all immediate, sync in background)
        StudyEvent::CreateStudy(study) => {
            // Apply immediately to local model
            model.studies().add(study.clone());

            // Trigger background sync
            let create_request = serde_json::json!({
                "name": study.name,
                "description": study.description
            });
            let api = crate::app::ApiConfig::default();
            return api.post("/api/studies", &create_request, |response| {
                super::Event::Study(StudyEvent::StudySynced(response))
            });
        }
        StudyEvent::UpdateStudy(study) => {
            // Apply immediately to local model
            model.studies().update(study.clone());

            // Trigger background sync
            let update_request = serde_json::json!({
                "name": study.name,
                "description": study.description
            });
            let api = crate::app::ApiConfig::default();
            return api.put(
                &format!("/api/studies/{}", study.id),
                &update_request,
                |response| super::Event::Study(StudyEvent::StudySynced(response)),
            );
        }
        StudyEvent::RemoveStudy(study_id) => {
            // Apply immediately to local model
            model.studies.retain(|s| s.id != study_id);

            // Trigger background sync
            let api = crate::app::ApiConfig::default();
            return api.delete(&format!("/api/studies/{study_id}"), |response| {
                super::Event::Study(StudyEvent::StudySynced(response))
            });
        }
    }

    crux_core::render::render()
}

// Helper function to merge server studies with local studies
fn merge_studies_from_server(server_studies: Vec<Study>, model: &mut Model) {
    // Simple merge strategy: server studies override local ones with same ID
    let server_study_ids: std::collections::HashSet<String> =
        server_studies.iter().map(|s| s.id.clone()).collect();

    // Keep local studies that don't exist on server (likely new/pending sync)
    model
        .studies
        .retain(|local_study| !server_study_ids.contains(&local_study.id));

    // Add/update with server studies
    for server_study in server_studies {
        if let Some(existing_pos) = model.studies.iter().position(|s| s.id == server_study.id) {
            model.studies[existing_pos] = server_study;
        } else {
            model.studies.push(server_study);
        }
    }
}

// *************
// TESTS
// *************

#[test]
fn test_add_study() {
    let mut model = Model::default();
    let study = Study::new("Study 1".to_string(), None);
    model.studies().add(study);
    assert_eq!(model.studies.len(), 1);
}

#[test]
fn test_edit_study() {
    let mut model = Model::default();
    let study = Study::new("Study 1".to_string(), None);
    model.studies().add(study.clone());

    let mut edited_study = study;
    edited_study.name = "Study 2".to_string();
    model.studies().update(edited_study);

    assert_eq!(model.studies.len(), 1);
    assert_eq!(model.studies[0].name, "Study 2");
}

#[test]
fn test_study_sessions() {
    let mut model = Model::default();

    // Create a study
    let study = Study::new("Test Study".to_string(), None);
    let study_id = study.id.clone();
    model.studies().add(study.clone());

    // Create a session
    let session = crate::app::session::PracticeSession::new(
        vec!["Goal 1".to_string()],
        "Test Session".to_string(),
    );
    let session_id = session.id.clone();
    model.sessions().add(session);

    // Add study sessions
    let session1 =
        crate::app::study_session::StudySession::new(study_id.clone(), session_id.clone());
    let session2 =
        crate::app::study_session::StudySession::new(study_id.clone(), session_id.clone());
    if let Some(practice_session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == session1.session_id)
    {
        practice_session.push_study_session(session1);
    }
    if let Some(practice_session) = model
        .sessions
        .iter_mut()
        .find(|s| s.id == session2.session_id)
    {
        practice_session.push_study_session(session2);
    }

    // Test get_study_sessions
    let sessions = study.get_study_sessions(&model);
    assert_eq!(sessions.len(), 2);
}
