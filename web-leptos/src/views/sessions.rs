use crate::components::typography::Header1;
use leptos::prelude::*;

#[component]
pub fn Sessions() -> impl IntoView {
    view! {
        <section>
            <Header1 text="Sessions" />
        </section>
    }
}
