use crux_core::{
    render::{render, Render},
    App, Command,
};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Event {
    GetExercises,
    AddExercise(String),
}

#[derive(Default)]
pub struct Model {
    exercises: Vec<String>,
}

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct ViewModel {
    pub exercises: Vec<String>,
}

#[cfg_attr(feature = "typegen", derive(crux_core::macros::Export))]
#[derive(crux_core::macros::Effect)]
#[allow(unused)]
pub struct Capabilities {
    render: Render<Event>,
}

#[derive(Default)]
pub struct Chopin;

// ANCHOR: impl_app
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
            Event::GetExercises => {
                // Implement logic to fetch exercises from a data source
                // For now, we'll just return an empty vector
                model.exercises = Vec::new();
            }
            Event::AddExercise(exercise) => model.exercises.push(exercise),
        };

        render()
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        ViewModel {
            exercises: model.exercises.clone(),
        }
    }
}

// TESTS
#[cfg(test)]
mod test {
    use super::*;
    use crux_core::{assert_effect, testing::AppTester};

    #[test]
    fn renders() {
        let app = AppTester::<Chopin>::default();
        let mut model = Model::default();

        let update = app.update(Event::GetExercises, &mut model);

        // Check update asked us to `Render`
        assert_effect!(update, Effect::Render(_));
    }
}
