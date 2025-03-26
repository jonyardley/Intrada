use leptos::prelude::*;

use crate::components::typography::{CardTitle, Header1, Header2};

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
            <Header1 text="Goals".to_string() />
            <Header2 text="What do you want to achieve?".to_string() />
            <AddGoalForm set_event=set_event />
        </section>
        <section>
            <Header2 text="Your goals".to_string() />
            <section>
                <ul class="list grid grid-cols-3 grid-flow-row-dense">
                    {move || {
                        if view.get().goals.is_empty() {
                            view! { <p>"No goals - add one above."</p> }.into_any()
                        } else {
                            view.get()
                                .goals
                                .into_iter()
                                .map(|e| {
                                    view! {
                                        <div class="card bg-base-100 card-sm shadow-sm col-span-1 m-2">
                                            <div class="card-body">
                                                <CardTitle text=e.name />
                                                <p>"id:: "{e.id.to_string()}</p>
                                                <div class="justify-end card-actions">
                                                    <button class="btn btn-primary">Details</button>
                                                </div>
                                            </div>
                                        </div>
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

    let add_goal_handler = move |_| {
        set_event.update(|value| {
            *value = shared::Event::AddGoal(goal_name.get());
            set_goal_name.set("".to_string());
        });
    };

    let cancel_handler = move |_| {
        set_goal_name.set("".to_string());
    };

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
                <button class="btn btn-primary btn-sm" on:click=add_goal_handler>
                    "Add goal"
                </button>
                <button
                    class="btn btn-error btn-accent btn-outline drawer-button btn-sm ml-2"
                    on:click=cancel_handler
                >
                    "Cancel"
                </button>
            </div>
        </fieldset>
    }
}
