use dioxus::prelude::*;
use views::Home;

mod components;
mod views;

#[derive(Debug, Clone, Routable, PartialEq)]
#[rustfmt::skip]
enum Route {
    #[route("/")]
    Home {}
}

const FAVICON: Asset = asset!("/assets/favicon.ico");
const DAISY_CSS: &str = "https://cdn.jsdelivr.net/npm/daisyui@5.0.0-beta.7/daisyui.css";
const DAISY_THEMES: &str = "https://cdn.jsdelivr.net/npm/daisyui@5.0.0-beta.7/themes.css";
const TAILWIND_CSS: &str = "https://cdn.tailwindcss.com";
const APP_CSS: Asset = asset!("/assets/styling/main.css");

fn main() {
    dioxus::launch(App);
}

#[component]
fn App() -> Element {
    rsx! {
        document::Link { rel: "icon", href: FAVICON }
        document::Link { rel: "stylesheet", href: DAISY_CSS }
        document::Link { rel: "stylesheet", href: DAISY_THEMES }
        document::Link { rel: "stylesheet", href: TAILWIND_CSS }
        document::Link { rel: "stylesheet", href: APP_CSS }
        div { "data-theme": "dark", Router::<Route> {} }
    }
}
