use leptos::prelude::*;

use crate::components::typography::{Header1, Header2};

use crate::core;
use crate::GlobalState;
use reactive_stores::Store;

#[component]
pub fn Goals() -> impl IntoView {
    let state = expect_context::<Store<GlobalState>>().get_untracked();
    let core = state.core;
    let (view, render) = signal(core.view());
    let (event, set_event) = signal(shared::Event::GetGoals);

    Effect::new(move |_| {
        core::update(&core, event.get(), render);
    });

    view! {
        <section>
            <Header1 text="Goals" />
            <Header2 text="What do you want to achieve?" />
            <AddGoalForm set_event=set_event />
        </section>
        <section>
            <Header2 text="Your goals" />
            <section class="bg-base-200 p-4">
                <ul class="list">
                    {move || {
                        if view.get().goals.is_empty() {
                            view! { <p>"No goals - add one above."</p> }.into_any()
                        } else {
                            view.get()
                                .goals
                                .into_iter()
                                .map(|e| {
                                    view! {
                                        <li class="list-row">{e.name}" :: "{e.id.to_string()}</li>
                                    }
                                })
                                .collect_view()
                                .into_any()
                        }
                    }}
                </ul>
            </section>
        </section>
    }
}

#[component]
pub fn AddGoalForm(set_event: WriteSignal<shared::Event>) -> impl IntoView {
    let (goal_name, set_goal_name) = signal("".to_string());

    view! {
        <fieldset class="fieldset w-xs bg-base-200 border border-base-300 p-4 mb-4">
            <legend class="fieldset-legend">"Add new goal"</legend>

            <input
                type="text"
                class="input"
                placeholder="New goal name"
                bind:value=(goal_name, set_goal_name)
            />

            <div class="join">
                <label
                    for="my-drawer"
                    class="btn btn-primary drawer-button mr-2 btn-sm"
                    on:click=move |_| {
                        set_event
                            .update(|value| {
                                *value = shared::Event::AddGoal(goal_name.get());
                            });
                        set_goal_name.set("".to_string());
                    }
                >
                    "Add goal"
                </label>
                <label
                    for="my-drawer"
                    class="btn btn-error btn-accent btn-outline drawer-button btn-sm"
                    on:click=move |_| {
                        set_goal_name.set("".to_string());
                    }
                >
                    "Cancel"
                </label>
            </div>
        </fieldset>
    }
}
