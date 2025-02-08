// use crate::components::Hero;
use dioxus::prelude::*;

#[component]
pub fn Home() -> Element {
    rsx!(
        div { class: "navbar bg-base-100",
            div { class: "navbar-start",
                div { class: "dropdown",
                    div {
                        tabindex: "0",
                        role: "button",
                        class: "btn btn-ghost lg:hidden",
                        svg {
                            xmlns: "http://www.w3.org/2000/svg",
                            class: "h-5 w-5",
                            fill: "none",
                            view_box: "0 0 24 24",
                            stroke: "currentColor",
                            path {
                                stroke_linecap: "round",
                                stroke_linejoin: "round",
                                stroke_width: "2",
                                d: "M4 6h16M4 12h8m-8 6h16",
                            }
                        }
                    }
                    ul {
                        tabindex: "0",
                        class: "menu menu-sm dropdown-content bg-base-100 rounded-box z-[1] mt-3 w-52 p-2 shadow",
                        li {
                            a { "Item 1" }
                        }
                        li {
                            a { "Parent" }
                            ul { class: "p-2",
                                li {
                                    a { "Submenu 1" }
                                }
                                li {
                                    a { "Submenu 2" }
                                }
                            }
                        }
                        li {
                            a { "Item 3" }
                        }
                    }
                }
                a { class: "btn btn-ghost text-xl", "Practice App" }
            }
            div { class: "navbar-center hidden lg:flex",
                ul { class: "menu menu-horizontal px-1",
                    li {
                        a { "Item 1" }
                    }
                    li {
                        details {
                            summary { "Parent" }
                            ul { class: "p-2",
                                li {
                                    a { "Submenu 1" }
                                }
                                li {
                                    a { "Submenu 2" }
                                }
                            }
                        }
                    }
                    li {
                        a { "Item 3" }
                    }
                }
            }
            div { class: "navbar-end",
                a { class: "btn", "Login" }
            }
        }
    )
}
