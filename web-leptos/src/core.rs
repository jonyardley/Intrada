use std::sync::Arc;

use leptos::prelude::{Update as _, WriteSignal};
use shared::{Chopin, Effect, Event, ViewModel};

pub type Core = Arc<shared::Core<Chopin>>;

pub fn update(core: &Core, event: Event, render: WriteSignal<ViewModel>) {
    for effect in core.process_event(event) {
        process_effect(core, effect, render);
    }
}

pub fn process_effect(core: &Core, effect: Effect, render: WriteSignal<ViewModel>) {
    match effect {
        Effect::Render(_) => {
            render.update(|view| *view = core.view());
        }
        Effect::Http(_) => {
            // Do nothing
        }
    }
}

// *************
// TESTS
// *************

#[cfg(test)]
mod tests {
    use super::*;
    use shared::{Chopin, DevEvent, Event};

    #[test]
    fn test_core_creation() {
        let core = Arc::new(shared::Core::<Chopin>::new());
        assert!(core.view().goals.is_empty());
    }

    #[test]
    fn test_core_process_event() {
        let core = Arc::new(shared::Core::<Chopin>::new());
        let effects = core.process_event(Event::Dev(DevEvent::Nothing));

        // Should return at least one effect (typically a Render effect)
        assert!(!effects.is_empty());
    }

    #[test]
    fn test_core_process_dev_data() {
        let core = Arc::new(shared::Core::<Chopin>::new());
        let effects = core.process_event(Event::Dev(DevEvent::SetDevData));

        // Should return effects when setting dev data
        assert!(!effects.is_empty());

        // After processing dev data, should have some goals
        assert!(!core.view().goals.is_empty());
    }

    #[test]
    fn test_view_model_structure() {
        let core = Arc::new(shared::Core::<Chopin>::new());
        let view_model = core.view();

        // Test that the view model has the expected structure
        assert!(view_model.goals.is_empty());
        assert!(view_model.studies.is_empty());
        assert!(view_model.sessions.is_empty());
    }

    #[test]
    fn test_core_type_alias() {
        let core1 = Arc::new(shared::Core::<Chopin>::new());
        let core2: Core = Arc::new(shared::Core::<Chopin>::new());

        // Both should be the same type
        assert_eq!(std::mem::size_of_val(&core1), std::mem::size_of_val(&core2));
    }

    #[test]
    fn test_event_processing() {
        let core = Arc::new(shared::Core::<Chopin>::new());

        // Test that Nothing event can be processed
        let effects = core.process_event(Event::Dev(DevEvent::Nothing));
        assert!(!effects.is_empty());
    }
}
