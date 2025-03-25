use console_log;
use leptos::prelude::*;
use log::info;

mod components;
use components::nav::Nav;

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
        <div id="root">
            <Router>
                <Nav />
                <main class="grid grid-cols-1 place-content-center mr-8 ml-8 mt-4">
                    <Routes fallback=|| "Not found.">

                        // DEFAULT WHILST IN DEV
                        <Route path=path!("/") view=Goals />

                        // <Route path=path!("/") view=Home />
                        <Route path=path!("/goals") view=Goals />
                        <Route path=path!("/sessions") view=Sessions />
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
