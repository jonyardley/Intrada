use crate::app::{add_exercise, add_goal, Exercise, Model, PracticeGoal};

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

    //Goals
    add_goal(
        PracticeGoal::new(
            "Master Nocturnes".to_string(),
            Some("Op. 23 & 23".to_string()),
            Some("2025-05-01".to_string()),
            vec![],
            None,
        ),
        model,
    );
    add_goal(
        PracticeGoal::new(
            "Perfect Etudes".to_string(),
            Some("Op. 23. No. 1 & 101".to_string()),
            Some("2025-05-01".to_string()),
            vec![],
            None,
        ),
        model,
    );
    add_goal(
        PracticeGoal::new(
            "More Etudes".to_string(),
            Some("Op. 25. No. 1".to_string()),
            Some("2025-05-01".to_string()),
            vec![],
            None,
        ),
        model,
    );
}
