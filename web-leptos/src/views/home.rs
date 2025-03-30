use leptos::prelude::*;

#[component]
pub fn Home() -> impl IntoView {
    view! {
        <section>
            <h2>"Dashboard"</h2>
            <p>"Welcome to the home page of the Practice App."</p>
            <p>"This page will show a summary of your practice sessions and goals."</p>
        </section>
    }
}
