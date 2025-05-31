use console_log;
use leptos::prelude::*;
use leptos_meta::*;
use leptos_router::{
    components::{Route, Router, Routes},
    path,
};
use log::info;
use reactive_stores::Store;
use shared::Event;
use wasm_bindgen::JsCast;
use web_leptos::GlobalState;
use web_sys::HtmlElement;

mod components;
mod core;
mod hooks;
mod views;
use components::Nav;
use views::{CreateGoal, Exercises, Goal, Goals, Home, SessionDetail, Sessions};

#[component]
pub fn App() -> impl IntoView {
    // Provide MetaContext for title and meta tags
    provide_meta_context();

    let global_state = GlobalState::default();
    global_state.core.process_event(Event::SetDevData());
    provide_context(Store::new(global_state));

    view! {
        <Html attr:lang="en" attr:dir="ltr" attr:data-theme="light" />
        <Title text="Intrada" />
        <Meta charset="UTF-8" />
        <Meta name="viewport" content="width=device-width, initial-scale=1.0" />

        <div class="min-h-full">

            <Router>
                <Nav />
                <Routes fallback=|| view! { <div>"[404] - Oops, page not found."</div> }>
                    <Route path=path!("/") view=|| view! { <Home /> } />

                    // Goals
                    <Route path=path!("/goals") view=|| view! { <Goals /> } />
                    <Route path=path!("/goals/new") view=|| view! { <CreateGoal /> } />
                    <Route path=path!("/goals/:id") view=|| view! { <Goal /> } />

                    // Sessions
                    <Route path=path!("/sessions") view=|| view! { <Sessions /> } />
                    <Route path=path!("/sessions/:id") view=|| view! { <SessionDetail /> } />

                    // Exercises
                    <Route path=path!("/exercises") view=|| view! { <Exercises /> } />
                </Routes>
            </Router>
        </div>
    }
}

fn main() {
    if let Some(root_element) = document()
        .get_element_by_id("root")
        .map(|el| el.dyn_into::<HtmlElement>().unwrap())
    {
        console_error_panic_hook::set_once();
        console_log::init_with_level(log::Level::Info).expect("error initializing logger");

        info!("Application started");

        mount_to(root_element, App).forget();
    } else {
        info!("Error: Could not find the element with id 'root' in the DOM.");
    }
}
