// Intrada Web Application - Leptos Frontend
use leptos::prelude::*;
use leptos_meta::*;
use leptos_router::{
    components::{Route, Router, Routes},
    path,
};
use log::info;
use reactive_stores::Store;
use shared::Event;
use wasm_bindgen::JsCast;
use web_leptos::GlobalState;
use web_sys::HtmlElement;

mod components;
mod core;
mod hooks;
mod views;
use components::Nav;
use views::{CreateGoal, Goal, Goals, Home, Sessions, Studies};

#[component]
pub fn App() -> impl IntoView {
    // Provide MetaContext for title and meta tags
    provide_meta_context();

    let global_state = GlobalState::default();
    global_state.core.process_event(Event::FetchAll);
    provide_context(Store::new(global_state));

    view! {
        <Html attr:lang="en" attr:dir="ltr" attr:data-theme="light" />
        <Title text="Intrada" />
        <Meta charset="UTF-8" />
        <Meta name="viewport" content="width=device-width, initial-scale=1.0" />

        <div class="min-h-full">

            <Router>
                <Nav />
                <Routes fallback=|| view! { <div>"[404] - Oops, page not found."</div> }>
                    <Route path=path!("/") view=|| view! { <Home /> } />

                    // Goals
                    <Route path=path!("/goals") view=|| view! { <Goals /> } />
                    <Route path=path!("/goals/new") view=|| view! { <CreateGoal /> } />
                    <Route path=path!("/goals/:id") view=|| view! { <Goal /> } />

                    // Sessions
                    <Route path=path!("/sessions") view=|| view! { <Sessions /> } />

                    // Studies
                    <Route path=path!("/studies") view=|| view! { <Studies /> } />
                </Routes>
            </Router>
        </div>
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

// *************
// TESTS
// *************

// #[cfg(test)]
// mod tests {
//     // App component not tested in unit tests (requires WASM environment)
//     use shared::{DevEvent, Event, PracticeSession, SessionEvent, Study, StudyEvent};
//     use web_leptos::GlobalState;

//     #[test]
//     fn test_global_state_creation() {
//         let global_state = GlobalState::default();

//         // Test that the global state is created successfully
//         let view_model = global_state.core.view();
//         assert!(view_model.goals.is_empty());
//         assert!(view_model.studies.is_empty());
//         assert!(view_model.sessions.is_empty());
//     }

//     #[test]
//     fn test_dev_data_processing() {
//         let global_state = GlobalState::default();
//         global_state
//             .core
//             .process_event(Event::Dev(DevEvent::SetDevData));

//         // After setting dev data, should have some content
//         let view_model = global_state.core.view();
//         assert!(!view_model.goals.is_empty());
//         assert!(!view_model.studies.is_empty());
//     }

//     #[test]
//     fn test_event_processing() {
//         let global_state = GlobalState::default();

//         // Test that Nothing event can be processed
//         let effects = global_state
//             .core
//             .process_event(Event::Dev(DevEvent::Nothing));
//         assert!(!effects.is_empty());
//     }

//     #[test]
//     fn test_session_creation_event() {
//         let global_state = GlobalState::default();

//         let new_session =
//             PracticeSession::new(vec!["goal1".to_string()], "Test session".to_string());

//         let effects = global_state
//             .core
//             .process_event(Event::Session(SessionEvent::AddSession(
//                 new_session.clone(),
//             )));
//         assert!(!effects.is_empty());

//         // Check that the session was added
//         let view_model = global_state.core.view();
//         assert!(view_model.sessions.iter().any(|s| s.id == new_session.id()));
//     }

//     #[test]
//     fn test_study_creation_event() {
//         let global_state = GlobalState::default();

//         let new_study = Study {
//             id: "test-study".to_string(),
//             name: "Test Study".to_string(),
//             description: Some("Test description".to_string()),
//         };

//         let effects = global_state
//             .core
//             .process_event(Event::Study(StudyEvent::AddStudy(new_study.clone())));
//         assert!(!effects.is_empty());

//         // Check that the study was added
//         let view_model = global_state.core.view();
//         assert!(view_model.studies.iter().any(|s| s.id == new_study.id));
//     }

//     // Note: App component test removed because it requires WASM environment
//     // The App component is tested in the browser environment instead

//     #[test]
//     fn test_route_paths() {
//         // Test that our route paths are valid strings
//         let home_path = "/";
//         let goals_path = "/goals";
//         let new_goal_path = "/goals/new";
//         let sessions_path = "/sessions";
//         let studies_path = "/studies";

//         assert_eq!(home_path, "/");
//         assert_eq!(goals_path, "/goals");
//         assert_eq!(new_goal_path, "/goals/new");
//         assert_eq!(sessions_path, "/sessions");
//         assert_eq!(studies_path, "/studies");
//     }
// }
