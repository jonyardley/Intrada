mod core;

use leptos::prelude::*;

fn main() {
    mount_to_body(App);
}

#[component]
pub fn App() -> impl IntoView {
    let core = core::new();
    let (view, render) = signal(core.view());
    let (event, set_event) = signal(shared::Event::Reset);

    Effect::new(move |_| {
        core::update(&core, event.get(), render);
    });

    view! {
        <div class="navbar bg-base-100">
            <a class="btn btn-ghost text-xl">"Practice App"</a>
        </div>
        <section class="box container has-text-centered m-5">
            <p class="is-size-5">{move || view.get().count}</p>
            <div class="buttons section is-centered">

                <button class="btn btn-error mr-4"
                    on:click=move |_| set_event.update(|value| *value = shared::Event::Reset)
                >
                    {"Reset"}
                </button>

                <button class="btn btn-success mr-4"
                    on:click=move |_| set_event.update(|value| *value = shared::Event::Increment)
                >
                    {"Increment"}
                </button>

                <button class="btn btn-warning"
                    on:click=move |_| set_event.update(|value| *value = shared::Event::Decrement)
                >
                    {"Decrement"}
                </button>
            </div>
        </section>
    }
}
