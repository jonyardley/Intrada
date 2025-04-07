use crate::app::{Exercise, Model, PracticeGoal, Status};

pub fn set_dev_data(model: &mut Model) {
    //Goals
    model.goals.push(PracticeGoal {
        name: "Master Nocturnes".to_string(),
        description: Some("Op. 23 & 23".to_string()),
        status: Status::NotStarted,
    });
    model.goals.push(PracticeGoal {
        name: "Perfect Etudes".to_string(),
        description: Some("Op. 23. No. 1 & 101".to_string()),
        status: Status::InProgress,
    });
    model.goals.push(PracticeGoal {
        name: "More Etudes".to_string(),
        description: Some("Op. 25. No. 1".to_string()),
        status: Status::Completed,
    });

    //Exercises
    model.exercises.push(Exercise {
        name: "Scales and Arpeggios".to_string(),
    });
    model.exercises.push(Exercise {
        name: "Chord Progressions".to_string(),
    });
}
