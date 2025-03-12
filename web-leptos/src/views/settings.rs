use crate::components::typography::Header1;
use leptos::prelude::*;

#[component]
pub fn Settings() -> impl IntoView {
    view! {
        <section>
            <Header1 text="Settings" />
        </section>
    }
}
