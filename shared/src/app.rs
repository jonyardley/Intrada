use crux_core::{
    macros::effect,
    render::{render, RenderOperation},
    App, Command, capability::Operation,
};
use serde::{Deserialize, Serialize};
use crux_http::{protocol::HttpRequest};

pub mod goal;
pub use goal::*;

pub mod exercise;
pub use exercise::*;

pub mod exercise_record;
pub use exercise_record::*;

pub mod session;
pub use session::*;

pub mod model;
pub use model::*;

pub mod dev;
pub use dev::*;

// *************
// EVENTS
// *************
#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Event {
    AddExercise(Exercise),
    EditExercise(Exercise),
    AddExerciseToGoal {
        goal_id: String,
        exercise_id: String,
    },

    AddSession(PracticeSession),
    EditSession(PracticeSession),
    SetActiveSession(String),
    StartSession(String, String),
    UnsetActiveSession(),
    EndSession(String, String),
    EditSessionNotes(String, String),

    AddExerciseRecord(ExerciseRecord),
    UpdateExerciseRecord(ExerciseRecord),

    SetDevData(),
    Nothing,

    // Simple Appwrite Events - just for loading goals
    LoadGoals,
    CreateGoal(PracticeGoal),
    UpdateGoal(PracticeGoal),
    DeleteGoal(String),
    #[serde(skip)]
    GoalsLoaded(AppwriteResult),
}

// Simple Appwrite Operation - just for getting goals
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum AppwriteOperation {
    GetGoals,
    CreateGoal(PracticeGoal),
    UpdateGoal(PracticeGoal),
    DeleteGoal(String),
}

impl Operation for AppwriteOperation {
    type Output = AppwriteResult;
}

// Appwrite Result - wrapper for different response types
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum AppwriteResult {
    Goals(Vec<PracticeGoal>),
    Goal(PracticeGoal), // For create/update operations
    Success, // For delete operations
    Error(String), // For error handling
}

#[effect]
pub enum Effect {
    Render(RenderOperation),
    Http(HttpRequest),
    Appwrite(AppwriteOperation),
}

// *************
// APP
// *************
#[derive(Default)]
pub struct Chopin;

impl App for Chopin {
    type Event = Event;
    type Model = Model;
    type ViewModel = ViewModel;
    type Capabilities = ();
    type Effect = Effect;

    fn update(
        &self,
        event: Self::Event,
        model: &mut Self::Model,
        _caps: &Self::Capabilities,
    ) -> Command<Effect, Event> {
        match event {

            Event::AddExercise(exercise) => add_exercise(exercise, model),
            Event::EditExercise(exercise) => edit_exercise(exercise, model),
            Event::AddExerciseToGoal {
                goal_id,
                exercise_id,
            } => add_exercise_to_goal(goal_id, exercise_id, model),

            Event::AddSession(session) => add_session(session, model),
            Event::EditSession(session) => edit_session(session, model),
            Event::SetActiveSession(session_id) => set_active_session(session_id, model),
            Event::StartSession(session_id, timestamp) => {
                start_session(session_id, timestamp, model)
            }
            Event::EndSession(session_id, timestamp) => end_session(session_id, timestamp, model), // End Active Session
            Event::UnsetActiveSession() => remove_active_session(model),
            Event::EditSessionNotes(session_id, notes) => {
                edit_session_notes(session_id, notes, model)
            }

            Event::AddExerciseRecord(record) => add_exercise_record(record, model),
            Event::UpdateExerciseRecord(record) => update_exercise_record(record, model),

            Event::SetDevData() => dev::set_dev_data(model),

            //Do Nothing
            Event::Nothing => (),

            // Simple Appwrite Events - just for loading goals
            Event::LoadGoals => {
                // Request goals from the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::GetGoals)
                    .then_send(Event::GoalsLoaded);
            }
            Event::CreateGoal(goal) => {
                // Request to create a goal via the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::CreateGoal(goal))
                    .then_send(Event::GoalsLoaded);
            }
            Event::UpdateGoal(goal) => {
                // Request to update a goal via the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::UpdateGoal(goal))
                    .then_send(Event::GoalsLoaded);
            }
            Event::DeleteGoal(goal_id) => {
                // Request to delete a goal via the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::DeleteGoal(goal_id))
                    .then_send(Event::GoalsLoaded);
            }
            Event::GoalsLoaded(result) => {
                // Update the model with the loaded goals
                match result {
                    AppwriteResult::Goals(goals) => {
                        model.goals = goals;
                    }
                    AppwriteResult::Goal(goal) => {
                        // Handle single goal result (for create/update)
                        // You might want to update the existing goal or add it to the list
                        if let Some(existing_index) = model.goals.iter().position(|g| g.id == goal.id) {
                            model.goals[existing_index] = goal;
                        } else {
                            model.goals.push(goal);
                        }
                    }
                    AppwriteResult::Success => {
                        // Handle success case (for delete operations)
                        // No action needed for now
                    }
                    AppwriteResult::Error(error_message) => {
                        // Handle error case
                        println!("Appwrite error: {}", error_message);
                        // You might want to set an error state in the model
                    }
                }
            }
        };

        render()
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        ViewModel {
            goals: model.goals.clone(),
            exercises: model.exercises.clone(),
            sessions: model.sessions.clone(),
            app_state: model.app_state.clone(),
        }
    }
}

