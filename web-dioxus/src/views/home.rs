use dioxus::prelude::*;
use shared::Event;

use crate::AppContext; // Adjust the path according to your project structure

#[component]
pub fn Home() -> Element {
    let context = use_context::<AppContext>();
    let count = context.view.read().count.clone();

    rsx!(
        h1 { "hello world" }
        section { class: "section has-text-centered",
            p { class: "is-size-5", "Count: {count}" }
            div { class: "buttons section is-centered",
                button {
                    class: "button is-primary is-success",
                    onclick: move |_| {
                        context.core.send(Event::Increment);
                    },
                    "Increment"
                }
                button {
                    class: "button is-primary is-warning",
                    onclick: move |_| {
                        context.core.send(Event::Decrement);
                    },
                    "Decrement"
                }
            }
        }
    )
}
