mod crux_core;
use components::NavBar;
use dioxus::prelude::*;
use tracing::Level;
use views::Home;

use shared::{Event, ViewModel};

use crux_core::CoreService;

mod components;
mod views;

#[derive(Debug, Clone, Routable, PartialEq)]
#[rustfmt::skip]
enum Route {
    #[layout(NavBar)]
    #[route("/")]
    Home {},
}

const FAVICON: Asset = asset!("/assets/favicon.ico");
const DAISY_CSS: &str = "https://cdn.jsdelivr.net/npm/daisyui@5.0.0-beta.7/daisyui.css";
const DAISY_THEMES: &str = "https://cdn.jsdelivr.net/npm/daisyui@5.0.0-beta.7/themes.css";
const TAILWIND_CSS: &str = "https://cdn.tailwindcss.com";
const APP_CSS: Asset = asset!("/assets/styling/main.css");

fn main() {
    dioxus_logger::init(Level::DEBUG).expect("failed to init logger");
    console_error_panic_hook::set_once();

    dioxus::launch(App);
}
#[derive(Clone)]
pub struct AppContext {
    core: Coroutine<Event>,
    view: Signal<ViewModel>,
}

#[component]
fn App() -> Element {
    let view = use_signal(ViewModel::default);
    let crux_core = use_coroutine(move |mut rx| {
        let svc = CoreService::new(view);
        async move { svc.run(&mut rx).await }
    });

    let context: AppContext = AppContext {
        core: crux_core,
        view: view,
    };

    use_context_provider(|| context);

    rsx! {
        document::Link { rel: "icon", href: FAVICON }
        document::Link { rel: "stylesheet", href: DAISY_CSS }
        document::Link { rel: "stylesheet", href: DAISY_THEMES }
        document::Link { rel: "stylesheet", href: TAILWIND_CSS }
        document::Link { rel: "stylesheet", href: APP_CSS }

        main {
            div { "data-theme": "lightark",
                section { Router::<Route> {} }
            }
        }
    }
}
