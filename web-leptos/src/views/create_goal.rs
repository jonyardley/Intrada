use crate::components::{DatePicker, Header, Main, TempoInput, TextInput, H2};
use crate::hooks::use_core;
use leptos::prelude::*;
use leptos_router::hooks::use_navigate;
use leptos_router::*;
use shared::{Event, PracticeGoal};

#[component]
pub fn CreateGoal() -> impl IntoView {
    let (name, set_name) = signal(String::new());
    let (description, set_description) = signal(String::new());
    let (target_date, set_target_date) = signal(String::new());
    let (tempo_target, set_tempo_target) = signal(String::new());
    let (selected_exercises, set_selected_exercises) = signal(Vec::new());

    let (view, set_event) = use_core(Event::Nothing);
    let navigate = use_navigate();

    view! {
        <Header title="Create a new goal".to_string() />
        <Main>
            <form>
                <div class="space-y-12">
                    <div class="border-b border-gray-900/10 pb-12">
                        <h2 class="text-base/7 font-semibold text-gray-900">
                            "What do you want to achieve?"
                        </h2>

                        <div class="mt-10 grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-6">
                            <div class="sm:col-span-4">
                                <TextInput
                                    label="Goal name".to_string()
                                    id="name".to_string()
                                    value=name
                                    set_value=set_name
                                />

                                <TextInput
                                    label="Goal Description".to_string()
                                    value=description
                                    id="description".to_string()
                                    set_value=set_description
                                />

                                <DatePicker
                                    label="Target date".to_string()
                                    value=target_date
                                    id="target_date".to_string()
                                    set_value=set_target_date
                                />

                                <TempoInput
                                    label="Tempo target".to_string()
                                    value=tempo_target
                                    id="tempo_target".to_string()
                                    set_value=set_tempo_target
                                />

                            </div>
                        </div>
                        <div class="sm:col-span-4">
                            <H2 text="Available Exercises".to_string() />
                            <div class="mt-4 space-y-4">
                                {move || {
                                    view.get()
                                        .exercises
                                        .into_iter()
                                        .map(|exercise| {
                                            let is_selected = selected_exercises
                                                .get()
                                                .contains(&exercise.id);
                                            view! {
                                                <div class="flex items-center gap-2">
                                                    {
                                                        let id = exercise.id.clone();
                                                        let input_id = format!("exercise-{}", id.clone());
                                                        view! {
                                                            <input
                                                                type="checkbox"
                                                                id=input_id.clone()
                                                                class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                                                                checked=is_selected
                                                                on:change=move |ev| {
                                                                    let checked = event_target_checked(&ev);
                                                                    set_selected_exercises
                                                                        .update(|exercises| {
                                                                            if checked {
                                                                                if !exercises.contains(&id) {
                                                                                    exercises.push(id.clone());
                                                                                }
                                                                            } else {
                                                                                exercises.retain(|eid| eid != &id);
                                                                            }
                                                                        });
                                                                }
                                                            />
                                                            <label
                                                                for=input_id
                                                                class="text-sm font-medium text-gray-900"
                                                            >
                                                                {exercise.name}
                                                            </label>
                                                        }
                                                    }
                                                </div>
                                            }
                                        })
                                        .collect::<Vec<_>>()
                                }}
                            </div>
                        </div>
                    </div>
                </div>
                <div class="mt-6 flex items-center justify-end gap-x-6">
                    <button type="button" class="text-sm/6 font-semibold text-gray-900">
                        "Cancel"
                    </button>
                    <button
                        type="submit"
                        class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-xs hover:bg-indigo-500 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                        on:click=move |ev| {
                            ev.prevent_default();
                            set_event
                                .update(|event| {
                                    *event = Event::AddGoal(
                                        PracticeGoal::new(
                                            name.get(),
                                            Some(description.get()),
                                            Some(target_date.get()),
                                            selected_exercises
                                                .get()
                                                .into_iter()
                                                .collect::<Vec<String>>(),
                                            tempo_target.get().parse::<u32>().ok(),
                                        ),
                                    );
                                });
                            navigate(
                                "/goals",
                                NavigateOptions {
                                    replace: true,
                                    ..Default::default()
                                },
                            );
                        }
                    >
                        "Create goal"
                    </button>
                </div>
            </form>
        </Main>
    }
}
