use leptos::prelude::*;
use leptos_router::components::A;
use leptos_router::hooks::use_location;

#[component]
pub fn Nav() -> impl IntoView {
    let (is_mobile_menu_open, set_mobile_menu_open) = signal(false);

    view! {
        <nav class="bg-gray-800">
            <div class="mx-auto max-w-7xl px-2 sm:px-6 lg:px-8">
                <div class="relative flex h-16 items-center justify-between">
                    <div class="absolute inset-y-0 left-0 flex items-center sm:hidden">
                        <button
                            type="button"
                            class="relative inline-flex items-center justify-center rounded-md p-2 text-gray-400 hover:bg-gray-700 hover:text-white focus:ring-2 focus:ring-white focus:outline-hidden focus:ring-inset"
                            on:click=move |_| set_mobile_menu_open.set(!is_mobile_menu_open.get())
                            aria-controls="mobile-menu"
                            aria-expanded=move || is_mobile_menu_open.get().to_string()
                        >
                            <span class="absolute -inset-0.5"></span>
                            <span class="sr-only">"Open main menu"</span>

                            <svg
                                class=move || {
                                    if is_mobile_menu_open.get() {
                                        "hidden size-6"
                                    } else {
                                        "block size-6"
                                    }
                                }
                                fill="none"
                                viewBox="0 0 24 24"
                                stroke-width="1.5"
                                stroke="currentColor"
                                aria-hidden="true"
                            >
                                <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
                                />
                            </svg>

                            <svg
                                class=move || {
                                    if is_mobile_menu_open.get() {
                                        "block size-6"
                                    } else {
                                        "hidden size-6"
                                    }
                                }
                                fill="none"
                                viewBox="0 0 24 24"
                                stroke-width="1.5"
                                stroke="currentColor"
                                aria-hidden="true"
                            >
                                <path
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                    d="M6 18 18 6M6 6l12 12"
                                />
                            </svg>
                        </button>
                    </div>

                    <div class="flex flex-1 items-center justify-center sm:items-stretch sm:justify-start">
                        <div class="flex shrink-0 items-center">
                            <svg
                                class="h-8 w-auto text-gray-300"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                stroke-width="2"
                                stroke-linecap="round"
                                stroke-linejoin="round"
                            >
                                <path d="M9 18V5l12-2v13" />
                                <circle cx="6" cy="18" r="3" />
                                <circle cx="18" cy="16" r="3" />
                            </svg>
                        </div>

                        <div class="hidden sm:ml-6 sm:block">
                            <div class="flex space-x-4">
                                <MenuItems mobile=false />
                            </div>
                        </div>
                    </div>

                </div>
            </div>

            <div
                class=move || {
                    if is_mobile_menu_open.get() { "sm:hidden" } else { "sm:hidden hidden" }
                }
                id="mobile-menu"
            >
                <div class="space-y-1 px-2 pt-2 pb-3">
                    <MenuItems mobile=true />
                </div>
            </div>
        </nav>
    }
}

// Simple struct to represent a navigation item
struct MenuItem {
    path: &'static str,
    label: &'static str,
}

#[component]
pub fn MenuItems(mobile: bool) -> impl IntoView {
    // Define styles based on mobile prop
    let (active_class, inactive_class) = if mobile {
        (
            "bg-gray-900 text-white block rounded-md px-3 py-2 text-base font-medium",
            "text-gray-300 hover:bg-gray-700 hover:text-white block rounded-md px-3 py-2 text-base font-medium"
        )
    } else {
        (
            "bg-gray-900 text-white rounded-md px-3 py-2 text-sm font-medium",
            "text-gray-300 hover:bg-gray-700 hover:text-white rounded-md px-3 py-2 text-sm font-medium"
        )
    };

    // Define all menu items in a central place
    let menu_items = vec![
        MenuItem {
            path: "/",
            label: "Dashboard",
        },
        MenuItem {
            path: "/goals",
            label: "Goals",
        },
        MenuItem {
            path: "/sessions",
            label: "Sessions",
        },
        MenuItem {
            path: "/exercises",
            label: "Exercises",
        },
    ];

    let location = use_location();

    view! {
        {menu_items
            .into_iter()
            .map(|item| {
                let is_active = move || location.pathname.get().eq(item.path);

                view! {
                    <A
                        href=item.path
                        attr:class=move || {
                            if is_active() { active_class } else { inactive_class }
                        }
                    >
                        {item.label}
                    </A>
                }
            })
            .collect::<Vec<_>>()}
    }
}
