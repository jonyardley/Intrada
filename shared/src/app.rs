use crux_core::{
    macros::effect,
    render::{render, RenderOperation},
    App, Command, capability::Operation,
};
use serde::{Deserialize, Serialize};
use crux_http::{command::Http, protocol::HttpRequest};

const API_URL: &str = "https://crux-counter.fly.dev";

// Appwrite configuration
const APPWRITE_ENDPOINT: &str = "https://cloud.appwrite.io/v1";
const APPWRITE_PROJECT_ID: &str = "your-project-id"; // You'll need to replace this
const APPWRITE_DATABASE_ID: &str = "your-database-id"; // You'll need to replace this

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
    AddGoal(PracticeGoal),
    EditGoal(PracticeGoal),

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
    #[serde(skip)]
    Set(crux_http::Result<crux_http::Response<String>>),

    Get,

    // Simple Appwrite Events - just for loading goals
    LoadGoals,
    #[serde(skip)]
    GoalsLoaded(AppwriteResult),
}

// Simple Appwrite Operation - just for getting goals
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum AppwriteOperation {
    GetGoals,
}

impl Operation for AppwriteOperation {
    type Output = AppwriteResult;
}

// Appwrite Result - wrapper for different response types
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum AppwriteResult {
    Goals(Vec<PracticeGoal>),
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
            Event::AddGoal(goal) => add_goal(goal, model),
            Event::EditGoal(goal) => edit_goal(goal, model),

            Event::AddExercise(exercise) => add_exercise(exercise, model),
            Event::EditExercise(exercise) => edit_exercise(exercise, model),
            Event::AddExerciseToGoal {
                goal_id,
                exercise_id,
            } => add_exercise_to_goal(goal_id, exercise_id, model),

            Event::AddSession(session) => add_session(session, model),
            Event::EditSession(session) => edit_session(session, model),
            Event::SetActiveSession(session_id) => set_active_session(session_id, model),
            Event::StartSession(session_id, timestamp) => { //Make this start Active Session
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

            Event::Get => return Http::get(API_URL)
                .expect_string()
                .build()
                .then_send(Event::Set),
            Event::Set(Ok(mut response)) => {
                let message = response.take_body().unwrap();
                model.message = message;
            }
            Event::Set(Err(e)) => {
                panic!("Oh no something went wrong: {e:?}");
            }
            
            //Do Nothing
            Event::Nothing => (),

            // Simple Appwrite Events - just for loading goals
            Event::LoadGoals => {
                // Request goals from the shell (iOS app)
                return Command::request_from_shell(AppwriteOperation::GetGoals)
                    .then_send(Event::GoalsLoaded);
            }
            Event::GoalsLoaded(result) => {
                // Update the model with the loaded goals
                match result {
                    AppwriteResult::Goals(goals) => {
                        model.goals = goals;
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
            message: model.message.clone(),
        }
    }
}

// ------------------------------------------------------------------
// TESTS
//
#[cfg(test)]
mod test {
    use super::*;
    use crux_core::{assert_effect, testing::AppTester};

    #[test]
    fn renders() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(Event::Nothing, &mut model);

        // Check update asked us to `Render`
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn adds_exercise() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(
            Event::AddExercise(Exercise::new("Exercise".to_string(), Some("".to_string()))),
            &mut model,
        );

        // Check update asked us to `Render`
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn adds_goal() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(
            Event::AddGoal(PracticeGoal::new(
                "Goal".to_string(),
                Some("".to_string()),
                Some("2025-05-01".to_string()),
                vec![],
                None,
            )),
            &mut model,
        );

        // Check update asked us to `Render`
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn sets_dev_data() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(Event::SetDevData(), &mut model);

        // Check update asked us to `Render`
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn adds_exercise_to_goal() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        // First add a goal
        let goal = PracticeGoal::new(
            "Test Goal".to_string(),
            None,
            None,
            vec!["Exercise 1".to_string()],
            None,
        );
        let update = app.update(Event::AddGoal(goal), &mut model);
        assert_effect!(update, Effect::Render(_));

        // Then add an exercise
        let exercise = Exercise::new("Test Exercise".to_string(), None);
        let update = app.update(Event::AddExercise(exercise), &mut model);
        assert_effect!(update, Effect::Render(_));

        // Now we can safely add the exercise to the goal
        let update = app.update(
            Event::AddExerciseToGoal {
                goal_id: model.goals[0].id.clone(),
                exercise_id: model.exercises[0].id.clone(),
            },
            &mut model,
        );

        // Check update asked us to `Render`
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn adds_session() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(
            Event::AddSession(PracticeSession::new(
                vec!["Goal 1".to_string()],
                "Intention 1".to_string(),
            )),
            &mut model,
        );
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn edits_session() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(
            Event::EditSession(PracticeSession::new(
                vec!["Goal 1".to_string()],
                "Intention 1".to_string(),
            )),
            &mut model,
        );
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn start_session() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(
            Event::StartSession(
                PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string())
                    .id
                    .clone(),
                "2025-05-01".to_string(),
            ),
            &mut model,
        );
        assert_effect!(update, Effect::Render(_));
    }

    #[test]
    fn end_session() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(
            Event::EndSession(
                PracticeSession::new(vec!["Goal 1".to_string()], "Intention 1".to_string())
                    .id
                    .clone(),
                "2025-05-01".to_string(),
            ),
            &mut model,
        );
        assert_effect!(update, Effect::Render(_));
    }
}
