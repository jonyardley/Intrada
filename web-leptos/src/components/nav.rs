use leptos::prelude::*;
use leptos_router::components::A;

#[component]
pub fn Nav() -> impl IntoView {
    view! {
        <nav class="max-w-[85rem] w-full mx-auto px-4 sm:flex sm:items-center sm:justify-between">

            <div class="flex items-center justify-between">
                <A
                    href="/"
                    attr:class="flex-none text-xl font-semibold text-white focus:outline-hidden focus:opacity-80 dark:text-neutral-800"
                >
                    "Practice App"
                </A>
                <div class="sm:hidden">
                    <button
                        type="button"
                        class="hs-collapse-toggle relative size-9 flex justify-center items-center gap-2 rounded-lg border border-gray-700 font-medium bg-gray-800 text-gray-400 shadow-2xs align-middle hover:bg-gray-700/20 focus:outline-hidden focus:bg-gray-700/20 text-sm dark:bg-white dark:hover:bg-gray-100 dark:border-gray-200 dark:text-gray-600 dark:focus:bg-gray-100"
                        id="hs-navbar-dark-collapse"
                        aria-expanded="false"
                        aria-controls="hs-navbar-dark"
                        aria-label="Toggle navigation"
                        data-hs-collapse="#hs-navbar-dark"
                    >
                        <svg
                            class="hs-collapse-open:hidden shrink-0 size-4"
                            xmlns="http://www.w3.org/2000/svg"
                            width="24"
                            height="24"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                        >
                            <line x1="3" x2="21" y1="6" y2="6" />
                            <line x1="3" x2="21" y1="12" y2="12" />
                            <line x1="3" x2="21" y1="18" y2="18" />
                        </svg>
                        <svg
                            class="hs-collapse-open:block hidden shrink-0 size-4"
                            xmlns="http://www.w3.org/2000/svg"
                            width="24"
                            height="24"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                        >
                            <path d="M18 6 6 18" />
                            <path d="m6 6 12 12" />
                        </svg>
                        <span class="sr-only">Toggle</span>
                    </button>
                </div>
            </div>
            <div
                id="hs-navbar-dark"
                class="hidden hs-collapse overflow-hidden transition-all duration-300 basis-full grow sm:block"
                aria-labelledby="hs-navbar-dark-collapse"
            >
                <MenuItems />
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
pub fn MenuItems() -> impl IntoView {
    let active_class = "font-medium text-white focus:outline-hidden dark:text-black";
    let inactive_class = "font-medium text-gray-400 hover:text-gray-500 focus:outline-hidden focus:text-gray-500 dark:text-neutral-500 dark:hover:text-neutral-400 dark:focus:text-neutral-400";

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

    view! {
        <div class="flex flex-col gap-5 mt-5 sm:flex-row sm:items-center sm:justify-end sm:mt-0 sm:ps-5">
            {menu_items
                .into_iter()
                .map(|item| {
                    // TODO: Add active class to the active item
                    view! {
                        <A href=item.path attr:class=inactive_class attr:class:active=active_class>
                            {item.label}
                        </A>
                    }
                })
                .collect::<Vec<_>>()}
        </div>
    }
}
