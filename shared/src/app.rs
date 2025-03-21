// ANCHOR: app
use crux_core::{
    render::{render, Render},
    App, Command,
};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Event {
    Increment,
    Decrement,
    Reset,
    AddExercise(String),
}

#[derive(Default)]
pub struct Model {
    count: isize,
    exercises: Vec<String>,
}

#[derive(Serialize, Deserialize, Clone, Default)]
pub struct ViewModel {
    pub count: String,
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
            Event::Increment => model.count += 1,
            Event::Decrement => model.count -= 1,
            Event::Reset => model.count = 0,
            Event::AddExercise(exercise) => model.exercises.push(exercise),
        };

        render()
    }

    fn view(&self, model: &Self::Model) -> Self::ViewModel {
        ViewModel {
            count: format!("Count is: {}", model.count),
            exercises: model.exercises.clone(),
        }
    }
}
// ANCHOR_END: impl_app
// ANCHOR_END: app

// // ANCHOR: test
// #[cfg(test)]
// mod test {
//     use super::*;
//     use crux_core::{assert_effect, testing::AppTester};

//     #[test]
//     fn renders() {
//         let app = AppTester::<Counter>::default();
//         let mut model = Model::default();

//         let update = app.update(Event::Reset, &mut model);

//         // Check update asked us to `Render`
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn shows_initial_count() {
//         let app = AppTester::<Counter>::default();
//         let model = Model::default();

//         let actual_view = app.view(&model).count;
//         let expected_view = "Count is: 0";
//         assert_eq!(actual_view, expected_view);
//     }

//     #[test]
//     fn increments_count() {
//         let app = AppTester::<Counter>::default();
//         let mut model = Model::default();

//         let update = app.update(Event::Increment, &mut model);

//         let actual_view = app.view(&model).count;
//         let expected_view = "Count is: 1";
//         assert_eq!(actual_view, expected_view);

//         // Check update asked us to `Render`
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn decrements_count() {
//         let app = AppTester::<Counter>::default();
//         let mut model = Model::default();

//         let update = app.update(Event::Decrement, &mut model);

//         let actual_view = app.view(&model).count;
//         let expected_view = "Count is: -1";
//         assert_eq!(actual_view, expected_view);

//         // Check update asked us to `Render`
//         assert_effect!(update, Effect::Render(_));
//     }

//     #[test]
//     fn resets_count() {
//         let app = AppTester::<Counter>::default();
//         let mut model = Model::default();

//         let _ = app.update(Event::Increment, &mut model);
//         let _ = app.update(Event::Reset, &mut model);

//         let actual_view = app.view(&model).count;
//         let expected_view = "Count is: 0";
//         assert_eq!(actual_view, expected_view);
//     }

//     #[test]
//     fn counts_up_and_down() {
//         let app = AppTester::<Counter>::default();
//         let mut model = Model::default();

//         let _ = app.update(Event::Increment, &mut model);
//         let _ = app.update(Event::Reset, &mut model);
//         let _ = app.update(Event::Decrement, &mut model);
//         let _ = app.update(Event::Increment, &mut model);
//         let _ = app.update(Event::Increment, &mut model);

//         let actual_view = app.view(&model).count;
//         let expected_view = "Count is: 1";
//         assert_eq!(actual_view, expected_view);
//     }
// }
// // ANCHOR_END: test
