use crux_core::{
    bridge::{Bridge, EffectId},
    Core,
};

use crate::{page_outline, Intrada, LibrarySort, SortDirection, SortField};

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

// ── Picker candidates ──

/// A small, flat type crossing the plain FFI boundary, not the full
/// `LibraryItemView`, so this shape stays stable regardless of what fields
/// the view gains (#1653).
#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
#[derive(Debug, Clone)]
pub struct PickerCandidateArg {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub notes: Option<String>,
    pub tags: Vec<String>,
    pub created_at: String,
    pub last_practiced_at: Option<String>,
}

impl From<PickerCandidateArg> for crate::app::PickerCandidate {
    fn from(c: PickerCandidateArg) -> Self {
        Self {
            id: c.id,
            title: c.title,
            subtitle: c.subtitle,
            notes: c.notes,
            tags: c.tags,
            created_at: c.created_at,
            last_practiced_at: c.last_practiced_at,
        }
    }
}

/// Core stays UniFFI-agnostic (CLAUDE.md), so `SortField` (which carries
/// `facet::Facet` for the crux typegen path, a separate derive system) needs
/// its own copy at this plain-call boundary.
#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PickerSortField {
    DateAdded,
    LastPracticed,
    Title,
}

impl From<PickerSortField> for SortField {
    fn from(field: PickerSortField) -> Self {
        match field {
            PickerSortField::DateAdded => Self::DateAdded,
            PickerSortField::LastPracticed => Self::LastPracticed,
            PickerSortField::Title => Self::Title,
        }
    }
}

/// Exhaustive over `SortField`, so a variant added there without a matching
/// arm here is a compile error, not a silently unreachable picker option.
impl From<SortField> for PickerSortField {
    fn from(field: SortField) -> Self {
        match field {
            SortField::DateAdded => Self::DateAdded,
            SortField::LastPracticed => Self::LastPracticed,
            SortField::Title => Self::Title,
        }
    }
}

#[cfg_attr(feature = "uniffi", derive(uniffi::Enum))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PickerSortDirection {
    Ascending,
    Descending,
}

impl From<PickerSortDirection> for SortDirection {
    fn from(direction: PickerSortDirection) -> Self {
        match direction {
            PickerSortDirection::Ascending => Self::Ascending,
            PickerSortDirection::Descending => Self::Descending,
        }
    }
}

impl From<SortDirection> for PickerSortDirection {
    fn from(direction: SortDirection) -> Self {
        match direction {
            SortDirection::Ascending => Self::Ascending,
            SortDirection::Descending => Self::Descending,
        }
    }
}

#[cfg_attr(feature = "uniffi", derive(uniffi::Record))]
#[derive(Debug, Clone, Copy)]
pub struct PickerSortArg {
    pub field: PickerSortField,
    pub direction: PickerSortDirection,
}

impl From<PickerSortArg> for LibrarySort {
    fn from(sort: PickerSortArg) -> Self {
        Self {
            field: sort.field.into(),
            direction: sort.direction.into(),
        }
    }
}

