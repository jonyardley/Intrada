use console_log;
use leptos::prelude::*;
use leptos_meta::*;
use leptos_router::{
    components::{Route, Router, Routes},
    path,
};
use log::info;
use reactive_stores::Store;
use shared::Event;
use thaw::*;

mod components;
use crate::components::*;
mod core;
mod views;
use views::*;

#[derive(Clone, Default, Store)]
struct GlobalState {
    core: core::Core,
}

#[component]
pub fn App() -> impl IntoView {
    provide_meta_context();

    // Add dev data to the global state
    let global_state = GlobalState::default();
    global_state.core.process_event(Event::SetDevData());

    provide_context(Store::new(global_state));

    view! {
        <Html attr:lang="en" attr:dir="ltr" attr:data-theme="light" />

        // sets the document title
        <Title text="Practice App" />

        // injects metadata in the <head> of the page
        <Meta charset="UTF-8" />
        <Meta name="viewport" content="width=device-width, initial-scale=1.0" />

        <ConfigProvider>
            <Router>
                <Layout has_sider=true>
                    <LayoutSider attr:style="padding: 20px;">
                        <Nav />
                    </LayoutSider>
                    <Layout>
                        <LayoutHeader attr:style="padding-right: 20px;">
                            <Header />
                        </LayoutHeader>
                        <Layout attr:style="padding: 20px;">
                            <Routes fallback=|| "[404] - Oops, page not found.">
                                <Route path=path!("/") view=Home />
                                <Route path=path!("/goals") view=Goals />
                            </Routes>
                        </Layout>
                    </Layout>
                </Layout>
            </Router>
        </ConfigProvider>
    }
}

fn main() {
    console_error_panic_hook::set_once();
    console_log::init_with_level(log::Level::Info).expect("error initializing logger");
    info!("Application started");
    mount_to_body(App);
}
