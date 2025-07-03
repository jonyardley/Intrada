use leptos::prelude::*;

use crate::components::{Header, Main};
use crate::hooks::use_core;
use shared::Event;

#[component]
pub fn Studies() -> impl IntoView {
    let (view, _) = use_core(Event::Nothing);

    view! {
        <Header title="Studies".to_string() />
        <Main>
            <ul class="list">
                {move || {
                    if view.get().studies.is_empty() {
                        view! { <p>"No studies - add one above."</p> }.into_any()
                    } else {
                        view.get()
                            .studies
                            .into_iter()
                            .map(|e| view! { <li class="list-row">{e.name}</li> })
                            .collect_view()
                            .into_any()
                    }
                }}
            </ul>
        </Main>
    }
}
