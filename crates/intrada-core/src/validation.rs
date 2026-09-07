use crate::domain::item::ItemKind;
use crate::domain::types::{CreateItem, Tempo, UpdateItem};
use crate::error::LibraryError;
use crate::model::Model;

/// Validation limits shared across shells (web, CLI).
pub const MAX_TITLE: usize = 500;
pub const MAX_COMPOSER: usize = 200;
pub const MAX_NOTES: usize = 5000;
pub const MAX_REFLECTION: usize = 500;
pub const MAX_INTENTION: usize = 500;
pub const MAX_TAG: usize = 100;
pub const MAX_TEMPO_MARKING: usize = 100;
pub const MIN_BPM: u16 = 1;
pub const MAX_BPM: u16 = 400;
pub const MIN_SCORE: u8 = 1;
pub const MAX_SCORE: u8 = 10;
// Equal to MAX on purpose: the stepper exists to ask for fewer passes, never more.
pub const DEFAULT_REP_TARGET: u8 = 10;
pub const MIN_REP_TARGET: u8 = 3;
pub const MAX_REP_TARGET: u8 = 10;
pub const MAX_REP_HISTORY: usize = 500;
pub const MAX_SET_NAME: usize = 200;
pub const MAX_VARIANT_LABEL: usize = 100;
pub const MAX_VARIANTS: usize = 24;
pub const MIN_PLANNED_DURATION_SECS: u32 = 60;
pub const MAX_PLANNED_DURATION_SECS: u32 = 3600;
pub const MIN_SESSION_TARGET_MINS: u32 = 5;
pub const MAX_SESSION_TARGET_MINS: u32 = 120;
pub const MIN_ACHIEVED_TEMPO: u16 = 1;
pub const MAX_ACHIEVED_TEMPO: u16 = 500;
pub const MIN_METRE_BEATS: u8 = 2;
pub const MAX_METRE_BEATS: u8 = 12;
pub const METRE_UNITS: [u8; 3] = [2, 4, 8];

// ── Normalisation ──
// Trim free-text on input and collapse a now-blank value to absent, so a
// whitespace-only field behaves exactly like an empty one through validation
// and storage (#883). Runs before validate_*, so "   " fails "required" just
// like "" rather than persisting as stored whitespace.

fn trimmed_nonempty(value: Option<String>) -> Option<String> {
    value
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
}

fn normalize_tags(tags: Vec<String>) -> Vec<String> {
    // Case-insensitive dedupe keeping first-seen casing, matching the AddTags
    // handler's case-fold and the available_tags vocabulary — so create/update
    // can't store "Jazz" + "jazz" as two tags.
    let mut seen = std::collections::HashSet::new();
    tags.into_iter()
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
        .filter(|t| seen.insert(t.to_lowercase()))
        .collect()
}

fn normalize_tempo(tempo: Option<Tempo>) -> Option<Tempo> {
    tempo.and_then(|t| Tempo::from_parts(trimmed_nonempty(t.marking), t.bpm))
}

pub fn normalize_create_item(mut input: CreateItem) -> CreateItem {
    input.title = input.title.trim().to_string();
    input.composer = trimmed_nonempty(input.composer);
    input.key = trimmed_nonempty(input.key);
    input.notes = trimmed_nonempty(input.notes);
    input.tempo = normalize_tempo(input.tempo);
    input.tags = normalize_tags(input.tags);
    input
}

pub fn normalize_update_item(mut input: UpdateItem) -> UpdateItem {
    input.title = input.title.map(|t| t.trim().to_string());
    input.composer = input.composer.map(trimmed_nonempty);
    input.key = input.key.map(trimmed_nonempty);
    input.notes = input.notes.map(trimmed_nonempty);
    input.tempo = input.tempo.map(normalize_tempo);
    input.tags = input.tags.map(normalize_tags);
    input
}

pub fn validate_title(title: &str) -> Result<(), LibraryError> {
    if title.is_empty() || title.len() > MAX_TITLE {
        return Err(LibraryError::Validation {
            field: "title".to_string(),
            message: format!("Title must be between 1 and {MAX_TITLE} characters"),
        });
    }
    Ok(())
}

pub fn validate_create_item(input: &CreateItem) -> Result<(), LibraryError> {
    validate_title(&input.title)?;
    if let Some(photo_id) = input.photo_id.as_deref() {
        validate_photo_id(photo_id)?;
    }
    // Composer is required for pieces, optional for exercises.
    match input.kind {
        ItemKind::Piece => {
            let composer = input.composer.as_deref().unwrap_or("");
            if composer.is_empty() {
                return Err(LibraryError::Validation {
                    field: "composer".to_string(),
                    message: "Composer is required".to_string(),
                });
            }
            if composer.len() > MAX_COMPOSER {
                return Err(LibraryError::Validation {
                    field: "composer".to_string(),
                    message: format!("Composer must be between 1 and {MAX_COMPOSER} characters"),
                });
            }
        }
        ItemKind::Exercise => {
            if let Some(ref composer) = input.composer {
                if composer.is_empty() || composer.len() > MAX_COMPOSER {
                    return Err(LibraryError::Validation {
                        field: "composer".to_string(),
                        message: format!(
                            "Composer must be between 1 and {MAX_COMPOSER} characters"
                        ),
                    });
                }
            }
        }
    }
    if let Some(ref notes) = input.notes {
        if notes.len() > MAX_NOTES {
            return Err(LibraryError::Validation {
                field: "notes".to_string(),
                message: format!("Notes must not exceed {MAX_NOTES} characters"),
            });
        }
    }
    validate_tags(&input.tags)?;
    if let Some(ref tempo) = input.tempo {
        validate_tempo(tempo)?;
    }
    Ok(())
}

