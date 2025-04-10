use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::{GoalList, Header, Main, H2};
use crate::hooks::use_core;
use shared::{Event, Status};

#[component]
pub fn Home() -> impl IntoView {
    let (view, _) = use_core(Event::Nothing);
    view! {
        <Header title="Welcome to Intrada".to_string() />
        <Main>
            <section class="bg-white lg:grid">
                <div class="mx-auto w-screen max-w-screen-xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8 lg:py-32">
                    <div class="mx-auto max-w-prose text-center">
                        <h1 class="text-4xl font-bold text-gray-900 sm:text-5xl">
                            "What do you want to "<strong class="text-indigo-600">"achieve"</strong>
                            " today?"
                        </h1>

                        <p class="mt-4 text-base text-pretty text-gray-700 sm:text-lg/relaxed">
                            "Create a new pactice goal, or dive into an existing one."
                        </p>

                        <div class="mt-4 flex justify-center gap-4 sm:mt-6">
                            <A
                                attr:class="inline-block rounded border border-indigo-600 bg-indigo-600 px-5 py-3 font-medium text-white shadow-sm transition-colors hover:bg-indigo-700"
                                href="/goals/new"
                            >
                                "Create a new goal"
                            </A>
                            <A
                                attr:class="inline-block rounded border border-gray-200 px-5 py-3 font-medium text-gray-700 shadow-sm transition-colors hover:bg-gray-50 hover:text-gray-900"
                                href="/goals"
                            >
                                "View existing goals"
                            </A>
                        </div>
                    </div>
                </div>
            </section>
            <section>
                <H2 text="Here are your active goals".to_string() />
                <GoalList goals=move || {
                    view.get()
                        .goals
                        .into_iter()
                        .filter(|goal| goal.status == Status::InProgress)
                        .collect()
                } />
            </section>
        </Main>
    }
}
