use crate::components::{DatePicker, Header, Main, TempoInput, TextInput};
use crate::hooks::{nothing_event, use_core};
use leptos::prelude::*;
use leptos_router::hooks::use_navigate;
use leptos_router::*;

#[component]
pub fn CreateGoal() -> impl IntoView {
    let (name, set_name) = signal(String::new());
    let (description, set_description) = signal(String::new());
    let (target_date, set_target_date) = signal(String::new());
    let (tempo_target, set_tempo_target) = signal(String::new());
    let (selected_studies, set_selected_studies) = signal(Vec::new());

    let (view, set_event) = use_core(nothing_event());
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
                    </div>

                    <div class="border-b border-gray-900/10 pb-12">
                        <h2 class="text-base/7 font-semibold text-gray-900">
                            "Select studies to work on"
                        </h2>

                        <div class="mt-10 space-y-10">
                            <fieldset>
                                <legend class="text-sm/6 font-semibold text-gray-900">
                                    "Available studies"
                                </legend>
                                <div class="mt-6 space-y-6">
                                    {move || {
                                        view.get()
                                            .studies
                                            .into_iter()
                                            .map(|study| {
                                                let study_id = study.id.clone();
                                                let study_id_for_check = study_id.clone();
                                                let is_selected = move || {
                                                    selected_studies.get().contains(&study_id_for_check)
                                                };

                                                view! {
                                                    <div class="relative flex gap-x-3">
                                                        <div class="flex h-6 items-center">
                                                            <input
                                                                id=study.id.clone()
                                                                name="studies"
                                                                type="checkbox"
                                                                class="size-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
                                                                checked=is_selected
                                                                on:change={
                                                                    let study_id = study_id.clone();
                                                                    move |_| {
                                                                        set_selected_studies
                                                                            .update(|studies| {
                                                                                if studies.contains(&study_id) {
                                                                                    studies.retain(|id| id != &study_id);
                                                                                } else {
                                                                                    studies.push(study_id.clone());
                                                                                }
                                                                            });
                                                                    }
                                                                }
                                                            />
                                                        </div>
                                                        <div class="text-sm/6">
                                                            <label
                                                                for=study.id.clone()
                                                                class="font-medium text-gray-900"
                                                            >
                                                                {study.name}
                                                            </label>
                                                            <p class="text-gray-500">
                                                                {study
                                                                    .description
                                                                    .unwrap_or_else(|| "No description".to_string())}
                                                            </p>
                                                        </div>
                                                    </div>
                                                }
                                            })
                                            .collect::<Vec<_>>()
                                    }}
                                </div>
                            </fieldset>
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
                                    *event = nothing_event();
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
