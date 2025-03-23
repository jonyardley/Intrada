use leptos::prelude::*;

use crate::components::typography::Header1;

#[component]
pub fn Goals() -> impl IntoView {
    view! {
        <section>
            <Header1 text="Goals" />
        </section>
    }
}
