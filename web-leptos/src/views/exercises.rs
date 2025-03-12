use crate::components::typography::Header1;
use leptos::prelude::*;

#[component]
pub fn Exercises() -> impl IntoView {
    view! {
        <Header1 text="Exercises" />
        <section>
            <ul>
                <li>Exercise 1</li>
                <li>Exercise 2</li>
                <li>Exercise 3</li>
            </ul>
        </section>
    }
}
