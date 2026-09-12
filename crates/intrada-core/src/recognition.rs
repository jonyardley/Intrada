//! On-device page recognition — the shell runs Vision (and, from phase C,
//! Foundation Models); the core decides what any of it means.
//!
//! Everything the shell returns is text with geometry. `read_fields` is the
//! only place a recognised line becomes a title, a composer or a tempo, and it
//! is a pure function so its tests need no device.

use crux_core::capability::Operation;
use crux_core::command::Command;
use serde::{Deserialize, Serialize};

use crate::app::{Effect, Event};
use crate::domain::types::Tempo;
use crate::validation::{MAX_BPM, MAX_COMPOSER, MAX_NOTES, MAX_TEMPO_MARKING, MAX_TITLE};

// ── The effect contract ─────────────────────────────────────────────

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum RecognitionOperation {
    /// Read a page the shell has already written to disk (phase A writes the
    /// bytes shell-side, so the core only ever names the file).
    ReadPage { photo_id: String },
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum RecognitionOutput {
    Page(PageReading),
    /// No recognition available on this device. Not an error: the user types
    /// the fields, and the photo is still saved.
    Unsupported,
    Failed,
}

impl Operation for RecognitionOperation {
    type Output = RecognitionOutput;
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct PageReading {
    /// Recognised lines in reading order, with normalised geometry so the core
    /// can reason about position without ever seeing the image.
    pub lines: Vec<RecognisedLine>,
    /// Populated only where Foundation Models ran (phase C). `None` on most
    /// devices, and `read_fields` must produce a usable draft regardless.
    pub suggested: Option<SuggestedFields>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct RecognisedLine {
    pub text: String,
    /// Normalised 0..1, origin top-left.
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub confidence: f32,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct SuggestedFields {
    pub title: Option<String>,
    pub composer: Option<String>,
    pub tempo_marking: Option<String>,
    pub bpm: Option<u16>,
    pub chart_text: Option<String>,
}

// ── The draft ───────────────────────────────────────────────────────

/// A proposal, exactly as `ScaffoldSpec` is: it becomes an `Item` only when the
/// user confirms. Every field carries where it came from, so the sheet can show
/// a low-confidence read differently from a clean one.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct PhotoDraft {
    pub title: Option<TextDraftField>,
    pub composer: Option<TextDraftField>,
    pub tempo: Option<TempoDraftField>,
    /// Phase D. Always `None` today.
    pub chart_text: Option<TextDraftField>,
}

/// The spec pins this as `DraftField<T>`; it is split per payload type because
/// facet typegen emits no generics across the bridge.
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct TextDraftField {
    pub value: String,
    pub source: DraftSource,
    pub confidence: f32,
    /// Whether the form shows this as a weak read. Decided here rather than
    /// against `confidence` in the shell: where the line between a clean read
    /// and a doubtful one falls is a domain judgement, and a shell that
    /// thresholded for itself would be the second place it lives.
    pub weak: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct TempoDraftField {
    pub value: Tempo,
    pub source: DraftSource,
    pub confidence: f32,
    /// See `TextDraftField::weak`.
    pub weak: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum DraftSource {
    /// Geometry heuristics in the core. The floor, available everywhere.
    Recognised,
    /// The on-device model chose it and it survived the substring clamp,
    /// except a tempo marking, which may then be tidied (#1683).
    Suggested,
}

/// Below this a read is shown as uncertain rather than hidden (decision 7).
pub const LOW_CONFIDENCE: f32 = 0.5;

/// `MIN_BPM` is the floor for a tempo the user *typed*. One guessed off a page
/// can be stricter: nobody prints a five-beats-a-minute marking, so a number
/// that low is a bar count or a fingering that happened to follow an `=`.
const MIN_READ_BPM: u16 = 20;

pub fn read_page(photo_id: String) -> Command<Effect, Event> {
    let read = photo_id.clone();
    Command::request_from_shell(RecognitionOperation::ReadPage { photo_id }).then_send(
        move |output| Event::PhotoRead {
            photo_id: read.clone(),
            output,
        },
    )
}

// ── Interpretation ──────────────────────────────────────────────────

/// Tempo markings we will name from a page, longest first so
/// "Allegro moderato" wins over "Allegro". Canonical spelling is ours, not the
/// page's: OCR reads `ALLEGRO` and the user should see `Allegro`.
/// Words that can stand beside a marking without making the line something
/// other than a tempo instruction: "Medium Swing", "Lento ma non troppo".
const TEMPO_QUALIFIERS: &[&str] = &[
    "slow",
    "slowly",
    "medium",
    "med",
    "fast",
    "up",
    "easy",
    "moderately",
    "very",
    "molto",
    "poco",
    "ma",
    "non",
    "troppo",
    "e",
    "con",
    "quasi",
    "tempo",
    "di",
    "bpm",
    "feel",
    "circa",
    "ca",
];

const TEMPO_MARKINGS: &[&str] = &[
    "Allegro moderato",
    "Allegro vivace",
    "Molto allegro",
    "Andante moderato",
    "Adagio ma non troppo",
    "Larghetto",
    "Moderato",
    "Andantino",
    "Sostenuto",
    "Allegretto",
    "Grazioso",
    "Maestoso",
    "Marcato",
    "Adagietto",
    "Allegro",
    "Andante",
    "Moderate",
    "Adagio",
    "Largo",
    "Lento",
    "Grave",
    "Vivace",
    "Presto",
    "Prestissimo",
    "Ballad",
    "Swing",
    "Bossa",
    "Latin",
    "Rubato",
];

/// A credit that names itself as one, and so needs no damping and no help from
/// where it sits on the page.
const EXPLICIT_CREDIT: f32 = 1.0;

/// How much a bare dash dampens the line's own confidence: the weakest credit
/// form, and the only one that has to prove itself geometrically.
const DASH_CREDIT: f32 = 0.8;

const DASHES: [char; 3] = ['-', '\u{2013}', '\u{2014}'];

/// Credit prefixes, longest first. The `f32` is how much the match dampens the
/// line's own OCR confidence: a bare `by` is a weaker claim than `Music by`.
const CREDIT_PREFIXES: &[(&str, f32)] = &[
    ("words and music by", 1.0),
    ("music and lyrics by", 1.0),
    ("lyrics and music by", 1.0),
    ("composed by", 1.0),
    ("music by", 1.0),
    ("written by", 0.9),
    ("by", 0.8),
];

/// A line this high up the page can be the title. Below it we are into the
/// first stave, where the largest text is a lyric, not a heading.
const TITLE_BAND: f32 = 0.4;

/// Deterministic. Prefers `suggested` where a field survives the substring
/// clamp (decision 5), otherwise falls back to geometry heuristics.
#[must_use]
pub fn read_fields(page: &PageReading) -> PhotoDraft {
    let heuristic = heuristic_draft(page);
    let Some(suggested) = page.suggested.as_ref() else {
        return heuristic;
    };

    let haystack = Haystack::of(&page.lines);

    PhotoDraft {
        title: clamped_text(suggested.title.as_deref(), &haystack, MAX_TITLE).or(heuristic.title),
        composer: clamped_composer(suggested.composer.as_deref(), &haystack).or(heuristic.composer),
        tempo: clamped_tempo(suggested, &haystack).or(heuristic.tempo),
        chart_text: clamped_text(suggested.chart_text.as_deref(), &haystack, MAX_NOTES)
            .or(heuristic.chart_text),
    }
}

/// Keeps which line each byte came from, so a clamped suggestion carries the
/// confidence of the text it matched rather than one it has not earned (#1454).
struct Haystack {
    text: String,
    lines: Vec<Span>,
}

struct Span {
    start: usize,
    end: usize,
    confidence: f32,
}

impl Haystack {
    /// Joined, not per line: a name Vision wrapped across two lines must still
    /// be accepted (decision 5, as amended in phase B).
    fn of(lines: &[RecognisedLine]) -> Self {
        let mut text = String::new();
        let mut spans = Vec::new();
        for line in lines {
            let normalised = normalise(&line.text);
            // A blank line would push a second separator space, and a needle
            // whose own spaces are single could then no longer match across it.
            if normalised.is_empty() {
                continue;
            }
            if !text.is_empty() {
                text.push(' ');
            }
            let start = text.len();
            text.push_str(&normalised);
            spans.push(Span {
                start,
                end: text.len(),
                confidence: line.confidence,
            });
        }
        Self { text, lines: spans }
    }

    /// Weakest line spanned, as `heuristic_tempo` already takes of its two. Best
    /// occurrence, not first: a smudged catalogue number printing the same
    /// digits must not decide a cleanly printed tempo's confidence.
    fn confidence_of(&self, value: &str) -> Option<f32> {
        let needle = normalise(value);
        if needle.is_empty() {
            return None;
        }
        self.text
            .match_indices(&needle)
            .filter_map(|(at, matched)| self.weakest_line_across(at, at + matched.len()))
            .reduce(f32::max)
    }

    fn weakest_line_across(&self, at: usize, end: usize) -> Option<f32> {
        self.lines
            .iter()
            .filter(|line| line.start < end && at < line.end)
            .map(|line| line.confidence)
            .reduce(f32::min)
    }

    /// `bpm_in`, run per line rather than on the page joined: an `=` ending
    /// one line must not pick up a page number printed on the next (#1683).
    fn bpm_follows_equals(&self, bpm: u16) -> bool {
        self.lines
            .iter()
            .any(|span| bpm_in(&self.text[span.start..span.end]) == Some(bpm))
    }
}

/// Decision 5, the whole of it: a suggested value the page does not literally
/// carry is discarded, so a model cannot invent a composer. Case- and
/// whitespace-insensitive, because OCR spacing is not the user's problem.
fn clamped_text(value: Option<&str>, haystack: &Haystack, max: usize) -> Option<TextDraftField> {
    let value = value?.trim();
    if value.is_empty() || value.len() > max {
        return None;
    }
    let confidence = haystack.confidence_of(value)?;
    Some(TextDraftField {
        value: value.to_string(),
        source: DraftSource::Suggested,
        confidence,
        weak: confidence < LOW_CONFIDENCE,
    })
}

/// The clamp says a suggestion is on the page, not that it is the right span of
/// it, and "Music by Kosma" is on the page. `heuristic_composer` strips it too.
fn clamped_composer(value: Option<&str>, haystack: &Haystack) -> Option<TextDraftField> {
    let value = value?.trim();
    let named = credit_prefix(value).map_or(value, |(rest, _)| rest);
    clamped_text(Some(named), haystack, MAX_COMPOSER)
}

fn clamped_tempo(suggested: &SuggestedFields, haystack: &Haystack) -> Option<TempoDraftField> {
    let marking = clamped_text(
        suggested.tempo_marking.as_deref(),
        haystack,
        MAX_TEMPO_MARKING,
    )
    .and_then(|m| {
        let value = canonical_marking(&m.value)?;
        Some(TextDraftField { value, ..m })
    });
    let bpm = suggested
        .bpm
        .filter(|bpm| haystack.bpm_follows_equals(*bpm))
        .and_then(|bpm| haystack.confidence_of(&bpm.to_string()).map(|c| (bpm, c)));

    let confidence = match (&marking, &bpm) {
        (Some(m), Some((_, b))) => m.confidence.min(*b),
        (Some(m), None) => m.confidence,
        (None, Some((_, b))) => *b,
        (None, None) => return None,
    };

    Tempo::from_parts(marking.map(|m| m.value), bpm.map(|(b, _)| b)).map(|value| TempoDraftField {
        value,
        source: DraftSource::Suggested,
        confidence,
        weak: confidence < LOW_CONFIDENCE,
    })
}

/// Decision 5 keeps a suggested marking verbatim, print noise and all: "(MED.)"
/// survives with its brackets (#1683).
fn canonical_marking(value: &str) -> Option<String> {
    let stripped = strip_print_noise(value);
    if stripped.is_empty() {
        return None;
    }
    Some(canonical_spelling(stripped))
}

fn strip_print_noise(value: &str) -> &str {
    let value = strip_enclosing(value.trim(), '(', ')');
    let value = strip_enclosing(value, '[', ']');
    value.trim().trim_end_matches('.').trim()
}

/// Only a single matched pair with nothing bracketed inside it: "(MED.)"
/// loses its brackets, "(BRIGHT) (SWING)" keeps both, unbalanced either way.
fn strip_enclosing(value: &str, open: char, close: char) -> &str {
    value
        .strip_prefix(open)
        .and_then(|rest| rest.strip_suffix(close))
        .filter(|inner| !inner.contains(open) && !inner.contains(close))
        .unwrap_or(value)
}

fn canonical_spelling(value: &str) -> String {
    let lower = value.to_lowercase();
    if lower == "med" {
        return "Medium".to_string();
    }
    TEMPO_MARKINGS
        .iter()
        .find(|candidate| candidate.to_lowercase() == lower)
        .map_or_else(|| value.to_string(), |candidate| (*candidate).to_string())
}

fn normalise(text: &str) -> String {
    text.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

fn heuristic_draft(page: &PageReading) -> PhotoDraft {
    // Title first: it keeps its line, so "Allegro Barbaro" is not a tempo.
    let title = heuristic_title(&page.lines);
    let tempo = heuristic_tempo(&page.lines, title.as_ref().map(|f| f.value.as_str()));
    PhotoDraft {
        title,
        composer: heuristic_composer(&page.lines),
        tempo,
        chart_text: None,
    }
}

/// Height alone picks the slash-chord stack that outsizes the title at a third
/// of its confidence (#1436).
/// A title is spelled. What sits above one on a photographed page is a page
/// number, a photocopier's reduction mark or a staple, and what sits beside it
/// is a chord row — all of them more figure than word (#1436 read both `66% =`
/// and `-7 C7#5` as fields before this).
fn looks_like_a_title(text: &str) -> bool {
    let letters = text.chars().filter(|c| c.is_alphabetic()).count();
    letters > 0 && letters > text.chars().filter(char::is_ascii_digit).count()
}

fn heuristic_title(lines: &[RecognisedLine]) -> Option<TextDraftField> {
    let candidates: Vec<&RecognisedLine> = lines
        .iter()
        .filter(|l| l.y < TITLE_BAND)
        .filter(|l| looks_like_a_title(&l.text))
        .filter(|l| credit_prefix(&l.text).is_none())
        .filter(|l| tempo_line(&l.text, true).is_none())
        .filter(|l| l.text.trim().len() <= MAX_TITLE)
        .collect();

    // A hallucinated line can dwarf the real heading (#1436); a weak one takes
    // the field only when nothing was read confidently, and is marked weak.
    let confident: Vec<&RecognisedLine> = candidates
        .iter()
        .copied()
        .filter(|l| l.confidence >= LOW_CONFIDENCE)
        .collect();
    let pool = if confident.is_empty() {
        &candidates
    } else {
        &confident
    };
    pool.iter()
        .max_by(|a, b| a.height.total_cmp(&b.height).then(b.y.total_cmp(&a.y)))
        .map(|l| TextDraftField {
            value: l.text.trim().to_string(),
            source: DraftSource::Recognised,
            confidence: l.confidence,
            weak: l.confidence < LOW_CONFIDENCE,
        })
}

fn heuristic_composer(lines: &[RecognisedLine]) -> Option<TextDraftField> {
    lines
        .iter()
        .filter_map(|l| {
            let (rest, damping) = credit_prefix(&l.text)?;
            // A bare `by` turns up in lyrics, so the weak forms only count
            // where a credit is printed. "Music by" runs the whole page.
            if damping < EXPLICIT_CREDIT && l.y >= TITLE_BAND {
                return None;
            }
            let rest = rest.trim().trim_end_matches([')', ']', '(', '[']).trim();
            (!rest.is_empty() && rest.len() <= MAX_COMPOSER).then_some((l, rest, damping))
        })
        // Strongest claim, then topmost: Vision's order is not the page's,
        // and its first match let a lyric beat an explicit credit (#1436).
        .max_by(|(a, _, ad), (b, _, bd)| ad.total_cmp(bd).then(b.y.total_cmp(&a.y)))
        .map(|(l, rest, damping)| TextDraftField {
            value: rest.to_string(),
            source: DraftSource::Recognised,
            confidence: l.confidence * damping,
            weak: l.confidence * damping < LOW_CONFIDENCE,
        })
}

/// Returns what follows the credit prefix, and how far the prefix dampens
/// confidence. Matched only at the start of the line.
/// A composer is spelled, capitalised and short. Everything else a dash can
/// start on a lead sheet is not: a chord row is figures (`-7 C7#5`) and a
/// hyphenated lyric runs on in lower case (`-er, I cried a riv-er over you`).
/// Both read as the composer before this (#1436).
fn looks_like_a_credited_name(text: &str) -> bool {
    (1..=4).contains(&text.split_whitespace().count())
        && !text.contains(',')
        && !text.chars().any(|c| c.is_ascii_digit() || c == '#')
        && text.starts_with(char::is_uppercase)
}

fn credit_prefix(text: &str) -> Option<(&str, f32)> {
    let trimmed = text.trim();
    // A leading dash does not stop an explicit credit being one.
    let undashed = trimmed.trim_start_matches(|c| DASHES.contains(&c) || c == ' ');

    let worded = CREDIT_PREFIXES.iter().find_map(|(prefix, damping)| {
        // Compared on `undashed`, not its lowercase: `to_lowercase` is not
        // length-preserving, so a byte index from one is not an index into it.
        let head = undashed.get(..prefix.len())?;
        if !head.eq_ignore_ascii_case(prefix) {
            return None;
        }
        let rest = &undashed[prefix.len()..];
        // Must end on a word boundary: "Bydgoszcz Suite" is not a credit.
        if !rest.is_empty() && !rest.starts_with(|c: char| c.is_whitespace() || c == ':') {
            return None;
        }
        Some((rest.trim_start_matches([':', ' ', '\t']), *damping))
    });
    if worded.is_some() {
        return worded;
    }

    // How a Real Book credits a composer: a dash and the name, nothing else.
    let name = undashed.trim_end_matches([')', ']', '(', '[']).trim();
    (undashed.len() < trimmed.len() && looks_like_a_credited_name(name))
        .then_some((name, DASH_CREDIT))
}

fn heuristic_tempo(lines: &[RecognisedLine], title: Option<&str>) -> Option<TempoDraftField> {
    let band: Vec<(&RecognisedLine, TempoRead)> = lines
        .iter()
        .filter(|l| l.y < TITLE_BAND)
        .filter(|l| Some(l.text.trim()) != title)
        .filter_map(|l| tempo_line(&l.text, false).map(|read| (l, read)))
        .collect();

    let marking = band
        .iter()
        .find_map(|(l, read)| read.marking.clone().map(|m| (m, l.confidence)));
    let bpm = band
        .iter()
        .find_map(|(l, read)| read.bpm.map(|b| (b, l.confidence)));

    let confidence = match (&marking, &bpm) {
        (Some((_, a)), Some((_, b))) => a.min(*b),
        (Some((_, c)), None) | (None, Some((_, c))) => *c,
        (None, None) => return None,
    };

    Tempo::from_parts(marking.map(|(m, _)| m), bpm.map(|(b, _)| b)).map(|value| TempoDraftField {
        value,
        source: DraftSource::Recognised,
        confidence,
        weak: confidence < LOW_CONFIDENCE,
    })
}

/// What the line says, if it is a tempo instruction and nothing else.
///
/// A marking *inside* a longer line belongs to a title — "Allegro Barbaro",
/// "Swing Low, Sweet Chariot", "Ballad of the Sad Young Men" — and reading it
/// as a tempo costs the title as well, since a title line is skipped once it
/// has explained itself as a tempo.
fn tempo_line(text: &str, strict: bool) -> Option<TempoRead> {
    let bpm = bpm_in(text);
    let before_bpm = text.rsplit_once('=').map_or(text, |(before, _)| before);
    let words: Vec<String> = before_bpm
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
        .map(str::to_lowercase)
        .collect();

    let mut marking = None;
    let mut rest: Vec<&str> = words.iter().map(String::as_str).collect();
    for candidate in TEMPO_MARKINGS {
        let needle: Vec<String> = candidate
            .to_lowercase()
            .split(' ')
            .map(String::from)
            .collect();
        if let Some(at) = rest.windows(needle.len()).position(|w| w == needle) {
            marking = Some((*candidate).to_string());
            rest.drain(at..at + needle.len());
            break;
        }
    }

    // A single leftover character is the mangled `♩` glyph.
    let unexplained = rest
        .iter()
        .filter(|w| w.chars().count() > 1 && !TEMPO_QUALIFIERS.contains(w))
        .count();

    // Strict means the line is *only* a tempo, so it cannot be the title. Loose
    // allows one unknown word, since print carries misprints (#1436).
    let allowed = if strict { 0 } else { 1 };

    (unexplained <= allowed && (marking.is_some() || bpm.is_some()))
        .then_some(TempoRead { marking, bpm })
}

/// What a tempo-only line says. Both parts are optional because a line can
/// carry either half on its own: `Andante`, or a bare `= 120`.
struct TempoRead {
    marking: Option<String>,
    bpm: Option<u16>,
}

/// Only a number that follows an `=` counts. `♩= 120` OCRs with the glyph
/// mangled or dropped, but the equals survives; a bare number near the top of a
/// page is a page number or a bar number at least as often as it is a tempo
/// (open question 3).
fn bpm_in(text: &str) -> Option<u16> {
    let (_, after) = text.rsplit_once('=')?;
    digits_after_equals(after)
}

/// Shared with `Haystack::bpm_follows_equals`; the range check lives here so
/// neither caller can skip it.
fn digits_after_equals(after: &str) -> Option<u16> {
    let digits: String = after
        .trim_start()
        .chars()
        .take_while(char::is_ascii_digit)
        .collect();
    digits
        .parse::<u16>()
        .ok()
        .filter(|bpm| (MIN_READ_BPM..=MAX_BPM).contains(bpm))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::item::ItemKind;
    use crate::domain::types::{assert_round_trips, CreateItem};
    use crate::validation;

    fn line(text: &str, y: f32, height: f32) -> RecognisedLine {
        RecognisedLine {
            text: text.to_string(),
            x: 0.1,
            y,
            width: 0.8,
            height,
            confidence: 0.9,
        }
    }

    fn page(lines: Vec<RecognisedLine>) -> PageReading {
        PageReading {
            lines,
            suggested: None,
        }
    }

    /// A printed first page: title big at the top, credit under it, tempo above
    /// the first stave, then lyrics well down the page.
    fn printed_page() -> PageReading {
        page(vec![
            line("Autumn Leaves", 0.08, 0.09),
            line("Music by Joseph Kosma", 0.18, 0.03),
            line("Moderato  = 120", 0.27, 0.025),
            line("The falling leaves drift by my window", 0.55, 0.04),
        ])
    }

    // ── Title ───────────────────────────────────────────────────────

    #[test]
    fn title_is_the_largest_text_in_the_top_band() {
        let draft = read_fields(&printed_page());
        let title = draft.title.expect("a title");
        assert_eq!(title.value, "Autumn Leaves");
        assert_eq!(title.source, DraftSource::Recognised);
    }

    /// Deleting the top-band filter makes this pass on the lyric instead: the
    /// biggest text on a lead sheet is often a lyric line halfway down.
    #[test]
    fn title_ignores_larger_text_below_the_top_band() {
        let draft = read_fields(&page(vec![
            line("Prelude in C", 0.10, 0.04),
            line("VERSE ONE, SET HUGE", 0.60, 0.20),
        ]));
        assert_eq!(draft.title.expect("a title").value, "Prelude in C");
    }

    /// Deleting the credit filter makes this pass on the credit line.
    #[test]
    fn title_is_never_the_credit_line() {
        let draft = read_fields(&page(vec![
            line("Music by Erik Satie", 0.10, 0.09),
            line("Gymnopedie No. 1", 0.20, 0.04),
        ]));
        assert_eq!(draft.title.expect("a title").value, "Gymnopedie No. 1");
    }

    #[test]
    fn title_carries_the_lines_own_confidence() {
        let mut lines = vec![line("Blurry Title", 0.08, 0.09)];
        lines[0].confidence = 0.31;
        let draft = read_fields(&page(lines));
        assert_eq!(draft.title.expect("a title").confidence, 0.31);
    }

    #[test]
    fn a_page_with_no_text_reads_into_nothing() {
        let draft = read_fields(&page(vec![]));
        assert_eq!(draft, PhotoDraft::default());
    }

    // ── Composer ────────────────────────────────────────────────────

    #[test]
    fn composer_is_read_from_each_credit_form() {
        for (text, expected) in [
            ("Music by Joseph Kosma", "Joseph Kosma"),
            ("Words and Music by Cole Porter", "Cole Porter"),
            ("Composed by Clara Schumann", "Clara Schumann"),
            ("by Thelonious Monk", "Thelonious Monk"),
            ("Music by: Bill Evans", "Bill Evans"),
        ] {
            let draft = read_fields(&page(vec![line(text, 0.2, 0.03)]));
            assert_eq!(
                draft.composer.expect("a composer").value,
                expected,
                "reading {text:?}"
            );
        }
    }

    /// Deleting the word-boundary check reads "dgoszcz Suite" as a composer.
    #[test]
    fn a_word_merely_starting_with_by_is_not_a_credit() {
        let draft = read_fields(&page(vec![line("Bydgoszcz Suite", 0.1, 0.05)]));
        assert!(draft.composer.is_none());
        assert_eq!(draft.title.expect("a title").value, "Bydgoszcz Suite");
    }

    /// Deleting the damping factor makes both forms equally confident, which
    /// is the claim being made: a bare `by` is a weaker signal than `Music by`.
    #[test]
    fn a_bare_by_is_less_confident_than_an_explicit_credit() {
        let bare = read_fields(&page(vec![line("by Duke Ellington", 0.2, 0.03)]))
            .composer
            .expect("a composer")
            .confidence;
        let explicit = read_fields(&page(vec![line("Music by Duke Ellington", 0.2, 0.03)]))
            .composer
            .expect("a composer")
            .confidence;
        assert!(
            bare < explicit,
            "bare {bare} should be less confident than explicit {explicit}"
        );
    }

    /// Deleting the band check on a bare `by` reads the lyric as the composer,
    /// at a confidence high enough that the form would not even mark it as a
    /// weak read.
    #[test]
    fn a_lyric_that_starts_with_by_is_not_a_composer() {
        let draft = read_fields(&page(vec![
            line("Moon River", 0.08, 0.09),
            line("By the light of the silvery moon she waits", 0.72, 0.03),
        ]));
        assert!(draft.composer.is_none());
        assert_eq!(draft.title.expect("a title").value, "Moon River");
    }

    #[test]
    fn an_explicit_credit_is_read_wherever_it_is_printed() {
        let draft = read_fields(&page(vec![
            line("Moon River", 0.08, 0.09),
            line("Music by Henry Mancini", 0.88, 0.03),
        ]));
        assert_eq!(draft.composer.expect("a composer").value, "Henry Mancini");
    }

    #[test]
    fn a_dash_before_a_name_is_a_credit() {
        for (text, expected) in [
            ("-J.J. Johnson", "J.J. Johnson"),
            ("- Cole Porter", "Cole Porter"),
            ("\u{2014} Clara Schumann", "Clara Schumann"),
        ] {
            let draft = read_fields(&page(vec![line(text, 0.16, 0.02)]));
            assert_eq!(
                draft.composer.expect("a composer").value,
                expected,
                "reading {text:?}"
            );
        }
    }

    /// What a dash actually starts on a lead sheet, all of it inside the band
    /// where the band check never protected anything.
    #[test]
    fn a_dash_reads_as_a_credit_only_when_a_name_follows_it() {
        let credits = [
            ("-J.J. JOHNSON", Some("J.J. JOHNSON")),
            ("- Cole Porter", Some("Cole Porter")),
            ("- Music by Cole Porter", Some("Cole Porter")),
            ("-7 C7#5 Bb7", None),
            ("-er, I cried a riv-er over you", None),
            ("-ly, you say you're lone-ly", None),
            ("- er", None),
        ];
        for (text, expected) in credits {
            let draft = read_fields(&page(vec![
                line("LAMENT", 0.048, 0.0459),
                line(text, 0.119, 0.0293),
            ]));
            assert_eq!(
                draft.composer.map(|f| f.value).as_deref(),
                expected,
                "reading {text:?}"
            );
        }
    }

    /// Vision's ordering is not the page's, so taking its first match let a
    /// lyric fragment beat an explicit credit printed above it (#1436).
    #[test]
    fn an_explicit_credit_beats_a_weaker_one_listed_before_it() {
        let draft = read_fields(&page(vec![
            line("Cry Me A River", 0.029, 0.0247),
            line("By the light of the silvery moon", 0.31, 0.02),
            line("Lyrics and Music by Arthur Hamilton", 0.06, 0.0119),
        ]));
        assert_eq!(draft.composer.expect("a composer").value, "Arthur Hamilton");
    }

    /// A photocopier's reduction mark and a page number are all figure (#1436).
    #[test]
    fn a_photocopier_mark_above_the_title_is_not_the_title() {
        let draft = read_fields(&page(vec![
            line("66% =", 0.008, 0.0240),
            line("239", 0.039, 0.0174),
            line("Cry Me A River", 0.029, 0.0247),
        ]));
        assert_eq!(draft.title.expect("a title").value, "Cry Me A River");
    }

    #[test]
    fn a_tall_uncertain_line_measured_off_a_page_loses_to_the_title() {
        let mut lines = vec![
            line("D/C Bbmi -7", 0.276, 0.0432),
            line("LAMENT", 0.104, 0.0417),
            line("(BALLAD)", 0.102, 0.0320),
        ];
        lines[0].confidence = 0.30;
        lines[1].confidence = 1.00;
        lines[2].confidence = 1.00;

        let draft = read_fields(&page(lines));

        assert_eq!(draft.title.expect("a title").value, "LAMENT");
        assert_eq!(
            draft.tempo.expect("a tempo").value.marking.as_deref(),
            Some("Ballad")
        );
    }

    /// Lines as Vision returned them (#1436): all three read, two dropped.
    #[test]
    fn a_printed_lead_sheet_gives_up_all_three_fields() {
        let mut lines = vec![
            line("th ct isu imthht to", 0.237, 0.0924),
            line("Cry Me A River", 0.121, 0.0176),
            line("Andrante Moderato (o = 88)", 0.170, 0.0161),
            line("Slowly and Rhythmically", 0.156, 0.0131),
            line("Lyrics and Music by Arthur Hamilton", 0.144, 0.0119),
        ];
        lines[0].confidence = 0.30;
        for l in lines.iter_mut().skip(1) {
            l.confidence = 1.0;
        }

        let draft = read_fields(&page(lines));

        assert_eq!(draft.title.expect("a title").value, "Cry Me A River");
        assert_eq!(draft.composer.expect("a composer").value, "Arthur Hamilton");
        let tempo = draft.tempo.expect("a tempo");
        assert_eq!(tempo.value.marking.as_deref(), Some("Moderato"));
        assert_eq!(tempo.value.bpm, Some(88));
    }

    /// Superscripts inflate a chord row's box past the title's, so size cannot
    /// separate them — but a chord row is more figure than word (#1436).
    #[test]
    fn a_chord_row_taller_than_the_title_is_not_a_title() {
        let draft = read_fields(&page(vec![
            line("B6 B67$5 E6A", 0.123, 0.0253),
            line("Cry Me A River", 0.029, 0.0247),
            line("Fm/Bb", 0.221, 0.0239),
        ]));
        assert_eq!(draft.title.expect("a title").value, "Cry Me A River");
    }

    /// The title is chosen first and the tempo cannot claim its line back.
    #[test]
    fn a_title_that_names_a_tempo_is_still_only_a_title() {
        let draft = read_fields(&page(vec![
            line("Allegro Barbaro", 0.08, 0.09),
            line("Bela Bartok", 0.18, 0.03),
        ]));
        assert_eq!(draft.title.expect("a title").value, "Allegro Barbaro");
        assert!(draft.tempo.is_none());
    }

    #[test]
    fn a_credit_with_no_name_after_it_is_not_a_composer() {
        let draft = read_fields(&page(vec![line("Music by", 0.2, 0.03)]));
        assert!(draft.composer.is_none());
    }

    // ── Tempo ───────────────────────────────────────────────────────

    #[test]
    fn tempo_reads_the_marking_and_the_bpm_together() {
        let tempo = read_fields(&printed_page()).tempo.expect("a tempo");
        assert_eq!(tempo.value.marking.as_deref(), Some("Moderato"));
        assert_eq!(tempo.value.bpm, Some(120));
    }

    #[test]
    fn a_marking_is_named_in_our_spelling_not_the_pages() {
        let draft = read_fields(&page(vec![line("ALLEGRO", 0.2, 0.03)]));
        assert_eq!(
            draft.tempo.expect("a tempo").value.marking.as_deref(),
            Some("Allegro")
        );
    }

    #[test]
    fn a_longer_marking_wins_over_the_word_inside_it() {
        let draft = read_fields(&page(vec![line("Allegro moderato", 0.2, 0.03)]));
        assert_eq!(
            draft.tempo.expect("a tempo").value.marking.as_deref(),
            Some("Allegro moderato")
        );
    }

    /// Deleting the whole-line requirement in `tempo_line` costs both fields at
    /// once: the tempo is invented, and the title it was invented from is
    /// skipped as a line that has already explained itself.
    #[test]
    fn a_title_containing_a_marking_word_stays_a_title() {
        for title in [
            "Swing Low, Sweet Chariot",
            "Ballad of the Sad Young Men",
            "Allegro Barbaro",
            "Latin Jazz Suite",
        ] {
            let draft = read_fields(&page(vec![line(title, 0.08, 0.09)]));
            assert_eq!(draft.title.map(|f| f.value).as_deref(), Some(title));
            assert!(draft.tempo.is_none(), "{title:?} is not a tempo marking");
        }
    }

    #[test]
    fn a_marking_still_reads_beside_the_words_that_qualify_it() {
        for (text, expected) in [
            ("Medium Swing", "Swing"),
            ("Slow Ballad", "Ballad"),
            ("Lento ma non troppo", "Lento"),
        ] {
            let draft = read_fields(&page(vec![line(text, 0.2, 0.03)]));
            assert_eq!(
                draft.tempo.expect("a tempo").value.marking.as_deref(),
                Some(expected),
                "reading {text:?}"
            );
        }
    }

    /// Open question 3, answered conservatively. Deleting the `=` requirement
    /// reads the page number as a tempo.
    #[test]
    fn a_bare_number_is_not_a_bpm() {
        let draft = read_fields(&page(vec![
            line("Sonata in G", 0.08, 0.09),
            line("48", 0.02, 0.02),
        ]));
        assert!(draft.tempo.is_none());
    }

    /// Deleting the floor reads a fingering or a bar count that happened to
    /// follow an `=` as a tempo nobody could play.
    #[test]
    fn a_bpm_outside_the_accepted_range_is_dropped() {
        for text in ["= 0", "= 5", "= 900", "= 40000"] {
            let draft = read_fields(&page(vec![line(text, 0.2, 0.03)]));
            assert!(draft.tempo.is_none(), "reading {text:?}");
        }
    }

    #[test]
    fn a_mangled_note_glyph_still_yields_the_bpm() {
        let draft = read_fields(&page(vec![line("J= 88", 0.2, 0.03)]));
        assert_eq!(draft.tempo.expect("a tempo").value.bpm, Some(88));
    }

    #[test]
    fn tempo_takes_the_weaker_of_its_two_lines_confidences() {
        let mut lines = vec![line("Andante", 0.15, 0.03), line("= 72", 0.20, 0.03)];
        lines[0].confidence = 0.8;
        lines[1].confidence = 0.4;
        let tempo = read_fields(&page(lines)).tempo.expect("a tempo");
        assert_eq!(tempo.confidence, 0.4);
    }

    // ── The substring clamp (key decision 5) ────────────────────────

    fn suggested_page(suggested: SuggestedFields) -> PageReading {
        PageReading {
            suggested: Some(suggested),
            ..printed_page()
        }
    }

    fn no_suggestions() -> SuggestedFields {
        SuggestedFields {
            title: None,
            composer: None,
            tempo_marking: None,
            bpm: None,
            chart_text: None,
        }
    }

    /// The whole of decision 5: a ~3B model asked to extract will sometimes
    /// produce a plausible composer that is not on the page. Deleting the
    /// `haystack.contains` check lets "Cole Porter" through from a Kosma page.
    #[test]
    fn a_suggestion_the_page_does_not_carry_is_discarded() {
        let draft = read_fields(&suggested_page(SuggestedFields {
            composer: Some("Cole Porter".to_string()),
            ..no_suggestions()
        }));
        let composer = draft.composer.expect("the heuristic composer");
        assert_eq!(composer.value, "Joseph Kosma");
        assert_eq!(composer.source, DraftSource::Recognised);
    }

    #[test]
    fn a_suggestion_the_page_carries_is_preferred_over_the_heuristic() {
        let draft = read_fields(&suggested_page(SuggestedFields {
            composer: Some("Kosma".to_string()),
            ..no_suggestions()
        }));
        let composer = draft.composer.expect("a composer");
        assert_eq!(composer.value, "Kosma");
        assert_eq!(composer.source, DraftSource::Suggested);
    }

    #[test]
    fn the_clamp_ignores_case_and_ocr_spacing() {
        let draft = read_fields(&suggested_page(SuggestedFields {
            title: Some("autumn   leaves".to_string()),
            ..no_suggestions()
        }));
        assert_eq!(draft.title.expect("a title").source, DraftSource::Suggested);
    }

    #[test]
    fn a_suggested_bpm_the_page_does_not_print_is_discarded() {
        let draft = read_fields(&suggested_page(SuggestedFields {
            bpm: Some(144),
            ..no_suggestions()
        }));
        let tempo = draft.tempo.expect("the heuristic tempo");
        assert_eq!(tempo.value.bpm, Some(120));
        assert_eq!(tempo.source, DraftSource::Recognised);
    }

    #[test]
    fn a_suggested_tempo_the_page_carries_is_preferred_over_the_heuristic() {
        let draft = read_fields(&suggested_page(SuggestedFields {
            tempo_marking: Some("Moderato".to_string()),
            bpm: Some(120),
            ..no_suggestions()
        }));
        let tempo = draft.tempo.expect("a tempo");
        assert_eq!(tempo.value.marking.as_deref(), Some("Moderato"));
        assert_eq!(tempo.value.bpm, Some(120));
        assert_eq!(tempo.source, DraftSource::Suggested);
    }

    /// Deleting the length check hands the create form a title it will reject,
    /// which the table test guards from the other side.
    #[test]
    fn a_suggestion_longer_than_the_field_allows_is_discarded() {
        let long = "La ".repeat(MAX_TITLE);
        let draft = read_fields(&PageReading {
            lines: vec![line(&long, 0.08, 0.09)],
            suggested: Some(SuggestedFields {
                title: Some(long.clone()),
                ..no_suggestions()
            }),
        });
        assert!(draft.title.is_none(), "too long for the form either way");
    }

    /// #1454: a suggestion claimed `confidence: 1.0`, so the field with the least
    /// evidence looked strongest. Hard-coding it fails here; the line read 0.31.
    #[test]
    fn a_suggestion_carries_the_confidence_of_the_text_it_matched() {
        let mut lines = vec![line("Autumn Leaves", 0.08, 0.09)];
        lines[0].confidence = 0.31;
        let draft = read_fields(&PageReading {
            lines,
            suggested: Some(SuggestedFields {
                title: Some("Autumn Leaves".to_string()),
                ..no_suggestions()
            }),
        });
        let title = draft.title.expect("a title");
        assert_eq!(title.source, DraftSource::Suggested);
        assert_eq!(title.confidence, 0.31);
        assert!(title.weak, "a shaky read is shown as one (decision 7)");
    }

    /// Decision 5 matches against the lines joined, so a name Vision wrapped is
    /// still accepted, and it is then only as good as its shakiest half.
    #[test]
    fn a_suggestion_spanning_two_lines_takes_the_weaker_of_them() {
        let mut lines = vec![
            line("Music by Joseph", 0.18, 0.03),
            line("Kosma", 0.22, 0.03),
        ];
        lines[0].confidence = 0.9;
        lines[1].confidence = 0.35;
        let composer = read_fields(&PageReading {
            lines,
            suggested: Some(SuggestedFields {
                composer: Some("Joseph Kosma".to_string()),
                ..no_suggestions()
            }),
        })
        .composer
        .expect("a composer");
        assert_eq!(composer.source, DraftSource::Suggested);
        assert_eq!(composer.confidence, 0.35);
    }

    /// Deleting the overlap filter takes the minimum of every line on the page,
    /// not of the lines the value actually spans.
    #[test]
    fn a_suggestion_is_not_dragged_down_by_a_line_it_did_not_match() {
        let mut lines = vec![
            line("Autumn Leaves", 0.08, 0.09),
            line("The falling leaves drift by my window", 0.55, 0.04),
        ];
        lines[0].confidence = 0.88;
        lines[1].confidence = 0.12;
        let title = read_fields(&PageReading {
            lines,
            suggested: Some(SuggestedFields {
                title: Some("Autumn Leaves".to_string()),
                ..no_suggestions()
            }),
        })
        .title
        .expect("a title");
        assert_eq!(title.confidence, 0.88);
        assert!(!title.weak);
    }

    #[test]
    fn a_suggested_tempo_takes_the_weaker_of_its_marking_and_its_bpm() {
        let mut lines = vec![line("Moderato", 0.25, 0.02), line("= 120", 0.27, 0.02)];
        lines[0].confidence = 0.7;
        lines[1].confidence = 0.44;
        let tempo = read_fields(&PageReading {
            lines,
            suggested: Some(SuggestedFields {
                tempo_marking: Some("Moderato".to_string()),
                bpm: Some(120),
                ..no_suggestions()
            }),
        })
        .tempo
        .expect("a tempo");
        assert_eq!(tempo.source, DraftSource::Suggested);
        assert_eq!(tempo.confidence, 0.44);
        assert!(tempo.weak);
    }

    /// A catalogue number and a metronome mark both print "120". Taking the first
    /// occurrence is #1454 surviving inside the fix for it.
    #[test]
    fn a_suggestion_the_page_prints_twice_takes_the_clearer_printing() {
        let mut lines = vec![line("Sonata K. 120", 0.06, 0.05), line("= 120", 0.28, 0.02)];
        lines[0].confidence = 0.15;
        lines[1].confidence = 0.92;
        let tempo = read_fields(&PageReading {
            lines,
            suggested: Some(SuggestedFields {
                bpm: Some(120),
                ..no_suggestions()
            }),
        })
        .tempo
        .expect("a tempo");
        assert_eq!(tempo.source, DraftSource::Suggested);
        assert_eq!(tempo.confidence, 0.92);
        assert!(!tempo.weak);
    }

    /// Deleting the blank-line skip in `Haystack::of` pushes a second separator
    /// space, and this stops matching across it, narrowing the phase B clamp.
    #[test]
    fn a_blank_line_between_two_lines_does_not_break_the_join() {
        let composer = read_fields(&PageReading {
            lines: vec![
                line("Music by Joseph", 0.18, 0.03),
                line("   ", 0.20, 0.01),
                line("Kosma", 0.22, 0.03),
            ],
            suggested: Some(SuggestedFields {
                composer: Some("Joseph Kosma".to_string()),
                ..no_suggestions()
            }),
        })
        .composer
        .expect("a composer");
        assert_eq!(composer.value, "Joseph Kosma");
        assert_eq!(composer.source, DraftSource::Suggested);
    }

    /// Hard-coding a certainty in this arm leaves every other test green.
    #[test]
    fn a_suggested_marking_with_no_bpm_carries_its_own_lines_confidence() {
        let mut lines = vec![line("Andante", 0.25, 0.02)];
        lines[0].confidence = 0.42;
        let tempo = read_fields(&PageReading {
            lines,
            suggested: Some(SuggestedFields {
                tempo_marking: Some("Andante".to_string()),
                ..no_suggestions()
            }),
        })
        .tempo
        .expect("a tempo");
        assert_eq!(tempo.source, DraftSource::Suggested);
        assert_eq!(tempo.confidence, 0.42);
        assert!(tempo.weak);
    }

    /// And plenty print the metronome mark and no word. Same arm, other half.
    #[test]
    fn a_suggested_bpm_with_no_marking_carries_its_own_lines_confidence() {
        let mut lines = vec![line("= 132", 0.25, 0.02)];
        lines[0].confidence = 0.38;
        let tempo = read_fields(&PageReading {
            lines,
            suggested: Some(SuggestedFields {
                bpm: Some(132),
                ..no_suggestions()
            }),
        })
        .tempo
        .expect("a tempo");
        assert_eq!(tempo.source, DraftSource::Suggested);
        assert_eq!(tempo.confidence, 0.38);
        assert!(tempo.weak);
    }

    struct TempoCase {
        name: &'static str,
        reading: PageReading,
        suggested: SuggestedFields,
        expected_bpm: Option<u16>,
        expected_marking: Option<&'static str>,
    }

    /// #1683: a page number sits where a metronome mark would, on its own
    /// line or, on a photocopy, after a reduction mark's `=` on the line
    /// above the title. "Allegro = 120" and "ca. 120" pin the genuine and the
    /// still-rejected shape either side of the fix.
    #[test]
    fn a_page_number_is_not_read_as_the_bpm_and_med_becomes_medium() {
        let cases = vec![
            TempoCase {
                name: "Real Book page 190: page number, marking, title, credit",
                reading: page(vec![
                    line("190", 0.03, 0.02),
                    line("(MED.)", 0.06, 0.02),
                    line("I Love You", 0.10, 0.08),
                    line("Cole Porter", 0.20, 0.03),
                ]),
                suggested: SuggestedFields {
                    tempo_marking: Some("(MED.)".to_string()),
                    bpm: Some(190),
                    ..no_suggestions()
                },
                expected_bpm: None,
                expected_marking: Some("Medium"),
            },
            TempoCase {
                name: "a page that actually prints a metronome mark",
                reading: page(vec![line("Allegro = 120", 0.09, 0.03)]),
                suggested: SuggestedFields {
                    tempo_marking: Some("Allegro".to_string()),
                    bpm: Some(120),
                    ..no_suggestions()
                },
                expected_bpm: Some(120),
                expected_marking: Some("Allegro"),
            },
            TempoCase {
                name: "a bare number with no marking and no equals falls through to nothing",
                reading: page(vec![line("304", 0.03, 0.02)]),
                suggested: SuggestedFields {
                    bpm: Some(304),
                    ..no_suggestions()
                },
                expected_bpm: None,
                expected_marking: None,
            },
            TempoCase {
                name: "ca. before the number is the same rule bpm_in already applies",
                reading: page(vec![line("Allegro = ca. 120", 0.09, 0.03)]),
                suggested: SuggestedFields {
                    tempo_marking: Some("Allegro".to_string()),
                    bpm: Some(120),
                    ..no_suggestions()
                },
                expected_bpm: None,
                expected_marking: Some("Allegro"),
            },
            TempoCase {
                name: "a photocopy's reduction mark ends in = one line above the page number",
                reading: page(vec![
                    line("66% =", 0.008, 0.0240),
                    line("239", 0.039, 0.0174),
                    line("Cry Me A River", 0.029, 0.0247),
                ]),
                suggested: SuggestedFields {
                    bpm: Some(239),
                    ..no_suggestions()
                },
                expected_bpm: None,
                expected_marking: None,
            },
        ];

        for case in cases {
            let mut reading = case.reading;
            reading.suggested = Some(case.suggested);
            let tempo = read_fields(&reading).tempo;
            let bpm = tempo.as_ref().and_then(|t| t.value.bpm);
            let marking = tempo.as_ref().and_then(|t| t.value.marking.clone());
            assert_eq!(bpm, case.expected_bpm, "{}: bpm", case.name);
            assert_eq!(
                marking.as_deref(),
                case.expected_marking,
                "{}: marking",
                case.name
            );
        }
    }

    /// "Music by Joseph Kosma" is on the page, so it survives the clamp and beats
    /// the heuristic. Deleting the strip pre-fills the field with the credit.
    #[test]
    fn a_suggested_composer_that_kept_its_credit_prefix_is_still_just_the_name() {
        let composer = read_fields(&suggested_page(SuggestedFields {
            composer: Some("Music by Joseph Kosma".to_string()),
            ..no_suggestions()
        }))
        .composer
        .expect("a composer");
        assert_eq!(composer.value, "Joseph Kosma");
        assert_eq!(composer.source, DraftSource::Suggested);
    }

    #[test]
    fn suggestions_never_replace_a_field_they_left_empty() {
        let draft = read_fields(&suggested_page(no_suggestions()));
        assert_eq!(draft, read_fields(&printed_page()));
    }

    // ── Against the consumer ────────────────────────────────────────

    /// Pages as a user would photograph them, asserted against what the create
    /// form actually accepts — not against the heuristics that produced them.
    #[test]
    fn every_read_field_is_one_the_create_form_accepts() {
        let pages: Vec<(&str, PageReading)> = vec![
            ("printed lead sheet", printed_page()),
            (
                "hymnal page",
                page(vec![
                    line("Be Thou My Vision", 0.06, 0.07),
                    line("Words and Music by Traditional Irish", 0.16, 0.025),
                    line("Andante", 0.24, 0.02),
                ]),
            ),
            (
                "photocopied study",
                page(vec![
                    line("Etude Op. 10 No. 3", 0.09, 0.06),
                    line("by Frederic Chopin", 0.17, 0.03),
                    line("Lento ma non troppo  = 100", 0.25, 0.02),
                ]),
            ),
            (
                "chart with no credit at all",
                page(vec![
                    line("Blues in F", 0.07, 0.08),
                    line("F7 | Bb7 | F7 | F7", 0.30, 0.03),
                ]),
            ),
            (
                "title made of a genre word",
                page(vec![
                    line("Swing Low, Sweet Chariot", 0.07, 0.08),
                    line("Traditional", 0.18, 0.03),
                    line("Medium Swing", 0.26, 0.02),
                ]),
            ),
            (
                "lyric that opens with by",
                page(vec![
                    line("Moon River", 0.06, 0.09),
                    line("Music by Henry Mancini", 0.16, 0.03),
                    line("By the light of the silvery moon she waits", 0.62, 0.04),
                ]),
            ),
            (
                "skewed capture, title not first in reading order",
                page(vec![
                    line("Swing", 0.22, 0.02),
                    line("Music by Count Basie", 0.15, 0.03),
                    line("One O'Clock Jump", 0.05, 0.08),
                ]),
            ),
        ];

        for (name, page) in pages {
            let draft = read_fields(&page);
            let title = draft.title.as_ref().map(|f| f.value.clone());
            assert!(title.is_some(), "{name}: expected a title");

            let input = CreateItem {
                title: title.unwrap(),
                kind: ItemKind::Piece,
                composer: draft
                    .composer
                    .as_ref()
                    .map(|f| f.value.clone())
                    .or_else(|| Some("Unknown".to_string())),
                key: None,
                modality: None,
                tempo: draft.tempo.as_ref().map(|f| f.value.clone()),
                notes: None,
                tags: vec![],
                photo_id: None,
            };
            validation::validate_create_item(&input)
                .unwrap_or_else(|e| panic!("{name}: the create form rejected the read: {e}"));

            if let Some(tempo) = draft.tempo.as_ref() {
                validation::validate_tempo(&tempo.value)
                    .unwrap_or_else(|e| panic!("{name}: tempo rejected: {e}"));
            }
        }
    }

    // ── The bridge wire (#846 class) ────────────────────────────────

    #[test]
    fn recognition_operation_round_trips_on_ffi_bincode_wire() {
        assert_round_trips(RecognitionOperation::ReadPage {
            photo_id: "01JB0000000000000000000000".to_string(),
        });
    }

    #[test]
    fn recognition_output_round_trips_on_ffi_bincode_wire() {
        assert_round_trips(RecognitionOutput::Page(suggested_page(SuggestedFields {
            title: Some("Autumn Leaves".to_string()),
            composer: Some("Kosma".to_string()),
            tempo_marking: Some("Moderato".to_string()),
            bpm: Some(120),
            chart_text: Some("F7 | Bb7".to_string()),
        })));
        assert_round_trips(RecognitionOutput::Unsupported);
        assert_round_trips(RecognitionOutput::Failed);
    }

    #[test]
    fn photo_draft_round_trips_on_ffi_bincode_wire() {
        assert_round_trips(read_fields(&printed_page()));
        assert_round_trips(PhotoDraft::default());
    }

    // ── Driving the app ─────────────────────────────────────────────

    mod wiring {
        use super::*;
        use crate::app::{Effect, Event, Intrada};
        use crate::domain::item::ItemEvent;
        use crate::model::{Model, PhotoRecognition, PhotoRecognitionStatus};
        use crux_core::App;

        const PHOTO: &str = "01JB0000000000000000000000";

        fn photo_read(output: RecognitionOutput) -> Event {
            Event::PhotoRead {
                photo_id: PHOTO.to_string(),
                output,
            }
        }

        fn read_photo(model: &mut Model) -> crux_core::Command<Effect, Event> {
            Intrada.update(
                Event::Item(ItemEvent::ReadPhoto {
                    photo_id: PHOTO.to_string(),
                }),
                model,
            )
        }

        #[test]
        fn read_photo_requests_recognition_and_marks_the_photo_as_reading() {
            let mut model = Model::test_default();
            let mut cmd = read_photo(&mut model);

            assert!(cmd.effects().any(|e| matches!(e, Effect::Recognition(req)
            if req.operation == RecognitionOperation::ReadPage {
                photo_id: PHOTO.to_string()
            })));
            assert_eq!(
                model.photo_recognition,
                PhotoRecognition::Reading {
                    photo_id: PHOTO.to_string()
                }
            );
        }

        /// The id correlation is only worth anything if the effect's own
        /// resolution carries it: deleting the capture in `read_page`'s closure
        /// leaves the event naming a photo the core never asked about.
        #[test]
        fn resolving_the_effect_sends_back_the_photo_it_asked_for() {
            let mut cmd = crate::recognition::read_page(PHOTO.to_string());
            let mut request = cmd
                .effects()
                .find_map(|e| match e {
                    Effect::Recognition(req) => Some(req),
                    _ => None,
                })
                .expect("a Recognition effect");

            request
                .resolve(RecognitionOutput::Unsupported)
                .expect("the shell resolves this once");

            let Some(Event::PhotoRead { photo_id, output }) = cmd.events().next() else {
                panic!("resolving should send PhotoRead");
            };
            assert_eq!(photo_id, PHOTO);
            assert_eq!(output, RecognitionOutput::Unsupported);
        }

        /// The screens show a spinner off this, so `Reading` has to reach the
        /// projection and not only the model.
        #[test]
        fn a_read_in_progress_is_visible_in_the_view() {
            let mut model = Model::test_default();
            let _ = read_photo(&mut model);

            let view = Intrada.view(&model).photo_recognition;
            assert_eq!(view.status, PhotoRecognitionStatus::Reading);
            assert_eq!(view.photo_id.as_deref(), Some(PHOTO));
            assert!(view.draft.is_none());
        }

        /// Offline-first invariant 1: recognition is on-device, end to end.
        #[test]
        fn reading_a_page_issues_no_http() {
            let mut model = Model::test_default();
            let mut cmd = read_photo(&mut model);
            assert!(!cmd.effects().any(|e| matches!(e, Effect::Http(_))));
        }

        #[test]
        fn an_unreadable_photo_id_surfaces_an_error_and_requests_nothing() {
            let mut model = Model::test_default();
            let mut cmd = Intrada.update(
                Event::Item(ItemEvent::ReadPhoto {
                    photo_id: "not-a-ulid".to_string(),
                }),
                &mut model,
            );
            assert!(model.last_error.is_some());
            assert_eq!(model.photo_recognition, PhotoRecognition::Idle);
            assert!(!cmd.effects().any(|e| matches!(e, Effect::Recognition(_))));
        }

        #[test]
        fn a_read_page_becomes_the_draft_the_form_is_filled_from() {
            let mut model = Model::test_default();
            let _ = read_photo(&mut model);
            let _ = Intrada.update(
                photo_read(RecognitionOutput::Page(printed_page())),
                &mut model,
            );

            let view = Intrada.view(&model).photo_recognition;
            assert_eq!(view.status, PhotoRecognitionStatus::Ready);
            assert_eq!(view.photo_id.as_deref(), Some(PHOTO));
            assert_eq!(
                view.draft.expect("a draft").title.expect("a title").value,
                "Autumn Leaves"
            );
        }

        /// Key decision 7, decided once in the core so no shell thresholds for
        /// itself. Deleting the `weak` derivation leaves a blurry read looking
        /// exactly as clean as a sharp one.
        #[test]
        fn a_weak_read_is_flagged_as_one_in_the_view() {
            let mut blurry = Model::test_default();
            let _ = read_photo(&mut blurry);
            let mut lines = printed_page().lines;
            lines[0].confidence = 0.2;
            let _ = Intrada.update(
                photo_read(RecognitionOutput::Page(page(lines))),
                &mut blurry,
            );
            let draft = Intrada
                .view(&blurry)
                .photo_recognition
                .draft
                .expect("a draft");
            assert!(
                draft.title.expect("a title").weak,
                "the blurry line is title"
            );
            assert!(
                !draft.composer.expect("a composer").weak,
                "the sharp lines are not dragged down with it"
            );
        }

        /// Not an error: the photo is still saved and the user types the
        /// fields. Surfacing this as a banner would be the wrong story.
        #[test]
        fn a_device_without_recognition_is_an_outcome_not_an_error() {
            let mut model = Model::test_default();
            let _ = read_photo(&mut model);
            let _ = Intrada.update(photo_read(RecognitionOutput::Unsupported), &mut model);

            assert_eq!(
                Intrada.view(&model).photo_recognition.status,
                PhotoRecognitionStatus::Unsupported
            );
            assert!(model.last_error.is_none());
        }

        #[test]
        fn a_failed_read_is_surfaced_as_failed_not_as_an_empty_draft() {
            let mut model = Model::test_default();
            let _ = read_photo(&mut model);
            let _ = Intrada.update(photo_read(RecognitionOutput::Failed), &mut model);

            let view = Intrada.view(&model).photo_recognition;
            assert_eq!(view.status, PhotoRecognitionStatus::Failed);
            assert!(view.draft.is_none());
        }

        /// Two scans in flight: the first to resolve must not land on the
        /// second's photo. Deleting the id comparison shows photo B beside the
        /// fields read off photo A, on the surface the user presses Add from.
        #[test]
        fn a_read_never_lands_on_a_photo_it_did_not_come_from() {
            const OTHER: &str = "01JB0000000000000000000001";
            let mut model = Model::test_default();

            let _ = read_photo(&mut model);
            let _ = Intrada.update(
                Event::Item(ItemEvent::ReadPhoto {
                    photo_id: OTHER.to_string(),
                }),
                &mut model,
            );

            // The first scan resolves second, as the slower page would.
            let _ = Intrada.update(
                photo_read(RecognitionOutput::Page(printed_page())),
                &mut model,
            );

            assert_eq!(
                model.photo_recognition,
                PhotoRecognition::Reading {
                    photo_id: OTHER.to_string()
                },
                "the current read must survive its predecessor landing"
            );
        }

        /// Deleting the `Reading` guard lets a read the user walked away from
        /// repopulate the form they have since left.
        #[test]
        fn a_late_read_is_dropped_once_the_user_has_moved_on() {
            let mut model = Model::test_default();
            let _ = read_photo(&mut model);
            let _ = Intrada.update(Event::DiscardPhotoDraft, &mut model);
            let _ = Intrada.update(
                photo_read(RecognitionOutput::Page(printed_page())),
                &mut model,
            );
            assert_eq!(model.photo_recognition, PhotoRecognition::Idle);
        }

        #[test]
        fn discarding_clears_a_draft_the_user_has_finished_with() {
            let mut model = Model::test_default();
            let _ = read_photo(&mut model);
            let _ = Intrada.update(
                photo_read(RecognitionOutput::Page(printed_page())),
                &mut model,
            );
            let _ = Intrada.update(Event::DiscardPhotoDraft, &mut model);

            let view = Intrada.view(&model).photo_recognition;
            assert_eq!(view.status, PhotoRecognitionStatus::Idle);
            assert!(view.draft.is_none());
            assert!(view.photo_id.is_none());
        }

        /// Nothing recognised is ever written without the user pressing Add
        /// (spec non-goal "no silent write").
        #[test]
        fn reading_a_page_never_writes_an_item() {
            let mut model = Model::test_default();
            let mut cmd = read_photo(&mut model);
            assert!(!cmd.effects().any(|e| matches!(e, Effect::Persistence(_))));

            let mut cmd = Intrada.update(
                photo_read(RecognitionOutput::Page(printed_page())),
                &mut model,
            );
            assert!(!cmd.effects().any(|e| matches!(e, Effect::Persistence(_))));
            assert!(model.items.is_empty());
        }

        #[test]
        fn the_bridge_events_round_trip_on_ffi_bincode_wire() {
            assert_round_trips(Event::Item(ItemEvent::ReadPhoto {
                photo_id: PHOTO.to_string(),
            }));
            assert_round_trips(photo_read(RecognitionOutput::Unsupported));
            assert_round_trips(Event::DiscardPhotoDraft);
        }

        #[test]
        fn the_view_projection_round_trips_on_ffi_bincode_wire() {
            let mut model = Model::test_default();
            let _ = read_photo(&mut model);
            let _ = Intrada.update(
                photo_read(RecognitionOutput::Page(printed_page())),
                &mut model,
            );
            assert_round_trips(Intrada.view(&model).photo_recognition);
        }
    }
}

#[cfg(test)]
mod real_pages {
    use super::*;

    fn line_at(text: &str, y: f32, height: f32, confidence: f32) -> RecognisedLine {
        RecognisedLine {
            text: text.to_string(),
            x: 0.1,
            y,
            width: 0.8,
            height,
            confidence,
        }
    }

    fn read(lines: Vec<RecognisedLine>) -> PhotoDraft {
        read_fields(&PageReading {
            lines,
            suggested: None,
        })
    }

    /// The whole of what Vision returned for a photographed handwritten Real
    /// Book page, recorded from a cropped photo before cropping was removed
    /// (#1436, #1684).
    #[test]
    fn a_handwritten_real_book_page() {
        let draft = read(vec![
            line_at("OLIDAY", 0.09, 0.0189, 1.0),
            line_at("(BALIAO)", 0.048, 0.0436, 1.0),
            line_at("F-9", 0.105, 0.0203, 1.0),
            line_at("LAMENT", 0.048, 0.0459, 1.0),
            line_at("Eb-", 0.108, 0.0247, 0.3),
            line_at("AbT", 0.115, 0.0233, 1.0),
            line_at("Dbmej?", 0.122, 0.0276, 1.0),
            line_at("Fma7", 0.19, 0.0262, 0.3),
            line_at("D-9", 0.202, 0.0218, 1.0),
            line_at("฿ 4 Л", 0.221, 0.0278, 0.3),
            line_at("G-7", 0.214, 0.0218, 1.0),
            line_at("D-", 0.285, 0.0247, 1.0),
            line_at("DC Bbm -", 0.269, 0.048, 0.3),
            line_at("D-7", 0.297, 0.0233, 1.0),
            line_at("G-1", 0.299, 0.0233, 1.0),
            line_at("F&...", 0.315, 0.0291, 0.3),
            line_at("F-7 Bb7", 0.369, 0.0308, 1.0),
            line_at("Eb-7", 0.376, 0.0291, 1.0),
            line_at("AbT", 0.379, 0.0291, 1.0),
            line_at("G-765", 0.381, 0.0349, 1.0),
            line_at("239", 0.039, 0.0174, 1.0),
            line_at("-J.J. JOHNSON)", 0.068, 0.0176, 1.0),
            line_at("G-105 C7", 0.119, 0.0293, 1.0),
            line_at("E-705", 0.201, 0.0262, 1.0),
            line_at("/A", 0.219, 0.0247, 1.0),
            line_at("AT#9", 0.209, 0.0291, 1.0),
            line_at("Cтba", 0.294, 0.0349, 1.0),
            line_at("ства", 0.384, 0.0349, 0.5),
        ]);
        assert_eq!(draft.title.expect("a title").value, "LAMENT");
        assert_eq!(draft.composer.expect("a composer").value, "J.J. JOHNSON");
    }

    /// The same for a printed lead sheet.
    #[test]
    fn a_printed_lead_sheet() {
        let draft = read(vec![
            line_at("Cry Me A River", 0.029, 0.0247, 1.0),
            line_at("Lyrics and Music by Arthur Hamilton", 0.06, 0.0161, 1.0),
            line_at("Slowly and Raythmically", 0.084, 0.016, 1.0),
            line_at("Andrante Moderato (o = 88)", 0.103, 0.022, 1.0),
            line_at("Cm", 0.131, 0.0174, 1.0),
            line_at("Cm#5", 0.125, 0.0218, 1.0),
            line_at("Ств", 0.125, 0.0218, 1.0),
            line_at("Cт?", 0.125, 0.0218, 1.0),
            line_at("Fm", 0.126, 0.0203, 1.0),
            line_at("B6 B67$5 E6A", 0.123, 0.0253, 1.0),
            line_at("Dm'", 0.126, 0.0203, 1.0),
            line_at("Gm?", 0.222, 0.0203, 1.0),
            line_at("C7#5", 0.221, 0.0218, 1.0),
            line_at("Fm?", 0.221, 0.0218, 1.0),
            line_at("Fm/Bb", 0.221, 0.0239, 1.0),
            line_at("EL6", 0.221, 0.0233, 1.0),
            line_at("D769 G", 0.219, 0.022, 1.0),
            line_at("Cry", 0.292, 0.0131, 1.0),
            line_at("Cm", 0.327, 0.0174, 1.0),
            line_at("Me A Riv -er,", 0.29, 0.0161, 1.0),
            line_at("Cm*s", 0.321, 0.0233, 1.0),
            line_at("Ст®", 0.323, 0.0218, 1.0),
            line_at("Cry_ Me A Riv-or,", 0.291, 0.0147, 1.0),
            line_at("Cm?", 0.323, 0.0218, 1.0),
            line_at("1 cried a riv-er o - ver", 0.291, 0.0147, 1.0),
            line_at("you......", 0.292, 0.0102, 1.0),
            line_at("Fm?", 0.323, 0.0218, 1.0),
            line_at("G'", 0.321, 0.0218, 1.0),
            line_at("Gm?", 0.42, 0.0203, 1.0),
            line_at("C?#5", 0.419, 0.0218, 1.0),
            line_at("F°", 0.422, 0.0174, 1.0),
            line_at("Fm?", 0.419, 0.0218, 1.0),
            line_at("Fm/Bb", 0.418, 0.0235, 1.0),
            line_at("EL6", 0.419, 0.0218, 0.3),
            line_at("Btpes ldaidd l. ol.", 0.433, 0.0503, 0.3),
            line_at("Cry-", 0.488, 0.0131, 1.0),
            line_at("Me A Riv-er,", 0.488, 0.0132, 1.0),
            line_at("Cry— My A Riv-er,", 0.488, 0.0146, 1.0),
            line_at("I cried a riv-er o - ver", 0.488, 0.0103, 1.0),
            line_at("you.", 0.49, 0.0102, 1.0),
        ]);
        assert_eq!(draft.title.expect("a title").value, "Cry Me A River");
        assert_eq!(draft.composer.expect("a composer").value, "Arthur Hamilton");
        let tempo = draft.tempo.expect("a tempo");
        assert_eq!(tempo.value.marking.as_deref(), Some("Moderato"));
        assert_eq!(tempo.value.bpm, Some(88));
    }
}