pub fn validate_update_item(input: &UpdateItem) -> Result<(), LibraryError> {
    if let Some(ref title) = input.title {
        validate_title(title)?;
    }
    if let Some(Some(ref composer)) = input.composer {
        if composer.is_empty() || composer.len() > MAX_COMPOSER {
            return Err(LibraryError::Validation {
                field: "composer".to_string(),
                message: format!("Composer must be between 1 and {MAX_COMPOSER} characters"),
            });
        }
    }
    if let Some(Some(ref notes)) = input.notes {
        if notes.len() > MAX_NOTES {
            return Err(LibraryError::Validation {
                field: "notes".to_string(),
                message: format!("Notes must not exceed {MAX_NOTES} characters"),
            });
        }
    }
    if let Some(ref tags) = input.tags {
        validate_tags(tags)?;
    }
    if let Some(Some(ref tempo)) = input.tempo {
        validate_tempo(tempo)?;
    }
    Ok(())
}

pub fn validate_session_notes(notes: &Option<String>) -> Result<(), LibraryError> {
    if let Some(ref n) = notes {
        if n.len() > MAX_NOTES {
            return Err(LibraryError::Validation {
                field: "session_notes".to_string(),
                message: format!("Practice notes must not exceed {MAX_NOTES} characters"),
            });
        }
    }
    Ok(())
}

pub fn validate_reflection(text: &Option<String>) -> Result<(), LibraryError> {
    if let Some(ref t) = text {
        if t.len() > MAX_REFLECTION {
            return Err(LibraryError::Validation {
                field: "reflection".to_string(),
                message: format!("A reflection must not exceed {MAX_REFLECTION} characters"),
            });
        }
    }
    Ok(())
}

pub fn validate_entry_notes(notes: &Option<String>) -> Result<(), LibraryError> {
    if let Some(ref n) = notes {
        if n.len() > MAX_NOTES {
            return Err(LibraryError::Validation {
                field: "notes".to_string(),
                message: format!("Notes must not exceed {MAX_NOTES} characters"),
            });
        }
    }
    Ok(())
}

pub fn validate_entries_not_empty<T>(entries: &[T], context: &str) -> Result<(), LibraryError> {
    if entries.is_empty() {
        return Err(LibraryError::Validation {
            field: "entries".to_string(),
            message: format!("{context} must have at least one entry"),
        });
    }
    Ok(())
}

pub fn validate_tags(tags: &[String]) -> Result<(), LibraryError> {
    for tag in tags {
        if tag.is_empty() || tag.len() > MAX_TAG {
            return Err(LibraryError::Validation {
                field: "tags".to_string(),
                message: format!("Each tag must be between 1 and {MAX_TAG} characters"),
            });
        }
    }
    Ok(())
}

pub fn validate_intention(intention: &Option<String>) -> Result<(), LibraryError> {
    if let Some(ref text) = intention {
        if text.len() > MAX_INTENTION {
            return Err(LibraryError::Validation {
                field: "intention".to_string(),
                message: format!("Intention must not exceed {MAX_INTENTION} characters"),
            });
        }
    }
    Ok(())
}

pub fn validate_score(score: &Option<u8>) -> Result<(), LibraryError> {
    if let Some(s) = score {
        if !(MIN_SCORE..=MAX_SCORE).contains(s) {
            return Err(LibraryError::Validation {
                field: "score".to_string(),
                message: format!("Score must be between {MIN_SCORE} and {MAX_SCORE}"),
            });
        }
    }
    Ok(())
}

pub fn validate_rep_target(rep_target: &Option<u8>) -> Result<(), LibraryError> {
    if let Some(t) = rep_target {
        if !(MIN_REP_TARGET..=MAX_REP_TARGET).contains(t) {
            return Err(LibraryError::Validation {
                field: "rep_target".to_string(),
                message: format!(
                    "Rep target must be between {MIN_REP_TARGET} and {MAX_REP_TARGET}"
                ),
            });
        }
    }
    Ok(())
}

pub fn validate_planned_duration(planned_duration_secs: &Option<u32>) -> Result<(), LibraryError> {
    if let Some(d) = planned_duration_secs {
        if !(MIN_PLANNED_DURATION_SECS..=MAX_PLANNED_DURATION_SECS).contains(d) {
            return Err(LibraryError::Validation {
                field: "planned_duration_secs".to_string(),
                message: format!(
                    "Planned duration must be between {MIN_PLANNED_DURATION_SECS} and {MAX_PLANNED_DURATION_SECS} seconds"
                ),
            });
        }
    }
    Ok(())
}

