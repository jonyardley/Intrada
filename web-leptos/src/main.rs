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

    let env_config = leptos_config::get_config_from_env();

    view! {
        <Router>
            <Nav />
            <h1>{format!("Site Address: {}", env_config.clone().unwrap().leptos_options.site_addr)}</h1>
            <h1>{format!("Site Root: {}", env_config.unwrap().leptos_options.site_root)}</h1>
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
    console_log::init_with_level(log::Level::Info).expect("error initializing logger");
    info!("Application started");
    mount_to_body(App);
}
