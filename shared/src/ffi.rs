#[cfg(not(target_family = "wasm"))]
pub mod uniffi_ffi {
    use std::sync::Arc;

    use crux_core::{
        bridge::EffectId,
        macros::effect,
        middleware::{BincodeFfiFormat, Bridge, Layer as _},
        render::RenderOperation,
        Core,
    };
    use crux_http::protocol::HttpRequest;

    use crate::Chopin;

    #[effect]
    pub enum Effect {
        Render(RenderOperation),
        Http(HttpRequest),
    }

    impl From<crate::app::Effect> for Effect {
        fn from(effect: crate::app::Effect) -> Self {
            match effect {
                crate::Effect::Render(request) => Effect::Render(request),
                crate::Effect::Http(request) => Effect::Http(request),
            }
        }
    }

    /// For the Shell to provide
    #[uniffi::export(with_foreign)]
    pub trait CruxShell: Send + Sync {
        /// Called when any effects resulting from an asynchronous process
        /// need processing by the shell.
        ///
        /// The bytes are a serialized vector of requests
        fn process_effects(&self, bytes: Vec<u8>);
    }

    /// The main interface used by the shell
    #[derive(uniffi::Object)]
    pub struct CoreFFI {
        core: Bridge<Core<Chopin>, BincodeFfiFormat>,
    }

    #[uniffi::export]
    #[allow(clippy::missing_panics_doc)]
    impl CoreFFI {
        #[uniffi::constructor]
        pub fn new(shell: Arc<dyn CruxShell>) -> Self {
            let core = Core::<Chopin>::new().bridge::<BincodeFfiFormat>(move |effect_bytes| {
                match effect_bytes {
                    Ok(effect) => shell.process_effects(effect),
                    Err(e) => {
                        log::error!("FFI bridge error: {e}");
                        // Return empty effects instead of panicking
                        shell.process_effects(vec![]);
                    }
                }
            });

            Self { core }
        }

        #[must_use]
        pub fn update(&self, data: &[u8]) -> Vec<u8> {
            match self.core.update(data) {
                Ok(effects) => effects,
                Err(e) => {
                    log::error!("FFI update error: {e}");
                    // Return empty effects instead of panicking
                    vec![]
                }
            }
        }

        #[must_use]
        pub fn resolve(&self, effect_id: u32, data: &[u8]) -> Vec<u8> {
            match self.core.resolve(EffectId(effect_id), data) {
                Ok(effects) => effects,
                Err(e) => {
                    log::error!("FFI resolve error: {e}");
                    // Return empty effects instead of panicking
                    vec![]
                }
            }
        }

        #[must_use]
        pub fn view(&self) -> Vec<u8> {
            match self.core.view() {
                Ok(view) => view,
                Err(e) => {
                    log::error!("FFI view error: {e}");
                    // Return empty view instead of panicking
                    vec![]
                }
            }
        }
    }
}

#[cfg(target_family = "wasm")]
pub mod wasm_ffi {
    use crux_core::middleware::{BincodeFfiFormat, Layer as _};
    use crux_core::{bridge::EffectId, Core};

    use crate::Chopin;

    /// The main interface used by the shell
    #[wasm_bindgen::prelude::wasm_bindgen]
    pub struct CoreFFI {
        core: crux_core::middleware::Bridge<Core<Chopin>, BincodeFfiFormat>,
    }

    struct JsCallback(js_sys::Function);

    unsafe impl Send for JsCallback {}
    unsafe impl Sync for JsCallback {}

    impl std::ops::Deref for JsCallback {
        type Target = js_sys::Function;

        fn deref(&self) -> &Self::Target {
            &self.0
        }
    }

    #[wasm_bindgen::prelude::wasm_bindgen]
    impl CoreFFI {
        #[wasm_bindgen::prelude::wasm_bindgen(constructor)]
        pub fn new(callback: js_sys::Function) -> Self {
            use wasm_bindgen::JsValue;

            let callback = JsCallback(callback);
            let core = Core::<Chopin>::new().bridge::<BincodeFfiFormat>(move |effect_bytes| {
                match effect_bytes {
                    Ok(bytes) => {
                        if let Err(e) = callback.call1(&JsValue::NULL, &JsValue::from(bytes)) {
                            log::error!("Failed to call JS callback: {e:?}");
                        }
                    }
                    Err(e) => {
                        log::error!("WASM FFI bridge error: {e}");
                        // Continue execution instead of panicking
                    }
                }
            });

            Self { core }
        }

        pub fn update(&self, data: &[u8]) -> Vec<u8> {
            match self.core.update(data) {
                Ok(effects) => effects,
                Err(e) => {
                    log::error!("WASM FFI update error: {e}");
                    vec![]
                }
            }
        }

        pub fn resolve(&self, effect_id: u32, data: &[u8]) -> Vec<u8> {
            match self.core.resolve(EffectId(effect_id), data) {
                Ok(effects) => effects,
                Err(e) => {
                    log::error!("WASM FFI resolve error: {e}");
                    vec![]
                }
            }
        }

        pub fn view(&self) -> Vec<u8> {
            match self.core.view() {
                Ok(view) => view,
                Err(e) => {
                    log::error!("WASM FFI view error: {e}");
                    vec![]
                }
            }
        }
    }
}
