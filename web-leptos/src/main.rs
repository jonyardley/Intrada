use leptos::prelude::*;

mod components;
use components::*;

mod core;
mod views;
use reactive_stores::Store;

use views::*;

use leptos_router::{
    components::{Route, Router, Routes},
    path,
};

#[derive(Clone, Default, Store)]
struct GlobalState {
    core: core::Core,
}

#[component]
pub fn App() -> impl IntoView {
    provide_context(Store::new(GlobalState::default()));

    view! {
        <Router>
            <Nav />
            <main>
                <Routes fallback=|| "Not found.">
                    <Route path=path!("/") view=Home />
                </Routes>
            </main>
        </Router>
    }
}

fn main() {
    console_error_panic_hook::set_once();
    mount_to_body(App);
}
