use console_log;
use leptos::prelude::*;
use leptos_meta::*;
use log::info;
use thaw::*;

mod components;
use components::nav::Nav;

use shared::Event;

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
    provide_meta_context();
    let global_state = GlobalState::default();
    global_state.core.process_event(Event::SetDevData());
    provide_context(Store::new(global_state));

    view! {
        <Html attr:lang="en" attr:dir="ltr" attr:data-theme="dark" />

        // sets the document title
        <Title text="Welcome to Leptos CSR" />

        // injects metadata in the <head> of the page
        <Meta charset="UTF-8" />
        <Meta name="viewport" content="width=device-width, initial-scale=1.0" />

        <ConfigProvider>
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
        </ConfigProvider>
    }
}

fn main() {
    console_error_panic_hook::set_once();
    console_log::init_with_level(log::Level::Info).expect("error initializing logger");
    info!("Application started");
    mount_to_body(App);
}