/// The picker sheet's own sort and search (#1653): a plain call, not an
/// `Event` round trip, since it runs on every keystroke and must not disturb
/// the Library screen's own `ListQuery` state. See
/// `intrada_core::app::sort_and_filter_candidates` for the shared comparator
/// and search predicate this calls into. Returns candidate ids in filtered,
/// sorted order; the shell reorders its own list by them.
#[cfg_attr(feature = "uniffi", uniffi::export)]
#[must_use]
pub fn sort_and_filter_picker_candidates(
    candidates: Vec<PickerCandidateArg>,
    sort: PickerSortArg,
    search: String,
) -> Vec<String> {
    let candidates: Vec<crate::app::PickerCandidate> =
        candidates.into_iter().map(Into::into).collect();
    crate::app::sort_and_filter_candidates(&candidates, &sort.into(), &search)
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

    /// Exercises the FFI-side duplicate types a caller actually constructs,
    /// not the core types directly.
    #[test]
    fn sort_and_filter_picker_candidates_round_trips_through_the_ffi_types() {
        let candidates = vec![
            PickerCandidateArg {
                id: "p1".to_string(),
                title: "Clair de Lune".to_string(),
                subtitle: "Debussy".to_string(),
                notes: None,
                tags: vec![],
                created_at: "2026-01-01".to_string(),
                last_practiced_at: None,
            },
            PickerCandidateArg {
                id: "p2".to_string(),
                title: "Ballade".to_string(),
                subtitle: "Chopin".to_string(),
                notes: None,
                tags: vec![],
                created_at: "2026-01-02".to_string(),
                last_practiced_at: None,
            },
        ];
        let sort = PickerSortArg {
            field: PickerSortField::Title,
            direction: PickerSortDirection::Ascending,
        };

        let ids = sort_and_filter_picker_candidates(candidates, sort, String::new());

        assert_eq!(
            ids,
            vec!["p2", "p1"],
            "ascending title order across the FFI boundary"
        );
    }

    #[test]
    fn sort_and_filter_picker_candidates_filters_by_search() {
        let candidates = vec![PickerCandidateArg {
            id: "p1".to_string(),
            title: "Clair de Lune".to_string(),
            subtitle: "Debussy".to_string(),
            notes: None,
            tags: vec![],
            created_at: "2026-01-01".to_string(),
            last_practiced_at: None,
        }];
        let sort = PickerSortArg {
            field: PickerSortField::Title,
            direction: PickerSortDirection::Ascending,
        };

        let ids = sort_and_filter_picker_candidates(candidates, sort, "nonexistent".to_string());

        assert!(ids.is_empty());
    }

    /// Every `PickerSortField` and `PickerSortDirection` combination, driven
    /// through the core enums and the reverse `From` conversions, so a
    /// transposed arm in either `From` table is caught rather than surviving
    /// on `Title`/`Ascending` alone.
    #[test]
    fn sort_and_filter_picker_candidates_covers_every_field_and_direction() {
        let candidates = vec![
            PickerCandidateArg {
                id: "a".to_string(),
                title: "Bravo".to_string(),
                subtitle: String::new(),
                notes: None,
                tags: vec![],
                created_at: "2026-01-03".to_string(),
                last_practiced_at: Some("2026-02-02".to_string()),
            },
            PickerCandidateArg {
                id: "b".to_string(),
                title: "Alpha".to_string(),
                subtitle: String::new(),
                notes: None,
                tags: vec![],
                created_at: "2026-01-01".to_string(),
                last_practiced_at: Some("2026-02-03".to_string()),
            },
            PickerCandidateArg {
                id: "c".to_string(),
                title: "Charlie".to_string(),
                subtitle: String::new(),
                notes: None,
                tags: vec![],
                created_at: "2026-01-02".to_string(),
                last_practiced_at: Some("2026-02-01".to_string()),
            },
        ];

        let cases: [(SortField, SortDirection, [&str; 3]); 6] = [
            (
                SortField::DateAdded,
                SortDirection::Ascending,
                ["b", "c", "a"],
            ),
            (
                SortField::DateAdded,
                SortDirection::Descending,
                ["a", "c", "b"],
            ),
            (SortField::Title, SortDirection::Ascending, ["b", "a", "c"]),
            (SortField::Title, SortDirection::Descending, ["c", "a", "b"]),
            (
                SortField::LastPracticed,
                SortDirection::Ascending,
                ["c", "a", "b"],
            ),
            (
                SortField::LastPracticed,
                SortDirection::Descending,
                ["b", "a", "c"],
            ),
        ];

        for (field, direction, expected) in cases {
            let sort = PickerSortArg {
                field: field.into(),
                direction: direction.into(),
            };
            let ids = sort_and_filter_picker_candidates(candidates.clone(), sort, String::new());
            assert_eq!(
                ids, expected,
                "field {field:?} direction {direction:?} should order {expected:?}"
            );
        }
    }
}
