use crate::components::{Header, Main};
use leptos::prelude::*;

#[component]
pub fn Sessions() -> impl IntoView {
    view! {
        <Header title="Sessions".to_string() />
        <Main>
            <p>"Here are your sessions"</p>
        </Main>
    }
}
