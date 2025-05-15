use crate::components::{GoalList, Header, Main, H2};
use crate::hooks::use_core;
use leptos::prelude::Memo;
use leptos::prelude::*;
use leptos_router::components::A;
use shared::Event;

#[component]
pub fn Goals() -> impl IntoView {
    let (view, _) = use_core(Event::Nothing);
    let goals = Memo::new(move |_| view.get().goals);

    view! {
        <Header title="Goals".to_string() />
        <Main>
            <section class="mb-8">
                <A
                    href="/goal/new"
                    attr:class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
                >
                    <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="size-4"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                        stroke-width="2"
                    >
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                    </svg>
                    Create New Goal
                </A>
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
