use crate::core;
use reactive_stores::Store;

#[derive(Clone, Default, Store)]
pub struct GlobalState {
    pub core: core::Core,
}
