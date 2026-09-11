//! The musician's profile: name, instrument, icon and highlighter colour,
//! stored on the device (`specs/profile.md`).

use crux_core::Command;
use serde::{Deserialize, Serialize};

use crate::app::{AppEffect, Effect, Event};
use crate::model::{FormErrorTarget, Model};
use crate::validation;

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum InstrumentIcon {
    Piano,
    AcousticGuitar,
    ElectricGuitar,
    Violin,
    Cello,
    Voice,
    Flute,
    Clarinet,
    Saxophone,
    Trumpet,
    Drums,
    Harp,
    #[default]
    Other,
}

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum HighlighterColour {
    Mint,
    Coral,
    Lavender,
    Sky,
    Sage,
    #[default]
    Butter,
    Peach,
    Powder,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct Profile {
    pub name: String,
    pub instrument: String,
    pub icon_choice: Option<InstrumentIcon>,
    pub colour: HighlighterColour,
}

impl Profile {
    pub fn icon(&self) -> InstrumentIcon {
        self.icon_choice
            .unwrap_or_else(|| suggest_icon(&self.instrument))
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum ProfileField {
    Name,
    Instrument,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
#[cfg_attr(feature = "facet_typegen", repr(C))]
pub enum ProfileEvent {
    Save(Profile),
    /// The shell replaying the stored blob at launch: no validation, no re-save.
    Loaded(Profile),
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Default)]
#[cfg_attr(feature = "facet_typegen", derive(facet::Facet))]
pub struct ProfileView {
    pub name: String,
    pub instrument: String,
    pub suggested_icon: InstrumentIcon,
    pub icon: InstrumentIcon,
    pub colour: HighlighterColour,
    pub greeting: String,
}

// Order-sensitive: a keyword inside a longer name ("alto" in "alto sax",
// "piccolo" in "piccolo trumpet") sits below every row claiming the longer one.
const ICON_KEYWORDS: &[(&str, InstrumentIcon)] = &[
    ("piano", InstrumentIcon::Piano),
    ("keyboard", InstrumentIcon::Piano),
    ("keys", InstrumentIcon::Piano),
    ("organ", InstrumentIcon::Piano),
    ("harpsichord", InstrumentIcon::Piano),
    ("electric guitar", InstrumentIcon::ElectricGuitar),
    ("bass guitar", InstrumentIcon::ElectricGuitar),
    ("electric bass", InstrumentIcon::ElectricGuitar),
    ("guitar", InstrumentIcon::AcousticGuitar),
    ("ukulele", InstrumentIcon::AcousticGuitar),
    ("banjo", InstrumentIcon::AcousticGuitar),
    ("mandolin", InstrumentIcon::AcousticGuitar),
    ("violin", InstrumentIcon::Violin),
    ("viola", InstrumentIcon::Violin),
    ("fiddle", InstrumentIcon::Violin),
    ("cello", InstrumentIcon::Cello),
    ("double bass", InstrumentIcon::Cello),
    ("flute", InstrumentIcon::Flute),
    ("recorder", InstrumentIcon::Flute),
    ("clarinet", InstrumentIcon::Clarinet),
    ("oboe", InstrumentIcon::Clarinet),
    ("cor anglais", InstrumentIcon::Clarinet),
    ("english horn", InstrumentIcon::Clarinet),
    ("bassoon", InstrumentIcon::Clarinet),
    ("sax", InstrumentIcon::Saxophone),
    ("trumpet", InstrumentIcon::Trumpet),
    ("cornet", InstrumentIcon::Trumpet),
    ("trombone", InstrumentIcon::Trumpet),
    ("horn", InstrumentIcon::Trumpet),
    ("tuba", InstrumentIcon::Trumpet),
    ("euphonium", InstrumentIcon::Trumpet),
    ("brass", InstrumentIcon::Trumpet),
    ("piccolo", InstrumentIcon::Flute),
    ("drum", InstrumentIcon::Drums),
    ("percussion", InstrumentIcon::Drums),
    ("timpani", InstrumentIcon::Drums),
    ("marimba", InstrumentIcon::Drums),
    ("harp", InstrumentIcon::Harp),
    ("voice", InstrumentIcon::Voice),
    ("vocal", InstrumentIcon::Voice),
    ("sing", InstrumentIcon::Voice),
    ("soprano", InstrumentIcon::Voice),
    ("alto", InstrumentIcon::Voice),
    ("tenor", InstrumentIcon::Voice),
    ("baritone", InstrumentIcon::Voice),
    ("bass", InstrumentIcon::Cello),
];

pub(crate) fn suggest_icon(instrument: &str) -> InstrumentIcon {
    let text = instrument.trim().to_lowercase();
    if text.is_empty() {
        return InstrumentIcon::Other;
    }
    ICON_KEYWORDS
        .iter()
        .find(|(keyword, _)| text.contains(keyword))
        .map(|(_, icon)| *icon)
        .unwrap_or(InstrumentIcon::Other)
}

// Bands are design-principles T25; the wording is tone-of-voice V6.
pub(crate) fn greeting(name: &str, local_hour: u32) -> String {
    let name = name.trim();
    if name.is_empty() {
        return String::new();
    }
    let time_of_day = match local_hour {
        4..=11 => "Morning",
        12..=17 => "Afternoon",
        _ => "Evening",
    };
    format!("{time_of_day}, {name}")
}

pub fn build_profile_view(profile: &Profile, local_hour: u32) -> ProfileView {
    ProfileView {
        name: profile.name.clone(),
        instrument: profile.instrument.clone(),
        suggested_icon: suggest_icon(&profile.instrument),
        icon: profile.icon(),
        colour: profile.colour,
        greeting: greeting(&profile.name, local_hour),
    }
}

pub fn handle_profile_event(event: ProfileEvent, model: &mut Model) -> Command<Effect, Event> {
    match event {
        ProfileEvent::Save(profile) => {
            let profile = validation::normalize_profile(profile);
            if let Err(e) = validation::validate_profile(&profile) {
                model.last_error_target = Some(FormErrorTarget::Profile {
                    field: profile_field(&e),
                });
                model.last_error = Some(e.to_string());
                return crux_core::render::render();
            }
            model.profile = profile.clone();
            model.record_success();
            Command::all([
                Command::notify_shell(AppEffect::SaveProfile(profile)).into(),
                crux_core::render::render(),
            ])
        }
        ProfileEvent::Loaded(profile) => {
            model.profile = profile;
            crux_core::render::render()
        }
    }
}

fn profile_field(error: &crate::error::LibraryError) -> ProfileField {
    match error {
        crate::error::LibraryError::Validation { field, .. } if field == "instrument" => {
            ProfileField::Instrument
        }
        _ => ProfileField::Name,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::Intrada;
    use crate::domain::types::assert_round_trips;
    use crate::validation::{MAX_INSTRUMENT, MAX_PROFILE_NAME};
    use crux_core::App;

    fn fixture() -> Profile {
        Profile {
            name: "Jon".to_string(),
            instrument: "Piano".to_string(),
            icon_choice: None,
            colour: HighlighterColour::Butter,
        }
    }

    fn save(model: &mut Model, profile: Profile) -> Command<Effect, Event> {
        Intrada.update(Event::Profile(ProfileEvent::Save(profile)), model)
    }

    fn emits_save(cmd: &mut Command<Effect, Event>) -> Option<Profile> {
        cmd.effects().find_map(|e| match e {
            Effect::App(req) => match &req.operation {
                AppEffect::SaveProfile(p) => Some(p.clone()),
                _ => None,
            },
            _ => None,
        })
    }

    // ── Icon suggestion ──

    #[test]
    fn suggests_an_icon_from_what_a_musician_types() {
        use InstrumentIcon::*;
        let cases = [
            ("Piano", Piano),
            ("grand piano", Piano),
            ("  Keys ", Piano),
            ("Acoustic guitar", AcousticGuitar),
            ("Guitar", AcousticGuitar),
            ("Electric guitar", ElectricGuitar),
            ("bass guitar", ElectricGuitar),
            ("Violin", Violin),
            ("viola", Violin),
            ("Cello", Cello),
            ("Double bass", Cello),
            ("Bass", Cello),
            ("vocals", Voice),
            ("Voice", Voice),
            ("Singer", Voice),
            ("Mezzo-soprano", Voice),
            ("Flute", Flute),
            ("Clarinet", Clarinet),
            ("Oboe", Clarinet),
            ("Alto sax", Saxophone),
            ("Saxophone", Saxophone),
            ("Trumpet", Trumpet),
            ("French horn", Trumpet),
            ("Trombone", Trumpet),
            ("Piccolo trumpet", Trumpet),
            ("Piccolo", Flute),
            ("English horn", Clarinet),
            ("Tenor banjo", AcousticGuitar),
            ("Bass trombone", Trumpet),
            ("Bass clarinet", Clarinet),
            ("Tenor sax", Saxophone),
            ("Cor anglais", Clarinet),
            ("Drums", Drums),
            ("Drum kit", Drums),
            ("Percussion", Drums),
            ("Harp", Harp),
            ("", Other),
            ("   ", Other),
            ("Theremin", Other),
        ];
        for (typed, expected) in cases {
            assert_eq!(suggest_icon(typed), expected, "typed {typed:?}");
        }
    }

    #[test]
    fn the_musicians_pick_wins_over_the_suggestion() {
        let profile = Profile {
            icon_choice: Some(InstrumentIcon::Harp),
            ..fixture()
        };
        assert_eq!(profile.icon(), InstrumentIcon::Harp);
        assert_eq!(fixture().icon(), InstrumentIcon::Piano);
    }

    // ── Greeting ──

    #[test]
    fn greeting_names_the_time_of_day_at_the_band_edges() {
        let cases: &[(u32, &str)] = &[
            (0, "Evening, Jon"),
            (3, "Evening, Jon"),
            (4, "Morning, Jon"),
            (11, "Morning, Jon"),
            (12, "Afternoon, Jon"),
            (17, "Afternoon, Jon"),
            (18, "Evening, Jon"),
            (23, "Evening, Jon"),
        ];
        for (hour, expected) in cases {
            assert_eq!(greeting("Jon", *hour), *expected, "hour {hour}");
        }
    }

    #[test]
    fn greeting_is_empty_without_a_name() {
        assert_eq!(greeting("", 9), "");
        assert_eq!(greeting("   ", 15), "");
    }

    // ── View ──

    #[test]
    fn view_carries_both_the_suggestion_and_the_shown_icon() {
        let view = build_profile_view(
            &Profile {
                instrument: "Double bass".to_string(),
                icon_choice: Some(InstrumentIcon::ElectricGuitar),
                ..fixture()
            },
            9,
        );
        assert_eq!(view.suggested_icon, InstrumentIcon::Cello);
        assert_eq!(view.icon, InstrumentIcon::ElectricGuitar);
        assert_eq!(view.greeting, "Morning, Jon");
        assert_eq!(view.colour, HighlighterColour::Butter);
    }

    #[test]
    fn view_of_an_untouched_profile_is_the_defaults() {
        let view = build_profile_view(&Profile::default(), 9);
        assert_eq!(view.name, "");
        assert_eq!(view.instrument, "");
        assert_eq!(view.icon, InstrumentIcon::Other);
        assert_eq!(view.colour, HighlighterColour::Butter);
        assert_eq!(view.greeting, "");
    }

    // ── Events ──

    #[test]
    fn save_trims_updates_the_model_and_emits_the_save_effect() {
        let mut model = Model::test_default();
        let mut cmd = save(
            &mut model,
            Profile {
                name: "  Jon ".to_string(),
                instrument: " Piano  ".to_string(),
                ..fixture()
            },
        );
        assert_eq!(model.profile, fixture(), "trimmed before storing");
        assert_eq!(emits_save(&mut cmd), Some(fixture()));
    }

    /// The save effect is fire-and-forget, so no confirmation event ever
    /// clears the banner: an accepted save must clear it itself, or the shell
    /// reads the second save as refused (`Store+Feedback.swift`).
    #[test]
    fn an_accepted_save_clears_the_error_a_rejected_one_left() {
        let mut model = Model::test_default();
        let _ = save(
            &mut model,
            Profile {
                name: "x".repeat(MAX_PROFILE_NAME + 1),
                ..fixture()
            },
        );
        assert!(model.last_error.is_some());

        let _ = save(&mut model, fixture());
        assert_eq!(model.last_error, None);
        assert_eq!(model.profile, fixture());
    }

    #[test]
    fn the_cap_counts_characters_not_bytes() {
        let mut model = Model::test_default();
        let accented = Profile {
            name: "é".repeat(MAX_PROFILE_NAME),
            instrument: "ü".repeat(MAX_INSTRUMENT),
            ..fixture()
        };
        let mut cmd = save(&mut model, accented.clone());
        assert_eq!(
            model.profile, accented,
            "at the cap in characters, over it in bytes"
        );
        assert!(emits_save(&mut cmd).is_some());
    }

    #[test]
    fn save_over_the_cap_keeps_the_last_profile_and_targets_the_field() {
        let mut model = Model::test_default();
        let _ = save(&mut model, fixture());

        let mut cmd = save(
            &mut model,
            Profile {
                instrument: "x".repeat(MAX_INSTRUMENT + 1),
                ..fixture()
            },
        );
        assert_eq!(
            model.profile,
            fixture(),
            "rejected save leaves the model alone"
        );
        assert!(model.last_error.is_some());
        assert_eq!(
            model.last_error_target,
            Some(FormErrorTarget::Profile {
                field: ProfileField::Instrument
            })
        );
        assert_eq!(emits_save(&mut cmd), None, "nothing written");

        let _ = save(
            &mut model,
            Profile {
                name: "x".repeat(MAX_PROFILE_NAME + 1),
                ..fixture()
            },
        );
        assert_eq!(
            model.last_error_target,
            Some(FormErrorTarget::Profile {
                field: ProfileField::Name
            })
        );
    }

    #[test]
    fn save_at_the_cap_is_accepted() {
        let mut model = Model::test_default();
        let at_cap = Profile {
            name: "n".repeat(MAX_PROFILE_NAME),
            instrument: "i".repeat(MAX_INSTRUMENT),
            ..fixture()
        };
        let mut cmd = save(&mut model, at_cap.clone());
        assert_eq!(model.profile, at_cap);
        assert!(emits_save(&mut cmd).is_some());
    }

    #[test]
    fn loaded_sets_the_model_without_re_saving() {
        let mut model = Model::test_default();
        let mut cmd = Intrada.update(Event::Profile(ProfileEvent::Loaded(fixture())), &mut model);
        assert_eq!(model.profile, fixture());
        assert_eq!(
            emits_save(&mut cmd),
            None,
            "restore never re-writes the blob"
        );
    }

    #[test]
    fn view_model_projects_the_profile() {
        let mut model = Model::test_default();
        let _ = save(&mut model, fixture());
        let vm = Intrada.view(&model);
        let projected = vm.profile;
        let expected = build_profile_view(&fixture(), 9);
        assert!(
            ["Morning, Jon", "Afternoon, Jon", "Evening, Jon"]
                .contains(&projected.greeting.as_str()),
            "the greeting follows the real clock: {}",
            projected.greeting
        );
        assert_eq!(
            ProfileView {
                greeting: expected.greeting.clone(),
                ..projected
            },
            expected
        );
    }

    #[test]
    fn sign_out_keeps_the_profile() {
        let mut model = Model::test_default();
        let _ = save(&mut model, fixture());
        let _ = Intrada.update(Event::SignedOut, &mut model);
        assert_eq!(model.profile, fixture(), "device data, not account data");
    }

    // ── Wire ──

    const PINNED_PROFILE_HEX: &str =
        "03000000000000004a6f6e05000000000000005069616e6f010300000003000000";
    /// The last variant of each enum and the `None` tag, so a reorder at the
    /// tail of either enum, or a new variant appended, moves a pinned byte.
    const PINNED_TAIL_PROFILE_HEX: &str = "000000000000000000000000000000000007000000";

    /// Positional bincode: a new field breaks every stored blob (#1345).
    /// Bump `Store.profileDefaultsKey`, then re-pin.
    #[test]
    fn profile_blob_wire_is_pinned() {
        use crux_core::bridge::{BincodeFfiFormat, FfiFormat};
        let profile = Profile {
            icon_choice: Some(InstrumentIcon::Violin),
            colour: HighlighterColour::Sky,
            ..fixture()
        };
        let mut bytes = Vec::new();
        BincodeFfiFormat::serialize(&mut bytes, &profile).expect("serialize");
        let hex: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
        assert_eq!(
            hex, PINNED_PROFILE_HEX,
            "the profile blob changed shape: bump Store.profileDefaultsKey, then re-pin"
        );
        let back: Profile =
            BincodeFfiFormat::deserialize(&bytes).expect("must decode on the FFI wire (#846)");
        assert_eq!(back, profile);

        let tail = Profile {
            name: String::new(),
            instrument: String::new(),
            icon_choice: None,
            colour: HighlighterColour::Powder,
        };
        let mut bytes = Vec::new();
        BincodeFfiFormat::serialize(&mut bytes, &tail).expect("serialize");
        let hex: String = bytes.iter().map(|b| format!("{b:02x}")).collect();
        assert_eq!(
            hex, PINNED_TAIL_PROFILE_HEX,
            "tail variants moved: bump the key, re-pin"
        );
        let mut bytes = Vec::new();
        BincodeFfiFormat::serialize(&mut bytes, &InstrumentIcon::Other).expect("serialize");
        assert_eq!(
            bytes,
            [12, 0, 0, 0],
            "Other is the thirteenth icon; a variant added before it shifts every stored pick"
        );
    }

    #[test]
    fn profile_events_round_trip_on_the_ffi_wire() {
        assert_round_trips(Event::Profile(ProfileEvent::Save(fixture())));
        assert_round_trips(Event::Profile(ProfileEvent::Loaded(Profile::default())));
        assert_round_trips(AppEffect::SaveProfile(fixture()));
        assert_round_trips(build_profile_view(&fixture(), 9));
    }
}
