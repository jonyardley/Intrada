use leptos::prelude::*;
use leptos_router::components::A;

use crate::components::{Header, Main};

#[component]
pub fn Home() -> impl IntoView {
    view! {
        <Header title="Welcome to Intrada".to_string() />
        <Main>
            <section class="bg-white lg:grid">
                <div class="mx-auto w-screen max-w-screen-xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8 lg:py-32">
                    <div class="mx-auto max-w-prose text-center">
                        <h1 class="text-4xl font-bold text-gray-900 sm:text-5xl">
                            "Can you "<strong class="text-indigo-600">"Rachmaninov?"</strong>
                        </h1>

                        <p class="mt-4 text-base text-pretty text-gray-700 sm:text-lg/relaxed">
                            "Let's get you there..."
                        </p>

                        <div class="mt-4 flex justify-center gap-4 sm:mt-6">
                            <A
                                attr:class="inline-block rounded border border-indigo-600 bg-indigo-600 px-5 py-3 font-medium text-white shadow-sm transition-colors hover:bg-indigo-700"
                                href="/sessions"
                            >
                                "Start a session"
                            </A>
                            <A
                                attr:class="inline-block rounded border border-gray-200 px-5 py-3 font-medium text-gray-700 shadow-sm transition-colors hover:bg-gray-50 hover:text-gray-900"
                                href="/goals/new"
                            >
                                "Create a new goal"
                            </A>
                        </div>
                    </div>
                </div>
            </section>
        </Main>
    }
}
