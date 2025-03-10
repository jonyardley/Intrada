use console_log;
use leptos::prelude::*;
use log::info;

mod components;
use components::*;

mod core;
mod views;
use reactive_stores::Store;

use views::*;

use leptos_router::{
    components::{Route, Router, Routes}, path
};

#[derive(Clone, Default, Store)]
struct GlobalState {
    core: core::Core,
}

#[component]
pub fn App() -> impl IntoView {
    provide_context(Store::new(GlobalState::default()));

    view! {
        <div id="root">
            <Router>
                <Nav />
                <main>
                    <Routes fallback=|| "Not found.">
                        <Route path=path!("/") view=Home />
                        <Route path=path!("/exercises") view=Exercises />
                    </Routes>
                </main>
            </Router>
        </div>
    }
}

fn main() {
    console_error_panic_hook::set_once();
    console_log::init_with_level(log::Level::Info).expect("error initializing logger");
    info!("Application started");
    mount_to_body(App);
}