// // ------------------------------------------------------------------
// // TESTS
// //
// #[cfg(test)]
// mod test {
//     use super::*;
//     use crux_core::{assert_effect, testing::AppTester};

//     #[test]
//     fn renders() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         let update = app.update(Event::Nothing, &mut model);

//         // Check update asked us to `Render`
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn adds_exercise() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         let update = app.update(
//             Event::AddExercise(Exercise::new("Exercise".to_string(), Some("".to_string()))),
//             &mut model,
//         );

//         // Check update asked us to `Render`
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn sets_dev_data() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         let update = app.update(Event::SetDevData(), &mut model);

//         // Check update asked us to `Render`
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn adds_exercise_to_goal() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         // First add a goal
//         let goal = PracticeGoal::new(
//             "Test Goal".to_string(),
//             None,
//             None,
//             vec!["Exercise 1".to_string()],
//             None,
//         );
//         let update = app.update(Event::AddGoal(goal), &mut model);
//         assert_effect!(update, Effect::Render(_));

//         // Then add an exercise
//         let exercise = Exercise::new("Test Exercise".to_string(), None);
//         let update = app.update(Event::AddExercise(exercise), &mut model);
//         assert_effect!(update, Effect::Render(_));

//         // Now we can safely add the exercise to the goal
//         let update = app.update(
//             Event::AddExerciseToGoal {
//                 goal_id: model.goals[0].id.clone(),
//                 exercise_id: model.exercises[0].id.clone(),
//             },
//             &mut model,
//         );

//         // Check update asked us to `Render`
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn adds_session() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         let update = app.update(
//             Event::AddSession(PracticeSession::new(
//                 vec!["Goal 1".to_string()],
//                 "Intention 1".to_string(),
//             )),
//             &mut model,
//         );
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn edits_session() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         let update = app.update(
//             Event::EditSession(PracticeSession::new(
//                 vec!["Goal 1".to_string()],
//                 "Intention 1".to_string(),
//             )),
//             &mut model,
//         );
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn start_session() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         let update = app.update(
//             Event::StartSession(
//                 PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string())
//                     .id
//                     .clone(),
//                 "2025-05-01".to_string(),
//             ),
//             &mut model,
//         );
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn end_session() {
//         let app = AppTester::<Chopin>::default();
//         let mut model = Model::default();

//         let update = app.update(
//             Event::EndSession(
//                 PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string())
//                     .id
//                     .clone(),
//                 "2025-05-01".to_string(),
//             ),
//             &mut model,
//         );
//         assert_effect!(update, Effect::Render(_));
//     }
// }
