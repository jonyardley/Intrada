use crate::app::{Exercise, Model, PracticeGoal, Status};

pub fn set_dev_data(model: &mut Model) {
    //Goals
    model.goals.push(PracticeGoal::new(
        "Master Nocturnes".to_string(),
        Some("Op. 23 & 23".to_string()),
        Some(Status::NotStarted),
    ));
    model.goals.push(PracticeGoal::new(
        "Perfect Etudes".to_string(),
        Some("Op. 23. No. 1 & 101".to_string()),
        Some(Status::InProgress),
    ));
    model.goals.push(PracticeGoal::new(
        "More Etudes".to_string(),
        Some("Op. 25. No. 1".to_string()),
        Some(Status::Completed),
    ));

    //Exercises
    model.exercises.push(Exercise {
        name: "Scales and Arpeggios".to_string(),
    });
    model.exercises.push(Exercise {
        name: "Chord Progressions".to_string(),
    });
}
