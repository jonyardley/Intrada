use crate::components::typography::Header1;
use leptos::prelude::*;

use crate::core;
use crate::GlobalState;
use reactive_stores::Store;

#[component]
pub fn Exercises() -> impl IntoView {
    let state = expect_context::<Store<GlobalState>>().get_untracked();
    let core = state.core;
    let (view, render) = signal(core.view());

    let (exercise_name, set_exercise_name) = signal("".to_string());

    let (event, set_event) = signal(shared::Event::Reset);

    Effect::new(move |_| {
        core::update(&core, event.get(), render);
    });

    view! {
        <Header1 text="Exercises" />
        <section class="mb-5">
            <input
                type="text"
                class="input mr-2"
                placeholder="Exercise Name"
                bind:value=(exercise_name, set_exercise_name)
            />
            <button
                class="btn"
                on:click=move |_| {
                    set_event
                        .update(|value| {
                            *value = shared::Event::AddExercise(exercise_name.get());
                        });
                    set_exercise_name.set("".to_string());
                }
            >
                Add Exercise
            </button>
        </section>
        <section>
            <ul class="list">
                {move || {
                    if view.get().exercises.is_empty() {
                        view! { <p>"No exercises - add one above."</p> }.into_any()
                    } else {
                        view.get()
                            .exercises
                            .into_iter()
                            .map(|e| view! { <li class="list-row">{e}</li> })
                            .collect_view()
                            .into_any()
                    }
                }}
            </ul>
        </section>
    }
}

// if view.get().exercises.is_empty() {
// view! { <p>"No exercises found."</p> }
// } else {
// view! {
//    <p>
//        {move || {
//            view.get()
//                .exercises
//                .iter()
//                .map(|exercise| {
//                    view! { <li>{exercise.to_string()}</li> }
//                })
//                .collect::<Vec<_>>()
//        }}
//    </p>
// }
// }
// }}
