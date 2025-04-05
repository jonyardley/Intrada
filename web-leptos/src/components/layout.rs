use leptos::prelude::*;

#[component]
pub fn Main(children: Children) -> impl IntoView {
    view! { <main class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">{children()}</main> }
}
