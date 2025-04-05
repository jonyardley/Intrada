use leptos::prelude::*;

#[component]
pub fn H1(text: String) -> impl IntoView {
    view! { <h1 class="text-2xl font-bold">{text}</h1> }
}

#[component]
pub fn H2(text: String) -> impl IntoView {
    view! { <h2 class="text-xl font-bold mb-5">{text}</h2> }
}
