use leptos::prelude::*;
use reactive_stores::Store;

use crate::core;
use crate::GlobalState;
use shared::{DevEvent, Event, ViewModel};

pub fn use_core(initial_event: Event) -> (ReadSignal<ViewModel>, WriteSignal<Event>) {
    let state = expect_context::<Store<GlobalState>>().get_untracked();
    let core = state.core;
    let (view, render) = signal(core.view());
    let (event, set_event) = signal(initial_event);

    Effect::new(move |_| {
        core::update(&core, event.get(), render);
    });

    (view, set_event)
}

// Helper function to create a Nothing event
pub fn nothing_event() -> Event {
    Event::Dev(DevEvent::Nothing)
}