pub fn validate_achieved_tempo(tempo: &Option<u16>) -> Result<(), LibraryError> {
    if let Some(t) = tempo {
        if !(MIN_ACHIEVED_TEMPO..=MAX_ACHIEVED_TEMPO).contains(t) {
            return Err(LibraryError::Validation {
                field: "achieved_tempo".to_string(),
                message: format!(
                    "Achieved tempo must be between {MIN_ACHIEVED_TEMPO} and {MAX_ACHIEVED_TEMPO} BPM"
                ),
            });
        }
    }
    Ok(())
}

pub fn validate_tempo(tempo: &Tempo) -> Result<(), LibraryError> {
    if tempo.marking.is_none() && tempo.bpm.is_none() {
        return Err(LibraryError::Validation {
            field: "tempo".to_string(),
            message: "Tempo must have at least a marking or BPM value".to_string(),
        });
    }
    if let Some(ref marking) = tempo.marking {
        if marking.len() > MAX_TEMPO_MARKING {
            return Err(LibraryError::Validation {
                field: "tempo".to_string(),
                message: format!("Tempo marking must not exceed {MAX_TEMPO_MARKING} characters"),
            });
        }
    }
    if let Some(bpm) = tempo.bpm {
        if !(MIN_BPM..=MAX_BPM).contains(&bpm) {
            return Err(LibraryError::Validation {
                field: "tempo".to_string(),
                message: format!("BPM must be between {MIN_BPM} and {MAX_BPM}"),
            });
        }
    }
    Ok(())
}

pub fn validate_set_name(name: &str) -> Result<(), LibraryError> {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        return Err(LibraryError::Validation {
            field: "name".to_string(),
            message: "Set name is required".to_string(),
        });
    }
    if trimmed.len() > MAX_SET_NAME {
        return Err(LibraryError::Validation {
            field: "name".to_string(),
            message: format!("Set name must not exceed {MAX_SET_NAME} characters"),
        });
    }
    Ok(())
}

/// Validate rep field consistency: rep_count must be <= rep_target, and
/// rep_count, rep_target_reached, and rep_history all require rep_target.
pub fn validate_rep_consistency(
    rep_target: Option<u8>,
    rep_count: Option<u8>,
    rep_target_reached: Option<bool>,
    rep_history_present: bool,
) -> Result<(), LibraryError> {
    if let Some(target) = rep_target {
        if let Some(count) = rep_count {
            if count > target {
                return Err(LibraryError::Validation {
                    field: "rep_count".to_string(),
                    message: format!("rep_count ({count}) cannot exceed rep_target ({target})"),
                });
            }
        }
    } else {
        // No target ⇒ count, reached, and history must also be absent.
        if rep_count.is_some() || rep_target_reached.is_some() || rep_history_present {
            return Err(LibraryError::Validation {
                field: "rep_target".to_string(),
                message: "rep_count, rep_target_reached, and rep_history require rep_target"
                    .to_string(),
            });
        }
    }
    Ok(())
}

/// A photo id becomes a path component in the shell, so a value that is not a
/// ulid is a traversal out of the app container (`specs/piece-from-photo.md`).
/// The core is the only layer that can refuse it before it is stored.
pub fn validate_photo_id(photo_id: &str) -> Result<(), LibraryError> {
    if ulid::Ulid::from_string(photo_id).is_err() {
        return Err(LibraryError::Validation {
            field: "photo_id".to_string(),
            message: "That photo could not be saved".to_string(),
        });
    }
    Ok(())
}

pub fn validate_metre(metre: &crate::domain::Metre) -> Result<(), LibraryError> {
    let invalid = |message: String| LibraryError::Validation {
        field: "metre".to_string(),
        message,
    };
    if !(MIN_METRE_BEATS..=MAX_METRE_BEATS).contains(&metre.beats) {
        return Err(invalid(format!(
            "Beats in the bar must be between {MIN_METRE_BEATS} and {MAX_METRE_BEATS}"
        )));
    }
    if !METRE_UNITS.contains(&metre.unit) {
        return Err(invalid(
            "The beat must be a minim, crotchet or quaver".to_string(),
        ));
    }
    if let Some(groups) = &metre.groups {
        let sum: u32 = groups.iter().map(|&g| u32::from(g)).sum();
        if groups.is_empty() || groups.contains(&0) || sum != u32::from(metre.beats) {
            return Err(invalid(
                "The grouping must add up to the beats in the bar".to_string(),
            ));
        }
    }
    Ok(())
}

/// A click state is a valid metre plus at least one sounding beat inside it.
pub fn validate_click_state(
    state: &crate::domain::session::ClickState,
) -> Result<(), LibraryError> {
    validate_metre(&state.metre)?;
    let in_bar: u16 = (1u16 << state.metre.beats) - 1;
    if state.sounding == 0 || state.sounding & !in_bar != 0 {
        return Err(LibraryError::Validation {
            field: "click".to_string(),
            message: "The click must sound on at least one beat of the bar".to_string(),
        });
    }
    Ok(())
}

