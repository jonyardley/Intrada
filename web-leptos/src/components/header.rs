use leptos::prelude::*;

use crate::components::H1;

#[component]
pub fn Header(title: String) -> impl IntoView {
    view! {
        <header class="bg-white shadow-sm">
            <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
                <H1 text=title />
            </div>
        </header>
    }
}
