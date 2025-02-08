mod core;
use dioxus::prelude::*;
use tracing::Level;

use shared::{Event, ViewModel};

use core::CoreService;

mod components;
mod views;

// #[derive(Debug, Clone, Routable, PartialEq)]
// #[rustfmt::skip]
// enum Route {
//     #[route("/")]
//     Home {}
// }

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

#[component]
fn App() -> Element {
    let view = use_signal(ViewModel::default);

    let core = use_coroutine(move |mut rx| {
        let svc = CoreService::new(view);
        async move { svc.run(&mut rx).await }
    });

    rsx! {
        document::Link { rel: "icon", href: FAVICON }
        document::Link { rel: "stylesheet", href: DAISY_CSS }
        document::Link { rel: "stylesheet", href: DAISY_THEMES }
        document::Link { rel: "stylesheet", href: TAILWIND_CSS }
        document::Link { rel: "stylesheet", href: APP_CSS }

        main {
            // section {
            //     div { "data-theme": "dark", Router::<Route> {} }
            // }
            section { class: "section has-text-centered",
                p { class: "is-size-5", "{view().count}" }
                div { class: "buttons section is-centered",
                    button {
                        class: "button is-primary is-success",
                        onclick: move |_| {
                            core.send(Event::Increment);
                        },
                        "Increment"
                    }
                    button {
                        class: "button is-primary is-warning",
                        onclick: move |_| {
                            core.send(Event::Decrement);
                        },
                        "Decrement"
                    }
                }
            }
        }
    }
}
