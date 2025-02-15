use leptos::prelude::*;

fn main() {
    mount_to_body(App);
}

#[component]
pub fn App() -> impl IntoView {
    view! {
        <div class="navbar bg-base-100">
            <a class="btn btn-ghost text-xl">"Practice App"</a>
        </div>
    }
}
