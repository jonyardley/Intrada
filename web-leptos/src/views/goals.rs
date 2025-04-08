use leptos::prelude::Memo;
use leptos::prelude::*;

use crate::components::{GoalList, Header, Main, H2};
use crate::hooks::use_core;
use shared::{Event, PracticeGoal};

#[component]
pub fn Goals() -> impl IntoView {
    let (view, set_event) = use_core(Event::GetGoals);
    let goals = Memo::new(move |_| view.get().goals);

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
                    <GoalList goals=move || goals.get() />
                </section>
            </section>
        </Main>
    }
}

#[component]
pub fn AddGoalForm(set_event: WriteSignal<Event>) -> impl IntoView {
    let (name, set_name) = signal("".to_string());
    let (description, set_description) = signal("".to_string());

    let add_goal_handler = move |_| {
        set_event.update(|value| {
            *value = Event::AddGoal(PracticeGoal::new(name.get(), Some(description.get()), None));

            set_name.set("".to_string());
            set_description.set("".to_string());
        });
    };

    let cancel_handler = move |_| {
        set_name.set("".to_string());
        set_description.set("".to_string());
    };

    view! {
        <fieldset class="fieldset w-xs bg-base-200 border border-base-300 p-4 mb-4">
            <legend class="fieldset-legend">"Add new goal"</legend>

            <input
                type="text"
                class="input"
                placeholder="New goal name"
                bind:value=(name, set_name)
            />
            <input
                type="text"
                class="input"
                placeholder="New goal description"
                bind:value=(description, set_description)
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
