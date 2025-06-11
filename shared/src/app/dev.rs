use crate::app::{
<<<<<<< HEAD
    add_exercise, add_exercise_record, add_goal, add_session, end_session, start_session, Exercise,
    ExerciseRecord, Model, PracticeGoal, PracticeSession,
=======
    add_exercise, add_goal, add_session, end_session, set_active_session, start_session, Exercise,
    Model, PracticeGoal, PracticeSession,
>>>>>>> a39c263 (Move some session stuff to core and refactor ios)
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
    let session_1 = PracticeSession::new(
        model.goals.iter().take(1).map(|g| g.id.clone()).collect(),
        "Do good practice!".to_string(),
    );
    let session_1_id = session_1.id.clone();
    add_session(session_1, model);

    start_session(
        session_1_id.clone(),
        "2025-05-01T12:00:00Z".to_string(),
        model,
    );
<<<<<<< HEAD

    // Add exercise records
    let exercise_record = ExerciseRecord::new(model.exercises[0].id.clone(), session_id.clone());
    add_exercise_record(exercise_record, model);

    end_session(session_id, "2025-05-01T12:30:00Z".to_string(), model);
=======
    end_session(session_1_id, "2025-05-01T12:30:00Z".to_string(), model);

    let session_2 = PracticeSession::new(
        model.goals.iter().take(1).map(|g| g.id.clone()).collect(),
        "Do good practice!".to_string(),
    );
    let session_2_id = session_2.id.clone();
    add_session(session_2, model);
    set_active_session(session_2_id.clone(), model);
>>>>>>> a39c263 (Move some session stuff to core and refactor ios)
}