/// The host half of `validate_link_exercise`: the id names an item that exists
/// and is a piece. Shared with `AddLinkedExercise`, where the exercise does not
/// exist yet and so only this half can run.
pub fn validate_piece_host(piece_id: &str, model: &Model) -> Result<(), LibraryError> {
    let piece = model
        .items
        .iter()
        .find(|i| i.id == piece_id)
        .ok_or_else(|| LibraryError::NotFound {
            id: piece_id.to_string(),
        })?;

    if piece.kind != ItemKind::Piece {
        return Err(LibraryError::Validation {
            field: "piece_id".to_string(),
            message: "Target must be a piece, not an exercise".to_string(),
        });
    }

    Ok(())
}

/// The linked half of `validate_link_exercise`: the id names an item that
/// exists and is an exercise. Shared with `AddPieceInFull`, where the host
/// piece does not exist yet and so only this half can run.
pub fn validate_exercise_link_target(exercise_id: &str, model: &Model) -> Result<(), LibraryError> {
    let exercise = model
        .items
        .iter()
        .find(|i| i.id == exercise_id)
        .ok_or_else(|| LibraryError::NotFound {
            id: exercise_id.to_string(),
        })?;

    if exercise.kind != ItemKind::Exercise {
        return Err(LibraryError::Validation {
            field: "exercise_id".to_string(),
            message: "Linked item must be an exercise, not a piece".to_string(),
        });
    }

    Ok(())
}

pub fn validate_link_exercise(
    piece_id: &str,
    exercise_id: &str,
    model: &Model,
) -> Result<(), LibraryError> {
    if piece_id == exercise_id {
        return Err(LibraryError::Validation {
            field: "exercise_id".to_string(),
            message: "A piece cannot be linked to itself".to_string(),
        });
    }

    validate_piece_host(piece_id, model)?;

    validate_exercise_link_target(exercise_id, model)?;

    let already_linked = model
        .items
        .iter()
        .find(|i| i.id == piece_id)
        .is_some_and(|p| p.linked_exercise_ids.iter().any(|id| id == exercise_id));
    if already_linked {
        return Err(LibraryError::Validation {
            field: "exercise_id".to_string(),
            message: "Exercise is already linked to this piece".to_string(),
        });
    }

    Ok(())
}

/// A chord chart hangs off a piece. The host must exist and be a `Piece` —
/// exercises don't carry changes.
pub fn validate_chart_host(piece_id: &str, model: &Model) -> Result<(), LibraryError> {
    let piece = model
        .items
        .iter()
        .find(|i| i.id == piece_id)
        .ok_or_else(|| LibraryError::NotFound {
            id: piece_id.to_string(),
        })?;

    if piece.kind != ItemKind::Piece {
        return Err(LibraryError::Validation {
            field: "piece_id".to_string(),
            message: "Only a piece can have a chord chart".to_string(),
        });
    }

    Ok(())
}

pub fn validate_variant_host(id: &str, model: &Model) -> Result<(), LibraryError> {
    let item = model
        .items
        .iter()
        .find(|i| i.id == id)
        .ok_or_else(|| LibraryError::NotFound { id: id.to_string() })?;

    if item.kind != ItemKind::Exercise {
        return Err(LibraryError::Validation {
            field: "id".to_string(),
            message: "Only an exercise can have steps".to_string(),
        });
    }

    Ok(())
}

pub fn normalize_variant_labels(labels: Vec<String>) -> Vec<String> {
    labels.into_iter().map(|l| l.trim().to_string()).collect()
}

pub fn validate_variant_labels(labels: &[String]) -> Result<(), LibraryError> {
    if labels.len() > MAX_VARIANTS {
        return Err(LibraryError::Validation {
            field: "labels".to_string(),
            message: format!("An exercise can have at most {MAX_VARIANTS} steps"),
        });
    }

    let mut seen = std::collections::HashSet::new();
    for label in labels {
        if label.is_empty() || label.len() > MAX_VARIANT_LABEL {
            return Err(LibraryError::Validation {
                field: "labels".to_string(),
                message: format!(
                    "Each step label must be between 1 and {MAX_VARIANT_LABEL} characters"
                ),
            });
        }
        if !seen.insert(label.to_lowercase()) {
            return Err(LibraryError::Validation {
                field: "labels".to_string(),
                message: format!("Duplicate step \u{201c}{label}\u{201d}"),
            });
        }
    }

    Ok(())
}

