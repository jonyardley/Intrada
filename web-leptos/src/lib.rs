use reactive_stores::Store;

pub mod components;
pub mod core;
pub mod hooks;
pub mod views;

#[derive(Clone, Default, Store)]
pub struct GlobalState {
    pub core: core::Core,
}

// *************
// TESTS
// *************

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use shared::Event;

//     #[test]
//     fn test_global_state_default() {
//         let state = GlobalState::default();

//         // Test that the default state is created successfully
//         let view_model = state.core.view();
//         assert!(view_model.goals.is_empty());
//         assert!(view_model.studies.is_empty());
//         assert!(view_model.sessions.is_empty());
//     }

//     #[test]
//     fn test_global_state_clone() {
//         let state1 = GlobalState::default();
//         let state2 = state1.clone();

//         // Both states should have the same initial structure
//         let view1 = state1.core.view();
//         let view2 = state2.core.view();

//         assert_eq!(view1.goals.len(), view2.goals.len());
//         assert_eq!(view1.studies.len(), view2.studies.len());
//         assert_eq!(view1.sessions.len(), view2.sessions.len());
//     }

//     #[test]
//     fn test_global_state_core_access() {
//         let state = GlobalState::default();

//         // Test that we can access the core and process events
//         let effects = state.core.process_event(Event::FetchAll);
//         assert!(!effects.is_empty());
//     }

//     #[test]
//     fn test_global_state_with_dev_data() {
//         let state = GlobalState::default();
//         state.core.process_event(Event::FetchAll);

//         // After setting dev data, should have some content
//         let view_model = state.core.view();
//         assert!(!view_model.goals.is_empty());
//     }

//     #[test]
//     fn test_store_derive_implementation() {
//         // Test that GlobalState has the Store derive macro
//         let state = GlobalState::default();

//         // This is a compile-time test - if it compiles, the Store derive is working
//         let cloned_state = state.clone();

//         // Verify that the cloned state has the same structure
//         assert_eq!(
//             state.core.view().goals.len(),
//             cloned_state.core.view().goals.len()
//         );
//     }
// }
