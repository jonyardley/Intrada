use crate::app::{
    add_goal, add_session, add_study, add_study_session, end_session, start_session, Model,
    PracticeGoal, PracticeSession, Study, StudySession,
};
use crux_core::Command;
use facet::Facet;
use serde::{Deserialize, Serialize};

#[derive(Facet, Serialize, Deserialize, Clone, Debug, PartialEq)]
#[repr(C)]
pub enum DevEvent {
    SetDevData,
    Nothing,
}

pub fn set_dev_data(model: &mut Model) {
    //Studies
    add_study(
        Study::new(
            "Scales over 2 octaves".to_string(),
            Some("In all keys".to_string()),
        ),
        model,
    );
    add_study(
        Study::new(
            "Arpeggios over 2 octaves".to_string(),
            Some("In all keys".to_string()),
        ),
        model,
    );
    add_study(
        Study::new(
            "Octaves over 2 octaves".to_string(),
            Some("In all keys".to_string()),
        ),
        model,
    );
    add_study(
        Study::new(
            "II-V-I progressions".to_string(),
            Some("In all keys".to_string()),
        ),
        model,
    );

    //Goals
    add_goal(
        PracticeGoal::new(
            "Master Nocturnes".to_string(),
            Some("Op. 23 & 23".to_string()),
            Some("2025-05-01".to_string()),
            model.studies.iter().take(1).map(|e| e.id.clone()).collect(),
            None,
        ),
        model,
    );
    add_goal(
        PracticeGoal::new(
            "Perfect Etudes".to_string(),
            Some("Op. 23. No. 1 & 101".to_string()),
            Some("2025-05-01".to_string()),
            model.studies.iter().take(2).map(|e| e.id.clone()).collect(),
            None,
        ),
        model,
    );
    add_goal(
        PracticeGoal::new(
            "More Etudes".to_string(),
            Some("Op. 25. No. 1".to_string()),
            Some("2026-05-01".to_string()),
            model
                .studies
                .iter()
                .rev()
                .take(3)
                .map(|e| e.id.clone())
                .collect(),
            None,
        ),
        model,
    );

    //Sessions
    // Create a completed session
    let session_1 = PracticeSession::new(
        model.goals.iter().take(1).map(|g| g.id.clone()).collect(),
        "Completed practice session".to_string(),
    );
    let session_1_id = session_1.id().to_string();
    add_session(session_1, model);

    let _ = start_session(&session_1_id, "2025-05-01T12:00:00Z".to_string(), model);

    // Add study sessions
    let study_session = StudySession::new(model.studies[0].id.clone(), session_1_id.clone());
    add_study_session(study_session, model);

    let _ = end_session(&session_1_id, "2025-05-01T12:30:00Z".to_string(), model);

    // Create a session that's ready to start (not active yet)
    let ready_session = PracticeSession::new(
        model
            .goals
            .iter()
            .skip(1)
            .take(1)
            .map(|g| g.id.clone())
            .collect(),
        "Ready to practice - etudes session".to_string(),
    );
    add_session(ready_session, model);
}

pub fn handle_event(event: DevEvent, model: &mut Model) -> Command<super::Effect, super::Event> {
    match event {
        DevEvent::SetDevData => set_dev_data(model),
        DevEvent::Nothing => (),
    }

    crux_core::render::render()
}
