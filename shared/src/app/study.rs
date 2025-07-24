use crate::app::model::Model;
use crate::app::study_session::StudySession;
use crate::HttpResult;
use crux_core::Command;
use crux_http::command::Http;
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
    FetchStudies,
    #[serde(skip)]
    #[facet(skip)]
    SetStudies(HttpResult<crux_http::Response<Vec<Study>>, crux_http::HttpError>),
    UpdateStudies(Vec<Study>),
    AddStudy(Study),
    #[serde(skip)]
    #[facet(skip)]
    StudyCreated(HttpResult<crux_http::Response<Study>, crux_http::HttpError>),
    EditStudy(Study),
    AddStudyToGoal {
        goal_id: String,
        study_id: String,
    },
}

impl Study {
    pub fn new(name: String, description: Option<String>) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            description,
        }
    }

    pub fn get_study_sessions<'a>(&self, model: &'a Model) -> Vec<&'a StudySession> {
        model
            .sessions
            .iter()
            .flat_map(super::session::PracticeSession::study_sessions)
            .filter(|session| session.study_id == self.id)
            .collect()
    }
}

pub fn add_study(study: Study, model: &mut Model) {
    model.studies.push(study);
}

pub fn edit_study(study: Study, model: &mut Model) {
    let index = model.studies.iter().position(|e| e.id == study.id);
    if let Some(index) = index {
        model.studies[index] = study;
    }
}

pub fn handle_event(event: StudyEvent, model: &mut Model) -> Command<super::Effect, super::Event> {
    match event {
        StudyEvent::FetchStudies => {
            return Http::get("http://localhost:3000/studies")
                .expect_json()
                .build()
                .map(Into::into)
                .then_send(|response| super::Event::Study(StudyEvent::SetStudies(response)));
        }
        StudyEvent::SetStudies(HttpResult::Ok(mut response)) => {
            let studies = response.take_body().unwrap();
            return Command::event(super::Event::Study(StudyEvent::UpdateStudies(studies)));
        }
        StudyEvent::SetStudies(HttpResult::Err(e)) => {
            eprintln!("Failed to fetch studies: {e:?}");
            // TODO: Add proper error handling - show error to user
        }
        StudyEvent::UpdateStudies(studies) => model.studies = studies,
        StudyEvent::AddStudy(study) => {
            // Transform Study to the format the server expects
            let create_request = serde_json::json!({
                "name": study.name,
                "description": study.description
            });

            let json_string =
                serde_json::to_string(&create_request).expect("Failed to serialize JSON");
            eprintln!("Creating study with JSON: {json_string}");

            return Http::post("http://localhost:3000/studies")
                .header("Content-Type", "application/json")
                .body(json_string)
                .expect_json::<Study>()
                .build()
                .map(Into::into)
                .then_send(|response| super::Event::Study(StudyEvent::StudyCreated(response)));
        }
        StudyEvent::StudyCreated(HttpResult::Ok(mut response)) => {
            let created_study = response.take_body().unwrap();
            add_study(created_study, model);
        }
        StudyEvent::StudyCreated(HttpResult::Err(e)) => {
            eprintln!("Failed to create study: {e:?}");
            // TODO: Add proper error handling - show error to user
        }
        StudyEvent::EditStudy(study) => edit_study(study, model),
        StudyEvent::AddStudyToGoal { goal_id, study_id } => {
            super::goal::add_study_to_goal(&goal_id, &study_id, model);
        }
    }

    crux_core::render::render()
}

// *************
// TESTS
// *************

#[test]
fn test_add_study() {
    let mut model = Model::default();
    let study = Study::new("Study 1".to_string(), None);
    add_study(study, &mut model);
    assert_eq!(model.studies.len(), 1);
}

#[test]
fn test_edit_study() {
    let mut model = Model::default();
    let study = Study::new("Study 1".to_string(), None);
    add_study(study.clone(), &mut model);

    let mut edited_study = study;
    edited_study.name = "Study 2".to_string();
    edit_study(edited_study, &mut model);

    assert_eq!(model.studies.len(), 1);
    assert_eq!(model.studies[0].name, "Study 2");
}

#[test]
fn test_study_sessions() {
    let mut model = Model::default();

    // Create a study
    let study = Study::new("Test Study".to_string(), None);
    let study_id = study.id.clone();
    add_study(study.clone(), &mut model);

    // Create a session
    let session = crate::app::session::PracticeSession::new(
        vec!["Goal 1".to_string()],
        "Test Session".to_string(),
    );
    let session_id = session.id().to_string();
    crate::app::session::add_session(session, &mut model);

    // Add study sessions
    let session1 =
        crate::app::study_session::StudySession::new(study_id.clone(), session_id.clone());
    let session2 =
        crate::app::study_session::StudySession::new(study_id.clone(), session_id.clone());
    crate::app::study_session::add_study_session(session1, &mut model);
    crate::app::study_session::add_study_session(session2, &mut model);

    // Test get_study_sessions
    let sessions = study.get_study_sessions(&model);
    assert_eq!(sessions.len(), 2);
}
