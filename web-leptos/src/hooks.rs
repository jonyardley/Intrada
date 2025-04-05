use crate::core::{update, Core};
use leptos::prelude::*;
use shared::{Event, ViewModel};

pub struct CoreUpdate {
    pub view: ReadSignal<ViewModel>,
    pub set_event: WriteSignal<Event>,
}

impl CoreUpdate {
    pub fn dispatch(&self, event: Event) {
        self.set_event.set(event);
    }
}

pub fn use_core<F>(core: &Core, initial_event: F) -> CoreUpdate
where
    F: Fn() -> Event + 'static,
{
    let (view, render) = signal(core.view());
    let (event, set_event) = signal(initial_event());
    let core = core.clone();

    Effect::new(move |_| {
        update(&core, event.get(), render);
    });

    CoreUpdate { view, set_event }
}
