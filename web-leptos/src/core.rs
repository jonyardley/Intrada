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
    };
