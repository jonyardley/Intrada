use crux_core::{
    bridge::{Bridge, EffectId},
    Core,
};

use crate::{page_outline, Intrada};

// Returned (not panicked) so the shell handles it per the no-`try!` contract —
// the crux `counter` example panics but says to do this in production.
#[cfg_attr(feature = "uniffi", derive(uniffi::Error))]
#[derive(Debug, thiserror::Error)]
pub enum CoreError {
    #[error("core bridge error: {0}")]
    Bridge(String),
}

#[cfg_attr(feature = "uniffi", derive(uniffi::Object))]
pub struct CoreFFI {
    core: Bridge<Intrada>,
}

impl Default for CoreFFI {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg_attr(feature = "uniffi", uniffi::export)]
impl CoreFFI {
    #[cfg_attr(feature = "uniffi", uniffi::constructor)]
    #[must_use]
    pub fn new() -> Self {
        Self {
            core: Bridge::new(Core::new()),
        }
    }

    pub fn update(&self, data: &[u8]) -> Result<Vec<u8>, CoreError> {
        let mut effects = Vec::new();
        self.core
            .update(data, &mut effects)
            .map_err(|e| CoreError::Bridge(e.to_string()))?;
        Ok(effects)
    }

    pub fn resolve(&self, id: u32, data: &[u8]) -> Result<Vec<u8>, CoreError> {
        let mut effects = Vec::new();
        self.core
            .resolve(EffectId(id), data, &mut effects)
            .map_err(|e| CoreError::Bridge(e.to_string()))?;
        Ok(effects)
    }

    pub fn view(&self) -> Result<Vec<u8>, CoreError> {
        let mut view = Vec::new();
        self.core
            .view(&mut view)
            .map_err(|e| CoreError::Bridge(e.to_string()))?;
        Ok(view)
    }
}

// ── Page outline ──

#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
#[derive(Debug, Clone, Copy)]
pub struct Corner {
    pub x: f64,
    pub y: f64,
}

/// Frame size is the upright pixel buffer Vision was given, not the image's
/// display size: a rotated photo transposes the two and every angle is wrong.
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
#[derive(Debug, Clone, Copy)]
pub struct PageOutline {
    pub top_left: Corner,
    pub top_right: Corner,
    pub bottom_left: Corner,
    pub bottom_right: Corner,
    pub frame_width: f64,
    pub frame_height: f64,
}

#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PageOutlineFault {
    CornerOnFrameEdge,
    EdgesNotParallel,
    Collapsed,
}

impl From<Corner> for page_outline::Corner {
    fn from(c: Corner) -> Self {
        Self { x: c.x, y: c.y }
    }
}

impl From<page_outline::OutlineFault> for PageOutlineFault {
    fn from(fault: page_outline::OutlineFault) -> Self {
        match fault {
            page_outline::OutlineFault::CornerOnFrameEdge => Self::CornerOnFrameEdge,
            page_outline::OutlineFault::EdgesNotParallel => Self::EdgesNotParallel,
            page_outline::OutlineFault::Collapsed => Self::Collapsed,
        }
    }
}

/// The crop runs in a detached task before the store sees the photo, so this
/// is a plain call rather than an Event round trip (#1565).
#[cfg_attr(feature = "uniffi", uniffi::export)]
#[must_use]
pub fn page_outline_fault(outline: PageOutline) -> Option<PageOutlineFault> {
    page_outline::fault(&page_outline::PageOutline {
        top_left: outline.top_left.into(),
        top_right: outline.top_right.into(),
        bottom_left: outline.bottom_left.into(),
        bottom_right: outline.bottom_right.into(),
        frame_width: outline.frame_width,
        frame_height: outline.frame_height,
    })
    .map(Into::into)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Swapping x with y, width with height, or any two corners in the mapping
    // changes this answer: the skew only crosses the limit in this aspect ratio.
    #[test]
    fn mirror_types_map_every_field_onto_the_core_outline() {
        let corner = |x, y| Corner { x, y };
        let keystoned = PageOutline {
            top_left: corner(0.12, 0.9),
            top_right: corner(0.88, 0.9),
            bottom_left: corner(0.05, 0.1),
            bottom_right: corner(0.95, 0.1),
            frame_width: 4032.0,
            frame_height: 500.0,
        };
        assert_eq!(
            page_outline_fault(keystoned),
            Some(PageOutlineFault::EdgesNotParallel)
        );
        let upright = PageOutline {
            frame_width: 3024.0,
            frame_height: 4032.0,
            ..keystoned
        };
        assert_eq!(page_outline_fault(upright), None);
    }

    #[test]
    fn bridge_serializes_initial_view() {
        let core = CoreFFI::new();
        let view = core.view().expect("initial view should serialize");
        assert!(!view.is_empty(), "serialized ViewModel should be non-empty");
    }
}
