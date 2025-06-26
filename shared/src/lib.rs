mod app;

mod ffi;

pub use crux_core::Core;
pub use crux_http as http;

pub use app::*;

#[cfg(not(target_family = "wasm"))]
const _: () = assert!(
    uniffi::check_compatible_version("0.29.3"),
    "please use uniffi v0.29.3"
);
#[cfg(not(target_family = "wasm"))]
uniffi::setup_scaffolding!();

#[cfg(not(target_family = "wasm"))]
pub use ffi::uniffi_ffi::CoreFFI;

#[cfg(target_family = "wasm")]
pub use ffi::wasm_ffi::CoreFFI;