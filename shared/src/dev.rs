use crate::app::{Event, Exercise, PracticeGoal, Status};

pub fn set_dev_data() -> Vec<Event> {
    let mut events = Vec::new();

    //Exercises
    events.push(Event::AddExercise(Exercise::new(
        "Scales over 2 octaves".to_string(),
        Some("In all keys".to_string()),
    )));
    events.push(Event::AddExercise(Exercise::new(
        "Arpeggios over 2 octaves".to_string(),
        Some("In all keys".to_string()),
    )));

    //Goals
    events.push(Event::AddGoal(PracticeGoal::new(
        "Master Nocturnes".to_string(),
        Some("Op. 23 & 23".to_string()),
        Some(Status::NotStarted),
    )));
    events.push(Event::AddGoal(PracticeGoal::new(
        "Perfect Etudes".to_string(),
        Some("Op. 23. No. 1 & 101".to_string()),
        Some(Status::InProgress),
    )));
    events.push(Event::AddGoal(PracticeGoal::new(
        "More Etudes".to_string(),
        Some("Op. 25. No. 1".to_string()),
        Some(Status::Completed),
    )));

    events
}
