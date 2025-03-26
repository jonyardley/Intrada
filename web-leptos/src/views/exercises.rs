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
    let (event, set_event) = signal(shared::Event::GetExercises);

    let (exercise_name, set_exercise_name) = signal("".to_string());

    Effect::new(move |_| {
        core::update(&core, event.get(), render);
    });

    view! {
        <div class="drawer">
            <input id="my-drawer" type="checkbox" class="drawer-toggle" />
            <div class="drawer-content">

                <Header1 text="Exercises".to_string() />

                <label for="my-drawer" class="btn btn-primary btn-sm mb-4">
                    "Add new exercise"
                </label>
                <section class="bg-base-200 p-4">
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
            </div>
            <div class="drawer-side">
                <label for="my-drawer" aria-label="close sidebar" class="drawer-overlay"></label>

                <div class="menu bg-base-200 text-base-content min-h-full p-4">
                    <fieldset class="fieldset w-xs bg-base-200 border border-base-300 p-4 mb-4">
                        <legend class="fieldset-legend">"Add new exercise"</legend>

                        <input
                            type="text"
                            class="input"
                            placeholder="Exercise Name"
                            bind:value=(exercise_name, set_exercise_name)
                        />

                        <div class="join">
                            <label
                                for="my-drawer"
                                class="btn btn-primary drawer-button mr-2 btn-sm"
                                on:click=move |_| {
                                    set_event
                                        .update(|value| {
                                            *value = shared::Event::AddExercise(exercise_name.get());
                                        });
                                    set_exercise_name.set("".to_string());
                                }
                            >
                                "Add exercise"
                            </label>
                            <label
                                for="my-drawer"
                                class="btn btn-error btn-accent btn-outline drawer-button btn-sm"
                                on:click=move |_| {
                                    set_exercise_name.set("".to_string());
                                }
                            >
                                "Cancel"
                            </label>
                        </div>
                    </fieldset>

                </div>
            </div>
        </div>
    }
}
