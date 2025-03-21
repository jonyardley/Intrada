use leptos::prelude::*;

use crate::components::typography::Header1;

#[component]
pub fn Home() -> impl IntoView {
    view! {
        <section>
            <Header1 text="Home" />
        </section>
    }
}
