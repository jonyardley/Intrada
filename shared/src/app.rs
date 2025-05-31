use crux_core::{
    macros::effect,
    render::{render, RenderOperation},
    App, Command,
};
use serde::{Deserialize, Serialize};

pub mod goal;
pub use goal::*;

pub mod exercise;
pub use exercise::*;

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
    AddExerciseToGoal {
        goal_id: String,
        exercise_id: String,
    },

    AddSession(PracticeSession),
    EditSession(PracticeSession),
    StartSession(String, String),
    EndSession(String, String),

    SetDevData(),
    Nothing,
}

#[effect]
pub enum Effect {
    Render(RenderOperation),
    // Http(HttpRequest),
    // ServerSentEvents(SseRequest),
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
            Event::AddExerciseToGoal {
                goal_id,
                exercise_id,
            } => add_exercise_to_goal(goal_id, exercise_id, model),

            Event::AddSession(session) => add_session(session, model),
            Event::EditSession(session) => edit_session(session, model),
            Event::StartSession(session_id, timestamp) => {
                start_session(session_id, timestamp, model)
            }
            Event::EndSession(session_id, timestamp) => end_session(session_id, timestamp, model),

            Event::SetDevData() => dev::set_dev_data(model),

            //No Nothing
            Event::Nothing => (),
        };

        render()
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        ViewModel {
            goals: model.goals.clone(),
            exercises: model.exercises.clone(),
            sessions: model.sessions.clone(),
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
