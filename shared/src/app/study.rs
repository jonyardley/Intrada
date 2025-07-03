use crate::app::model::Model;
use crate::app::study_session::StudySession;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct Study {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
}

impl Study {
    pub fn new(name: String, description: Option<String>) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            description,
        }
    }

    pub fn get_session_records<'a>(&self, model: &'a Model) -> Vec<&'a StudySession> {
        model
            .sessions
            .iter()
            .flat_map(|session| session.study_sessions())
            .filter(|record| record.study_id == self.id)
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
fn test_study_records() {
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

    // Test get_session_records
    let records = study.get_session_records(&model);
    assert_eq!(records.len(), 2);
}