pub fn validate_set_entry_fields(item_id: &str, item_title: &str) -> Result<(), LibraryError> {
    if item_id.trim().is_empty() {
        return Err(LibraryError::Validation {
            field: "item_id".to_string(),
            message: "Entry item_id must not be empty".to_string(),
        });
    }
    if item_title.trim().is_empty() {
        return Err(LibraryError::Validation {
            field: "item_title".to_string(),
            message: "Entry item_title must not be empty".to_string(),
        });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    // --- normalisation (#883) ---

    #[test]
    fn normalize_create_trims_and_drops_blank_optionals() {
        let input = CreateItem {
            title: "  Clair de Lune  ".to_string(),
            kind: ItemKind::Exercise,
            composer: Some("   ".to_string()),
            key: Some("  D major ".to_string()),
            modality: None,
            tempo: Some(Tempo {
                marking: Some("   ".to_string()),
                bpm: None,
            }),
            notes: Some("  ".to_string()),
            tags: vec![
                "  warm-up ".to_string(),
                "   ".to_string(),
                "scales".to_string(),
            ],
            photo_id: None,
        };

        let out = normalize_create_item(input);

        assert_eq!(out.title, "Clair de Lune");
        assert_eq!(
            out.composer, None,
            "whitespace-only composer collapses to None"
        );
        assert_eq!(out.key, Some("D major".to_string()));
        assert_eq!(out.notes, None, "whitespace-only notes collapses to None");
        assert_eq!(out.tempo, None, "blank marking + no bpm drops the tempo");
        assert_eq!(out.tags, vec!["warm-up".to_string(), "scales".to_string()]);
    }

    #[test]
    fn normalize_dedupes_tags_case_insensitively_keeping_first_casing() {
        let input = CreateItem {
            title: "Etude".to_string(),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![
                "Jazz".to_string(),
                "jazz".to_string(),
                "  JAZZ  ".to_string(),
                "blues".to_string(),
            ],
            photo_id: None,
        };
        assert_eq!(
            normalize_create_item(input).tags,
            vec!["Jazz".to_string(), "blues".to_string()]
        );

        let update = UpdateItem {
            tags: Some(vec!["Recital".to_string(), "recital".to_string()]),
            ..Default::default()
        };
        assert_eq!(
            normalize_update_item(update).tags,
            Some(vec!["Recital".to_string()])
        );
    }

    #[test]
    fn normalize_tempo_keeps_bpm_when_marking_blank() {
        // Blank marking must not discard a valid bpm — only a fully-empty
        // tempo collapses to None.
        let input = CreateItem {
            title: "Etude".to_string(),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: Some(Tempo {
                marking: Some("  ".to_string()),
                bpm: Some(120),
            }),
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        assert_eq!(
            normalize_create_item(input).tempo,
            Some(Tempo {
                marking: None,
                bpm: Some(120)
            })
        );
    }

    #[test]
    fn normalize_create_keeps_padded_composer_trimmed() {
        let input = CreateItem {
            title: "Hanon".to_string(),
            kind: ItemKind::Exercise,
            composer: Some("  Charles-Louis Hanon ".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        assert_eq!(
            normalize_create_item(input).composer,
            Some("Charles-Louis Hanon".to_string())
        );
    }

    #[test]
    fn normalize_update_trims_and_three_state_clears_blank() {
        let input = UpdateItem {
            title: Some("  Renamed ".to_string()),
            composer: Some(Some("   ".to_string())),
            key: Some(Some("  F# minor ".to_string())),
            tempo: Some(Some(Tempo {
                marking: Some("  ".to_string()),
                bpm: None,
            })),
            tags: Some(vec![" a ".to_string(), "".to_string()]),
            ..Default::default()
        };

        let out = normalize_update_item(input);

        assert_eq!(out.title, Some("Renamed".to_string()));
        assert_eq!(
            out.composer,
            Some(None),
            "blank set-composer becomes a clear"
        );
        assert_eq!(out.key, Some(Some("F# minor".to_string())));
        assert_eq!(out.tempo, Some(None), "blank tempo becomes a clear");
        assert_eq!(out.tags, Some(vec!["a".to_string()]));
    }

    #[test]
    fn normalize_update_leaves_untouched_fields_none() {
        let out = normalize_update_item(UpdateItem::default());
        assert_eq!(
            out.composer, None,
            "absent field stays absent (not a clear)"
        );
        assert_eq!(out.title, None);
        assert_eq!(out.tags, None);
    }

    // --- validate_create_item tests (piece kind) ---

    #[test]
    fn test_valid_create_piece() {
        let input = CreateItem {
            title: "Moonlight Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: Some("Beethoven".to_string()),
            key: Some("C# minor".to_string()),
            modality: None,
            tempo: Some(Tempo {
                marking: Some("Adagio sostenuto".to_string()),
                bpm: Some(60),
            }),
            notes: Some("First movement".to_string()),
            tags: vec!["classical".to_string(), "piano".to_string()],
            photo_id: None,
        };
        assert!(validate_create_item(&input).is_ok());
    }

    #[test]
    fn test_create_piece_empty_title() {
        let input = CreateItem {
            title: "".to_string(),
            kind: ItemKind::Piece,
            composer: Some("Beethoven".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "title");
                assert_eq!(message, "Title must be between 1 and 500 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_piece_title_too_long() {
        let input = CreateItem {
            title: "x".repeat(501),
            kind: ItemKind::Piece,
            composer: Some("Beethoven".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "title");
                assert_eq!(message, "Title must be between 1 and 500 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_piece_no_composer() {
        let input = CreateItem {
            title: "Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "composer");
                assert_eq!(message, "Composer is required");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_piece_empty_composer() {
        let input = CreateItem {
            title: "Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: Some("".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "composer");
                assert_eq!(message, "Composer is required");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_piece_composer_too_long() {
        let input = CreateItem {
            title: "Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: Some("x".repeat(201)),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "composer");
                assert_eq!(message, "Composer must be between 1 and 200 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_piece_notes_too_long() {
        let input = CreateItem {
            title: "Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: Some("Beethoven".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: Some("x".repeat(5001)),
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "notes");
                assert_eq!(message, "Notes must not exceed 5000 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_piece_notes_at_limit() {
        let input = CreateItem {
            title: "Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: Some("Beethoven".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: Some("x".repeat(5000)),
            tags: vec![],
            photo_id: None,
        };
        assert!(validate_create_item(&input).is_ok());
    }

    #[test]
    fn test_create_piece_minimal() {
        let input = CreateItem {
            title: "A".to_string(),
            kind: ItemKind::Piece,
            composer: Some("B".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        assert!(validate_create_item(&input).is_ok());
    }

    // --- validate_create_item tests (exercise kind) ---

    #[test]
    fn test_valid_create_exercise() {
        let input = CreateItem {
            title: "Scale Practice".to_string(),
            kind: ItemKind::Exercise,
            composer: Some("Hanon".to_string()),
            key: Some("C major".to_string()),
            modality: None,
            tempo: Some(Tempo {
                marking: Some("Moderato".to_string()),
                bpm: Some(100),
            }),
            notes: Some("Practice daily".to_string()),
            tags: vec!["technique".to_string()],
            photo_id: None,
        };
        assert!(validate_create_item(&input).is_ok());
    }

    #[test]
    fn test_create_exercise_empty_title() {
        let input = CreateItem {
            title: "".to_string(),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "title");
                assert_eq!(message, "Title must be between 1 and 500 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_exercise_title_too_long() {
        let input = CreateItem {
            title: "x".repeat(501),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "title");
                assert_eq!(message, "Title must be between 1 and 500 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_exercise_empty_composer() {
        let input = CreateItem {
            title: "Scales".to_string(),
            kind: ItemKind::Exercise,
            composer: Some("".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "composer");
                assert_eq!(message, "Composer must be between 1 and 200 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_exercise_composer_too_long() {
        let input = CreateItem {
            title: "Scales".to_string(),
            kind: ItemKind::Exercise,
            composer: Some("x".repeat(201)),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "composer");
                assert_eq!(message, "Composer must be between 1 and 200 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_exercise_notes_too_long() {
        let input = CreateItem {
            title: "Scales".to_string(),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: Some("x".repeat(5001)),
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "notes");
                assert_eq!(message, "Notes must not exceed 5000 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_exercise_no_optional_fields() {
        let input = CreateItem {
            title: "Warm up".to_string(),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        assert!(validate_create_item(&input).is_ok());
    }

    // --- validate_tags tests ---

    #[test]
    fn test_valid_tags() {
        let tags = vec!["classical".to_string(), "piano".to_string()];
        assert!(validate_tags(&tags).is_ok());
    }

    #[test]
    fn test_empty_tag() {
        let tags = vec!["classical".to_string(), "".to_string()];
        let err = validate_tags(&tags).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tags");
                assert_eq!(message, "Each tag must be between 1 and 100 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_tag_too_long() {
        let tags = vec!["x".repeat(101)];
        let err = validate_tags(&tags).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tags");
                assert_eq!(message, "Each tag must be between 1 and 100 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_tag_at_limit() {
        let tags = vec!["x".repeat(100)];
        assert!(validate_tags(&tags).is_ok());
    }

    #[test]
    fn test_empty_tags_vec() {
        let tags: Vec<String> = vec![];
        assert!(validate_tags(&tags).is_ok());
    }

    // --- validate_tempo tests ---

    #[test]
    fn test_valid_tempo_both_fields() {
        let tempo = Tempo {
            marking: Some("Allegro".to_string()),
            bpm: Some(120),
        };
        assert!(validate_tempo(&tempo).is_ok());
    }

    #[test]
    fn test_valid_tempo_marking_only() {
        let tempo = Tempo {
            marking: Some("Adagio".to_string()),
            bpm: None,
        };
        assert!(validate_tempo(&tempo).is_ok());
    }

    #[test]
    fn test_valid_tempo_bpm_only() {
        let tempo = Tempo {
            marking: None,
            bpm: Some(120),
        };
        assert!(validate_tempo(&tempo).is_ok());
    }

    #[test]
    fn test_tempo_neither_field() {
        let tempo = Tempo {
            marking: None,
            bpm: None,
        };
        let err = validate_tempo(&tempo).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "Tempo must have at least a marking or BPM value");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_tempo_marking_too_long() {
        let tempo = Tempo {
            marking: Some("x".repeat(101)),
            bpm: None,
        };
        let err = validate_tempo(&tempo).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "Tempo marking must not exceed 100 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_tempo_marking_at_limit() {
        let tempo = Tempo {
            marking: Some("x".repeat(100)),
            bpm: None,
        };
        assert!(validate_tempo(&tempo).is_ok());
    }

    #[test]
    fn test_tempo_bpm_zero() {
        let tempo = Tempo {
            marking: None,
            bpm: Some(0),
        };
        let err = validate_tempo(&tempo).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "BPM must be between 1 and 400");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_tempo_bpm_too_high() {
        let tempo = Tempo {
            marking: None,
            bpm: Some(401),
        };
        let err = validate_tempo(&tempo).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "BPM must be between 1 and 400");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_tempo_bpm_at_limits() {
        let tempo_min = Tempo {
            marking: None,
            bpm: Some(1),
        };
        assert!(validate_tempo(&tempo_min).is_ok());

        let tempo_max = Tempo {
            marking: None,
            bpm: Some(400),
        };
        assert!(validate_tempo(&tempo_max).is_ok());
    }

    // --- validate_update_item tests ---

    #[test]
    fn test_valid_update_item_no_fields() {
        let input = UpdateItem::default();
        assert!(validate_update_item(&input).is_ok());
    }

    #[test]
    fn test_update_item_empty_title() {
        let input = UpdateItem {
            title: Some("".to_string()),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "title");
                assert_eq!(message, "Title must be between 1 and 500 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_title_too_long() {
        let input = UpdateItem {
            title: Some("x".repeat(501)),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "title");
                assert_eq!(message, "Title must be between 1 and 500 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_empty_composer() {
        let input = UpdateItem {
            composer: Some(Some("".to_string())),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "composer");
                assert_eq!(message, "Composer must be between 1 and 200 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_clear_composer() {
        let input = UpdateItem {
            composer: Some(None),
            ..Default::default()
        };
        assert!(validate_update_item(&input).is_ok());
    }

    #[test]
    fn test_update_item_notes_too_long() {
        let input = UpdateItem {
            notes: Some(Some("x".repeat(5001))),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "notes");
                assert_eq!(message, "Notes must not exceed 5000 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_clear_notes() {
        let input = UpdateItem {
            notes: Some(None),
            ..Default::default()
        };
        assert!(validate_update_item(&input).is_ok());
    }

    #[test]
    fn test_update_item_invalid_tags() {
        let input = UpdateItem {
            tags: Some(vec!["".to_string()]),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tags");
                assert_eq!(message, "Each tag must be between 1 and 100 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_invalid_tempo() {
        let input = UpdateItem {
            tempo: Some(Some(Tempo {
                marking: None,
                bpm: None,
            })),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "Tempo must have at least a marking or BPM value");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_clear_tempo() {
        let input = UpdateItem {
            tempo: Some(None),
            ..Default::default()
        };
        assert!(validate_update_item(&input).is_ok());
    }

    #[test]
    fn test_create_piece_with_invalid_tempo() {
        let input = CreateItem {
            title: "Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: Some("Bach".to_string()),
            key: None,
            modality: None,
            tempo: Some(Tempo {
                marking: Some("x".repeat(101)),
                bpm: Some(120),
            }),
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "Tempo marking must not exceed 100 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_piece_with_invalid_tags() {
        let input = CreateItem {
            title: "Sonata".to_string(),
            kind: ItemKind::Piece,
            composer: Some("Bach".to_string()),
            key: None,
            modality: None,
            tempo: None,
            notes: None,
            tags: vec!["good".to_string(), "".to_string()],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tags");
                assert_eq!(message, "Each tag must be between 1 and 100 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_create_exercise_with_invalid_tempo() {
        let input = CreateItem {
            title: "Scales".to_string(),
            kind: ItemKind::Exercise,
            composer: None,
            key: None,
            modality: None,
            tempo: Some(Tempo {
                marking: None,
                bpm: Some(500),
            }),
            notes: None,
            tags: vec![],
            photo_id: None,
        };
        let err = validate_create_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "BPM must be between 1 and 400");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_invalid_tempo_bpm() {
        let input = UpdateItem {
            tempo: Some(Some(Tempo {
                marking: None,
                bpm: Some(0),
            })),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tempo");
                assert_eq!(message, "BPM must be between 1 and 400");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_update_item_tags_too_long() {
        let input = UpdateItem {
            tags: Some(vec!["x".repeat(101)]),
            ..Default::default()
        };
        let err = validate_update_item(&input).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "tags");
                assert_eq!(message, "Each tag must be between 1 and 100 characters");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    // --- validate_metre / validate_click_state ---

    fn metre(beats: u8, unit: u8, groups: Option<Vec<u8>>) -> crate::domain::Metre {
        crate::domain::Metre {
            beats,
            unit,
            groups,
        }
    }

    /// Metres a musician would actually enter, and the ones the picker must
    /// refuse, asserting what the click sheet needs: accepted means playable.
    #[test]
    fn metres_a_musician_enters_validate_as_the_picker_expects() {
        let accepted = [
            metre(4, 4, None),
            metre(3, 4, None),
            metre(2, 2, None),
            metre(6, 8, Some(vec![3, 3])),
            metre(7, 8, Some(vec![3, 2, 2])),
            metre(12, 8, Some(vec![3, 3, 3, 3])),
            metre(5, 4, Some(vec![3, 2])),
        ];
        for m in accepted {
            assert!(validate_metre(&m).is_ok(), "{m:?}");
        }
        let refused = [
            metre(1, 4, None),
            metre(13, 8, None),
            metre(4, 3, None),
            metre(4, 16, None),
            metre(7, 8, Some(vec![3, 3])),
            metre(7, 8, Some(vec![])),
            metre(4, 4, Some(vec![4, 0])),
        ];
        for m in refused {
            assert!(validate_metre(&m).is_err(), "{m:?}");
        }
    }

    #[test]
    fn a_click_must_sound_inside_the_bar() {
        use crate::domain::session::ClickState;
        let ok = ClickState {
            metre: metre(4, 4, None),
            sounding: 0b1010,
        };
        assert!(validate_click_state(&ok).is_ok());
        let silent = ClickState {
            metre: metre(4, 4, None),
            sounding: 0,
        };
        assert!(validate_click_state(&silent).is_err());
        let beyond = ClickState {
            metre: metre(3, 4, None),
            sounding: 0b1000,
        };
        assert!(
            validate_click_state(&beyond).is_err(),
            "beat 4 of a 3/4 bar"
        );
    }

    // --- validate_achieved_tempo tests ---

    #[test]
    fn test_achieved_tempo_none() {
        assert!(validate_achieved_tempo(&None).is_ok());
    }

    #[test]
    fn test_achieved_tempo_valid() {
        assert!(validate_achieved_tempo(&Some(120)).is_ok());
    }

    #[test]
    fn test_achieved_tempo_at_min() {
        assert!(validate_achieved_tempo(&Some(1)).is_ok());
    }

    #[test]
    fn test_achieved_tempo_at_max() {
        assert!(validate_achieved_tempo(&Some(500)).is_ok());
    }

    #[test]
    fn test_achieved_tempo_zero() {
        let err = validate_achieved_tempo(&Some(0)).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "achieved_tempo");
                assert_eq!(message, "Achieved tempo must be between 1 and 500 BPM");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_achieved_tempo_above_max() {
        let err = validate_achieved_tempo(&Some(501)).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "achieved_tempo");
                assert_eq!(message, "Achieved tempo must be between 1 and 500 BPM");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    // --- validate_entries_not_empty tests ---

    #[test]
    fn test_entries_not_empty_ok() {
        assert!(validate_entries_not_empty(&[1, 2, 3], "Setlist").is_ok());
    }

    #[test]
    fn test_entries_empty_setlist() {
        let entries: Vec<i32> = vec![];
        let err = validate_entries_not_empty(&entries, "Setlist").unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "entries");
                assert_eq!(message, "Setlist must have at least one entry");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_entries_empty_set() {
        let entries: Vec<i32> = vec![];
        let err = validate_entries_not_empty(&entries, "Set").unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "entries");
                assert_eq!(message, "Set must have at least one entry");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    // --- validate_rep_consistency tests ---

    #[test]
    fn test_rep_consistency_all_none() {
        assert!(validate_rep_consistency(None, None, None, false).is_ok());
    }

    #[test]
    fn test_rep_consistency_valid() {
        assert!(validate_rep_consistency(Some(5), Some(3), Some(false), true).is_ok());
    }

    #[test]
    fn test_rep_consistency_count_at_target() {
        assert!(validate_rep_consistency(Some(5), Some(5), Some(true), true).is_ok());
    }

    #[test]
    fn test_rep_consistency_count_exceeds_target() {
        let err = validate_rep_consistency(Some(5), Some(6), None, false).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "rep_count");
                assert_eq!(message, "rep_count (6) cannot exceed rep_target (5)");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_rep_consistency_count_without_target() {
        let err = validate_rep_consistency(None, Some(3), None, false).unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "rep_target");
                assert_eq!(
                    message,
                    "rep_count, rep_target_reached, and rep_history require rep_target"
                );
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_rep_consistency_reached_without_target() {
        let err = validate_rep_consistency(None, None, Some(true), false).unwrap_err();
        match err {
            LibraryError::Validation { field, .. } => {
                assert_eq!(field, "rep_target");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_rep_consistency_history_without_target() {
        let err = validate_rep_consistency(None, None, None, true).unwrap_err();
        match err {
            LibraryError::Validation { field, .. } => {
                assert_eq!(field, "rep_target");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    // --- validate_score tests ---

    #[test]
    fn validate_score_accepts_full_0_to_10_band() {
        assert!(validate_score(&Some(1)).is_ok());
        assert!(validate_score(&Some(10)).is_ok());
        assert!(validate_score(&None).is_ok());
        // 0 is "unrated" (None), never a settable score; 11 is out of range.
        assert!(validate_score(&Some(0)).is_err());
        assert!(validate_score(&Some(11)).is_err());
    }

    // --- validate_set_entry_fields tests ---

    #[test]
    fn test_set_entry_fields_valid() {
        assert!(validate_set_entry_fields("id1", "Sonata").is_ok());
    }

    #[test]
    fn test_set_entry_fields_empty_item_id() {
        let err = validate_set_entry_fields("", "Sonata").unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "item_id");
                assert_eq!(message, "Entry item_id must not be empty");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_set_entry_fields_whitespace_item_id() {
        let err = validate_set_entry_fields("  ", "Sonata").unwrap_err();
        match err {
            LibraryError::Validation { field, .. } => {
                assert_eq!(field, "item_id");
            }
            _ => panic!("Expected Validation error"),
        }
    }

    #[test]
    fn test_set_entry_fields_empty_item_title() {
        let err = validate_set_entry_fields("id1", "").unwrap_err();
        match err {
            LibraryError::Validation { field, message } => {
                assert_eq!(field, "item_title");
                assert_eq!(message, "Entry item_title must not be empty");
            }
            _ => panic!("Expected Validation error"),
        }
    }
}
