use leptos::prelude::*;

#[component]
pub fn Header1(text: &'static str) -> impl IntoView {
    view! { <h1 class="text-2xl font-bold mb-5">{text.to_string()}</h1> }
}

#[component]
pub fn Header2(text: &'static str) -> impl IntoView {
    view! { <h2 class="text-xl font-bold mb-5">{text.to_string()}</h2> }
}
