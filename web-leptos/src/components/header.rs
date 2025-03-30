use leptos::prelude::*;
use thaw::*;

#[component]
pub fn header() -> impl IntoView {
    view! {
        <div style="text-align: right;">
            <h1>"Practice App"</h1>
            <Divider />
        </div>
    }
}
