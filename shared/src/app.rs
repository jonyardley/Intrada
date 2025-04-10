use crate::dev;
use crux_core::{
    render::{render, Render},
    App, Command,
};
use serde::{Deserialize, Serialize};

pub mod goal;
pub use goal::*;

pub mod exercise;
pub use exercise::*;

pub mod model;
pub use model::*;

// *************
// EVENTS
// *************
#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Event {
    AddGoal(PracticeGoal),
    AddExercise(Exercise),
    AddExerciseToGoal {
        goal_id: String,
        exercise_id: String,
    },
    SetDevData(),

    Nothing,
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
    type Capabilities = Capabilities;
    type Effect = Effect;

    fn update(
        &self,
        event: Self::Event,
        model: &mut Self::Model,
        _caps: &Self::Capabilities,
    ) -> Command<Effect, Event> {
        match event {
            Event::AddGoal(goal) => add_goal(goal, model),
            Event::AddExercise(exercise) => add_exercise(exercise, model),
            Event::AddExerciseToGoal {
                goal_id,
                exercise_id,
            } => add_exercise_to_goal(goal_id, exercise_id, model),
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
        }
    }
}

#[cfg_attr(feature = "typegen", derive(crux_core::macros::Export))]
#[derive(crux_core::macros::Effect)]
#[allow(unused)]
pub struct Capabilities {
    render: Render<Event>,
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
        let goal = PracticeGoal::new("Test Goal".to_string(), None, None);
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
}
