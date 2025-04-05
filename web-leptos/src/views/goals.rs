use leptos::prelude::*;

use crate::components::{GoalList, Header, Main, H2};
use crate::hooks::use_core;
use shared::Event;

#[component]
pub fn Goals() -> impl IntoView {
    let (view, set_event) = use_core(Event::GetGoals);

    view! {
        <Header title="Goals".to_string() />
        <Main>
            <section>
                <H2 text="What do you want to achieve?".to_string() />
                <AddGoalForm set_event=set_event />
            </section>
            <section>
                <H2 text="Your goals".to_string() />
                <section>
                    <GoalList goals=view.get().goals />
                </section>
            </section>
        </Main>
    }
}

#[component]
pub fn AddGoalForm(set_event: WriteSignal<Event>) -> impl IntoView {
    let (goal_name, set_goal_name) = signal("".to_string());

    let add_goal_handler = move |_| {
        set_event.update(|value| {
            *value = Event::AddGoal(goal_name.get());
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
