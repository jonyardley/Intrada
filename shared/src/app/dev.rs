use crate::app::{
    add_exercise, add_goal, add_session, end_session, start_session, Exercise, Model, PracticeGoal,
    PracticeSession,
};

pub fn set_dev_data(model: &mut Model) {
    //Exercises
    add_exercise(
        Exercise::new(
            "Scales over 2 octaves".to_string(),
            Some("In all keys".to_string()),
        ),
        model,
    );
    add_exercise(
        Exercise::new(
            "Arpeggios over 2 octaves".to_string(),
            Some("In all keys".to_string()),
        ),
        model,
    );
    add_exercise(
        Exercise::new(
            "Octaves over 2 octaves".to_string(),
            Some("In all keys".to_string()),
        ),
        model,
    );
    add_exercise(
        Exercise::new(
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
            model
                .exercises
                .iter()
                .take(1)
                .map(|e| e.id.clone())
                .collect(),
            None,
        ),
        model,
    );
    add_goal(
        PracticeGoal::new(
            "Perfect Etudes".to_string(),
            Some("Op. 23. No. 1 & 101".to_string()),
            Some("2025-05-01".to_string()),
            model
                .exercises
                .iter()
                .take(2)
                .map(|e| e.id.clone())
                .collect(),
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
                .exercises
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
    let session = PracticeSession::new(
        model.goals.iter().take(1).map(|g| g.id.clone()).collect(),
        "Do good practice!".to_string(),
    );
    let session_id = session.id.clone();
    add_session(session, model);

    let session_to_update = PracticeSession {
        id: session_id.clone(),
        goal_ids: vec![],
        intention: "".to_string(),
        start_time: None,
        end_time: None,
        notes: None,
    };

    start_session(
        session_to_update.clone(),
        "2025-05-01 12:00:00".to_string(),
        model,
    );
    end_session(session_to_update, "2025-05-01 12:30:00".to_string(), model);
}
