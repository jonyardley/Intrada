use leptos::prelude::*;

use crate::components::typography::Header1;
use crate::hooks::use_core;
use shared::Event;

#[component]
pub fn Exercises() -> impl IntoView {
    let (view, set_event) = use_core(Event::GetExercises);
    let (exercise_name, set_exercise_name) = signal("".to_string());

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
                            placeholder="New exercise name"
                            bind:value=(exercise_name, set_exercise_name)
                        />
                        <div class="join">
                            <button
                                class="btn btn-primary btn-sm"
                                on:click=move |_| {
                                    set_event
                                        .update(|value| {
                                            *value = Event::AddExercise(exercise_name.get());
                                            set_exercise_name.set("".to_string());
                                        });
                                }
                            >
                                "Add exercise"
                            </button>
                            <button
                                class="btn btn-error btn-accent btn-outline drawer-button btn-sm ml-2"
                                on:click=move |_| {
                                    set_exercise_name.set("".to_string());
                                }
                            >
                                "Cancel"
                            </button>
                        </div>
                    </fieldset>
                </div>
            </div>
        </div>
    }
}
