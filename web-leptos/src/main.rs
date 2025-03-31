use console_log;
use js_sys;
use leptos::prelude::*;
use leptos_meta::*;
use log::info;
use wasm_bindgen::prelude::*;
use web_sys::HtmlElement;

use shared::Event;

mod core;

use reactive_stores::Store;

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

           <header class="flex flex-wrap sm:justify-start sm:flex-nowrap w-full bg-gray-800 text-sm py-3 dark:bg-white">
      <nav class="max-w-[85rem] w-full mx-auto px-4 sm:flex sm:items-center sm:justify-between">

        <div class="flex items-center justify-between">
          <a class="flex-none text-xl font-semibold text-white focus:outline-hidden focus:opacity-80 dark:text-neutral-800" href="#">Brand</a>
          <div class="sm:hidden">
            <button type="button" class="hs-collapse-toggle relative size-9 flex justify-center items-center gap-2 rounded-lg border border-gray-700 font-medium bg-gray-800 text-gray-400 shadow-2xs align-middle hover:bg-gray-700/20 focus:outline-hidden focus:bg-gray-700/20 text-sm dark:bg-white dark:hover:bg-gray-100 dark:border-gray-200 dark:text-gray-600 dark:focus:bg-gray-100" id="hs-navbar-dark-collapse" aria-expanded="false" aria-controls="hs-navbar-dark" aria-label="Toggle navigation" data-hs-collapse="#hs-navbar-dark">
              <svg class="hs-collapse-open:hidden shrink-0 size-4" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" x2="21" y1="6" y2="6"/><line x1="3" x2="21" y1="12" y2="12"/><line x1="3" x2="21" y1="18" y2="18"/></svg>
              <svg class="hs-collapse-open:block hidden shrink-0 size-4" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
              <span class="sr-only">Toggle</span>
            </button>
          </div>
        </div>
        <div id="hs-navbar-dark" class="hidden hs-collapse overflow-hidden transition-all duration-300 basis-full grow sm:block" aria-labelledby="hs-navbar-dark-collapse">
          <div class="flex flex-col gap-5 mt-5 sm:flex-row sm:items-center sm:justify-end sm:mt-0 sm:ps-5">
            <a class="font-medium text-white focus:outline-hidden dark:text-black" href="#" aria-current="page">Landing</a>
            <a class="font-medium text-gray-400 hover:text-gray-500 focus:outline-hidden focus:text-gray-500 dark:text-neutral-500 dark:hover:text-neutral-400 dark:focus:text-neutral-400" href="#">Account</a>
            <a class="font-medium text-gray-400 hover:text-gray-500 focus:outline-hidden focus:text-gray-500 dark:text-neutral-500 dark:hover:text-neutral-400 dark:focus:text-neutral-400" href="#">Work</a>
            <a class="font-medium text-gray-400 hover:text-gray-500 focus:outline-hidden focus:text-gray-500 dark:text-neutral-500 dark:hover:text-neutral-400 dark:focus:text-neutral-400" href="#">Blog</a>
          </div>
        </div>
      </nav>
    </header>

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
