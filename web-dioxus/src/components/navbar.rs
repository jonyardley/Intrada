use crate::Route;
use dioxus::prelude::*;

#[component]
pub fn NavBar() -> Element {
    rsx!(
        div { "data-theme": "dark", class: "navbar bg-base-100",
            div { class: "navbar-start",
                a { class: "btn btn-ghost text-xl", "Practice App" }
            }
            div { class: "navbar-center hidden lg:flex",
                ul { class: "menu menu-horizontal px-1",
                    li {
                        a { "Sessions" }
                    }
                    li {
                        a { "Routines" }
                    }
                    li {
                        a { "Exersizes" }
                    }
                    li {
                        a { "Settings" }
                    }
                }
            }
            div { class: "navbar-end" }
        }
        Outlet::<Route> {}
    )
}
