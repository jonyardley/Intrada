use leptos::prelude::*;

use crate::components::Header;

#[component]
pub fn Home() -> impl IntoView {
    view! {
        <Header />
        <main>
            <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">"This is the home page"</div>
        </main>
    }
}
