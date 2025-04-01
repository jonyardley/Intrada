use console_log;
use js_sys;
use leptos::prelude::*;
use leptos_meta::*;
use leptos_router::{
    components::{Route, Router, Routes},
    path,
};

use log::info;
use reactive_stores::Store;
use shared::Event;
use wasm_bindgen::prelude::*;
use web_sys::HtmlElement;

mod components;
mod core;
mod views;
use components::nav::Nav;
use views::{Exercises, Goals, Sessions};

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = ["window", "HSStaticMethods"], js_name = "autoInit")]
    fn hs_static_methods_auto_init();
}

#[derive(Clone, Default, Store)]
struct GlobalState {
    core: core::Core,
}

#[component]
pub fn App() -> impl IntoView {
    // Provide MetaContext for title and meta tags
    provide_meta_context();

    let _ = Effect::new(move |_| {
        // Initialize Preline UI after the component has mounted in the DOM
        let window = web_sys::window().expect("no global window exists");
        if js_sys::Reflect::has(&window, &JsValue::from_str("HSStaticMethods")).unwrap_or(false) {
            hs_static_methods_auto_init();
        } else {
            log::warn!("HSStaticMethods not found in window. Preline UI might not be initialized properly.");
        }
    });

    let global_state = GlobalState::default();
    global_state.core.process_event(Event::SetDevData());
    provide_context(Store::new(global_state));

    view! {
        <Html attr:lang="en" attr:dir="ltr" attr:data-theme="light" />
        <Title text="Practice App" />
        <Meta charset="UTF-8" />
        <Meta name="viewport" content="width=device-width, initial-scale=1.0" />

        <div>

            <main class="container mx-auto p-4">
                <Router>
                    <header class="flex flex-wrap sm:justify-start sm:flex-nowrap w-full bg-gray-800 text-sm py-3 dark:bg-white">
                        <Nav />
                    </header>
                    <Routes fallback=|| view! { <div>"[404] - Oops, page not found."</div> }>
                        <Route path=path!("/") view=|| view! { <Goals /> } />
                        <Route path=path!("/goals") view=|| view! { <Goals /> } />
                        <Route path=path!("/sessions") view=|| view! { <Sessions /> } />
                        <Route path=path!("/exercises") view=|| view! { <Exercises /> } />
                    </Routes>
                </Router>
            </main>
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
