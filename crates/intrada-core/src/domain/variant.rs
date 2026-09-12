use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// One rung of an exercise's step ladder: "C", "Root position", "Land on
/// the 3rd". The core's name; on screen a ladder is "Steps", or "Keys" when
/// every live rung names one. Which of the two is the core's call, via
/// `ladder_is_all_keys` (#1083, moved off the shell in #1467) — the shell
/// only prints the word. Score history is derived from session entries
/// tagged with this `id`, never stored here.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct Variant {
    pub id: String,
    pub label: String,
    pub position: usize,
    /// Per-row LWW timestamp so a step can sync independently of its
    /// exercise (invariant 2). Same format as `Item::updated_at`.
    pub updated_at: DateTime<Utc>,
    /// Soft-delete tombstone. Tombstoned variants stay in `Item::variants`
    /// (views filter them) so session history keeps resolving labels and a
    /// re-added label resurrects its score history.
    #[serde(default)]
    pub deleted_at: Option<DateTime<Utc>>,
}

/// A step is "Solid" (UI copy) once its latest score reaches this, of 10.
/// The current step is the first that isn't; progress means advancing the
/// rung, not polishing one rating (#1083; threshold decision in
/// specs/exercise-variants.md).
pub const SOLID_SCORE_MIN: u8 = 8;

/// Reconcile a ladder against the requested `labels` (ordered), matching by
/// case-insensitive label. A match keeps its id (and so its score history)
/// and adopts the incoming casing and position. `updated_at` bumps only on
/// rows that actually changed (per-row LWW hygiene).
pub fn reconcile_variants(
    existing: Vec<Variant>,
    labels: &[String],
    now: DateTime<Utc>,
) -> Vec<Variant> {
    let mut pool = existing;
    let mut next: Vec<Variant> = Vec::with_capacity(labels.len());

    for (position, label) in labels.iter().enumerate() {
        // Prefer a live match; fall back to a tombstone, which a re-added
        // label resurrects; its id, and so its score history, come back.
        let matched = pool
            .iter()
            .position(|v| v.deleted_at.is_none() && v.label.to_lowercase() == label.to_lowercase())
            .or_else(|| {
                pool.iter()
                    .position(|v| v.label.to_lowercase() == label.to_lowercase())
            });
        match matched {
            Some(i) => {
                let mut v = pool.remove(i);
                let changed = v.position != position || v.label != *label || v.deleted_at.is_some();
                v.position = position;
                v.label = label.clone();
                v.deleted_at = None;
                if changed {
                    v.updated_at = now;
                }
                next.push(v);
            }
            None => next.push(Variant {
                id: ulid::Ulid::generate().to_string(),
                label: label.clone(),
                position,
                updated_at: now,
                deleted_at: None,
            }),
        }
    }

    // Whatever wasn't matched has left the ladder: tombstone live rows;
    // rows already tombstoned carry through untouched.
    for mut v in pool {
        if v.deleted_at.is_none() {
            v.deleted_at = Some(now);
            v.updated_at = now;
        }
        next.push(v);
    }

    next
}

// ── Keys or steps ─────────────────────────────────────────────────────

/// True when the ladder has rungs and every one of them names a key, so the
/// Library row can say "12 keys" rather than "12 steps" (#1467). All or
/// nothing: one rung that isn't a key and "keys" would be a lie about it.
/// A ladder with no rungs has nothing to be all of, so it is not keys.
pub(crate) fn ladder_is_all_keys<'a>(labels: impl IntoIterator<Item = &'a str>) -> bool {
    let mut any = false;
    for label in labels {
        any = true;
        if !is_key_label(label) {
            return false;
        }
    }
    any
}

/// Deliberately not a circle-of-fifths lookup: spellings off the wheel
/// ("D♯ major") are keys a musician types, and the wheel would reject them.
/// Swift's `KeyHelper` keeps its own wheel for the picker, which answers a
/// different question — which spoke is this — and is view-only (#819).
fn is_key_label(raw: &str) -> bool {
    let normalised = ascii_accidentals(raw);
    let tonic = strip_mode_word(&normalised);
    is_tonic(tonic)
}

fn ascii_accidentals(raw: &str) -> String {
    raw.replace('\u{266F}', "#")
        .replace('\u{266D}', "b")
        .trim()
        .to_string()
}

/// "major"/"minor" are ASCII, so a five-byte tail is a five-char tail; the
/// boundary check keeps a multi-byte rung from slicing mid-character.
fn strip_mode_word(value: &str) -> &str {
    match value.len().checked_sub(5) {
        Some(cut)
            if value.is_char_boundary(cut)
                && matches!(value[cut..].to_lowercase().as_str(), "major" | "minor") =>
        {
            &value[..cut]
        }
        _ => value,
    }
}

/// The sign after the tonic letter is a symbol ("F#", "Bb") or the word a
/// musician types instead ("E flat", "F sharp") — the latter is what #1478
/// was filed over.
fn is_tonic(raw: &str) -> bool {
    let trimmed = raw.trim();
    let mut chars = trimmed.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    if !('A'..='G').contains(&first.to_ascii_uppercase()) {
        return false;
    }
    let sign = chars.as_str().trim_start();
    match sign.chars().count() {
        0 => true,
        1 => matches!(sign.chars().next().unwrap(), '#' | 'b' | 'B'),
        _ => matches!(sign.to_lowercase().as_str(), "flat" | "sharp"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Rungs a musician would actually type, not cases picked to match the
    /// scanner; the consumer is `ladder_is_all_keys`.
    #[test]
    fn labels_that_read_as_keys() {
        for label in [
            "C",
            "F#",
            "Bb",
            "F\u{266F}",
            "B\u{266D}",
            "c",
            " D ",
            "C major",
            "f# minor",
            // Spelled out and off the wheel: "C major, C♯ major, D♯ major…"
            // is all keys, so this is not a circle-of-fifths lookup.
            "D\u{266F} major",
            "G# major",
            "Db minor",
            // Spelled out, the #1478 gap: a musician types the sign as a
            // word rather than reaching for a symbol.
            "E flat major",
            "F sharp minor",
            "A flat",
            "c sharp",
        ] {
            assert!(is_key_label(label), "{label:?} names a key");
        }
    }

    #[test]
    fn labels_that_do_not() {
        for label in [
            "Root position",
            "1st inversion",
            "Land on the 3rd",
            "Hands together",
            "Step 1",
            "Am",
            "Dm",
            "C dorian",
            "G mixolydian",
            "C/E",
            "H",
            "",
            "major",
            "E flatten major",
            "F sharpish minor",
        ] {
            assert!(!is_key_label(label), "{label:?} does not name a key");
        }
    }

    #[test]
    fn a_ladder_of_keys_is_keys() {
        assert!(ladder_is_all_keys(["C", "G", "D"]));
        assert!(ladder_is_all_keys([
            "C major",
            "C\u{266F} major",
            "D major"
        ]));
    }

    #[test]
    fn one_rung_that_is_not_a_key_makes_the_whole_ladder_steps() {
        assert!(!ladder_is_all_keys(["C", "G", "Hands together"]));
        assert!(!ladder_is_all_keys(["Root position", "1st inversion"]));
    }

    #[test]
    fn an_empty_ladder_is_not_keys() {
        assert!(!ladder_is_all_keys(std::iter::empty::<&str>()));
    }
}
