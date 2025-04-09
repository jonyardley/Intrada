use crate::dev;
use crux_core::{
    render::{render, Render},
    App, Command,
};
use serde::{Deserialize, Serialize};
use uuid;

// *************
// GOALS
// *************
#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct PracticeGoal {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub status: Status,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
}

#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub enum Status {
    #[default]
    NotStarted,
    InProgress,
    Completed,
}

impl PracticeGoal {
    pub fn new(name: String, description: Option<String>, status: Option<Status>) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            description,
            status: status.unwrap_or(Status::NotStarted),
            start_date: None,
            end_date: None,
        }
    }
}

// *************
// EXERCISES
// *************
#[derive(Serialize, Deserialize, Clone, Default, Debug, PartialEq)]
pub struct Exercise {
    pub name: String,
}

// *************
// EVENTS
// *************
#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Event {
    AddGoal(PracticeGoal),
    AddExercise(Exercise),
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
            Event::AddGoal(goal) => {
                model.goals.push(goal);
            }
            Event::AddExercise(exercise) => model.exercises.push(exercise),
            Event::SetDevData() => dev::set_dev_data(model),
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

#[derive(Default)]
pub struct Model {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
}

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct ViewModel {
    pub goals: Vec<PracticeGoal>,
    pub exercises: Vec<Exercise>,
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
            Event::AddExercise(Exercise {
                name: "Exercise".to_string(),
            }),
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
                Some(Status::NotStarted),
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
}
