use leptos::prelude::*;

use crate::components::{GoalList, Header, Main, H2};
use crate::hooks::use_core;
use shared::{Event, Status};

#[component]
pub fn Home() -> impl IntoView {
    let (view, _) = use_core(Event::GetGoals);
    view! {
        <Header title="Welcome to Intrada".to_string() />
        <Main>
            <H2 text="Here are your active goals".to_string() />
            <GoalList goals=move || {
                view.get()
                    .goals
                    .into_iter()
                    .filter(|goal| goal.status == Status::InProgress)
                    .collect()
            } />
        </Main>
    }
}
