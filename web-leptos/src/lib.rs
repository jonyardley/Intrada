use reactive_stores::Store;

pub mod components;
pub mod core;
pub mod hooks;
pub mod views;

#[derive(Clone, Default, Store)]
pub struct GlobalState {
    pub core: core::Core,
}
