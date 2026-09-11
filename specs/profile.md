# Profile: name, instrument, icon and highlighter colour on the device

> Tier 3 (a new bridge shape and a new persisted singleton). Rides as the
> first commit of the core PR for #1691, part of #1689. Native iOS only.

## Problem

The app has no idea who is using it. It cannot remember a musician's name,
what they play, which icon stands for them or which highlighter colour they
chose. The profile screen (#1692), the highlighter colour across the app
(#1677), the instrument icons (#1693) and the greeting on the Practice screen
(#1694) all read from one thing that does not exist yet.

It has to work with no account and no network. On the free tier the device is
the only copy.

## Approach: the profile is core state, saved as a small singleton

The core owns the profile, its validation, the icon suggestion and the
greeting text. The shell writes one blob to UserDefaults when told to, reads
it back at launch, and renders the view. No profile logic lives in Swift.

### Data model (core)

New module `domain/profile.rs`:

```rust
pub struct Profile {
    pub name: String,                        // "" until typed
    pub instrument: String,                  // "" until typed
    pub icon_choice: Option<InstrumentIcon>, // the musician's own pick
    pub colour: HighlighterColour,           // Butter by default
}

pub enum InstrumentIcon {
    Piano, AcousticGuitar, ElectricGuitar, Violin, Cello, Voice, Flute,
    Clarinet, Saxophone, Trumpet, Drums, Harp,
    Other, // the plain fallback
}

pub enum HighlighterColour {
    Mint, Coral, Lavender, Sky, Sage, Butter, Peach, Powder,
}
```

The twelve icons are the set #1690 is drawing; `Other` is the plain fallback
for anything unmatched. The eight colours are the marker pastels from #1677.
Names, not hex values: the shell maps a name to its swatch in `Theme.swift`,
so a palette tweak never touches the core or the stored blob.

### Icon suggestion

`suggest_icon(instrument: &str) -> InstrumentIcon` lowercases and trims the
text, then walks a keyword table in order and returns the first icon whose
keyword the text contains. Substring match handles plurals ("drums"),
qualifiers ("grand piano", "bass guitar") and extra spaces without a
tokeniser. Order matters where keywords overlap: "bass guitar" must reach
`ElectricGuitar` before "bass" reaches `Cello` (double bass), so the guitar
row sits above the cello row. Nothing matched, or an empty string, gives
`Other`.

The icon actually shown is `icon_choice.unwrap_or(suggest_icon(instrument))`:
the musician's own pick wins over the suggestion.

### Greeting

`greeting(name: &str) -> String` returns "Hello, Jon" when there is a name and
"Hello" when there is not. The wording is deliberately plain until #1690
settles the header; changing it later is one string in one function.

### Validation

In `validation.rs`: `MAX_PROFILE_NAME` and `MAX_INSTRUMENT`, both 100
characters. `normalize_profile` trims both fields. `validate_profile` rejects
either field over its cap with a `LibraryError::Validation` naming the field.
An over-cap save leaves the model on the last accepted profile and sets
`last_error` with `FormErrorTarget::Profile { field }`, the same path a long
title takes. Rejecting rather than silently truncating keeps validation
consistent across the app and loses nothing: the previous value stays.

### Events and view

```rust
pub enum ProfileEvent {
    Save(Profile),   // the screen's Save button
    Loaded(Profile), // the shell replaying the stored blob at launch
}
```

`Event::Profile(ProfileEvent)` delegates to `handle_profile_event`, like the
other domains.

- `Save` normalises, validates, sets `model.profile`, emits
  `AppEffect::SaveProfile(Profile)` and renders.
- `Loaded` sets `model.profile` and renders. It skips validation and does not
  re-save: the blob was accepted when it was written, and a later cap change
  must never make a stored profile vanish on launch.

`ViewModel.profile: ProfileView` carries everything the screens need, so the
screens PR does not change the core:

```rust
pub struct ProfileView {
    pub name: String,
    pub instrument: String,
    pub suggested_icon: InstrumentIcon, // what the core would show unpicked
    pub icon: InstrumentIcon,           // what is actually shown
    pub colour: HighlighterColour,
    pub greeting: String,
}
```

### Persistence: the library sort's route, not `crux_kv`

The offline-first rules name `crux_kv` for small singletons, but nothing wires
it today; the library sort and the crash-recovery blob persist through the
existing fire-and-forget `AppEffect`. The profile takes the same route: no new
capability, no new dependency, one more arm in a switch the shell already has.
If a third singleton arrives, that is the moment to stand `crux_kv` up and
move all three.

- **Write:** `Save` emits `AppEffect::SaveProfile(Profile)`; `Store.swift`
  bincode-serialises it into UserDefaults under `Store.profileDefaultsKey`.
- **Read:** at launch, next to `restorePersistedSort()`, the shell decodes the
  blob and sends `Event::Profile(ProfileEvent::Loaded(profile))`. A missing or
  undecodable blob is a no-op and the defaults stand.

**The blob is positional bincode, so any field added later breaks every saved
copy (#1345).** The key is versioned from the first release:
`intrada.profile.v1`. A core test pins the wire bytes of a fixture profile as
hex; it fails the moment the shape changes. Adding a field is then: change the
Rust type, bump the key to `v2` (a `v1` blob is simply not found and the
defaults stand, which for a profile is an acceptable loss the first time and a
reason to add a migration read the second), re-pin the hex, regenerate the
bindings.

Sign-out leaves the profile alone. It is device data, like the UTC offset,
not account data: the app works with no account at all, and the name was
typed, never taken from the sign-in.

## Key decisions

1. **Core owns the profile, the suggestion and the greeting.** Dumb-pipe
   rule; a future shell reimplements nothing.
2. **Names for colours and icons, not hex or asset names.** The stored blob
   and the bridge stay stable when the look changes.
3. **The pick wins over the suggestion, and the view carries both.** The
   edit screen can show "suggested" beside the musician's own choice.
4. **Reject over the cap, never truncate.** Consistent with titles; nothing
   is lost.
5. **`Loaded` is its own event.** Restore never re-validates or re-saves.
6. **The existing `AppEffect` route, key versioned as `v1` from day one.**
   No `crux_kv` until a third singleton justifies it.
7. **Sign-out keeps the profile.** Device data, not user data.

## Deliberately not doing

- Syncing the profile to the server. `user_preferences` and
  `AccountPreferences` stay as they are; the server side is #1599's concern.
- Taking the name from the sign-in account (decided 2026-09-11 on #1689).
- A colour per piece or plan (#1677: one colour for the whole app).
- Free-text icon search or fuzzy matching. Substring keywords cover what a
  musician types; an unmatched instrument gets the fallback and a manual pick.
- Screens, the Practice header, `Theme.swift` and sample data: the screens PR.

## Testing

- **Core, test-first:** a table test of `suggest_icon` from inputs a musician
  would type ("Piano", "grand piano", "vocals", "Double bass", "bass guitar",
  "Drums", "  flute  ", "", "theremin"); `greeting` with and without a name;
  normalisation trims, validation rejects at cap plus one and accepts at cap;
  `Save` updates the model and emits `SaveProfile`; an over-cap `Save` keeps
  the previous profile, sets the error target and emits no save; `Loaded`
  sets the model and emits no `SaveProfile`; the view shows the pick when
  present and the suggestion when not; sign-out keeps the profile; the wire
  hex of a fixture profile is pinned; both events round-trip on the bincode
  wire (#846).
- **iOS, this PR:** the save effect writes the blob under the versioned key
  and it decodes through `LiveBridge`; restore replays `Loaded` with the
  stored profile; restore is a no-op when nothing is stored.
- **iOS, screens PR:** the profile screen, the swatches and the greeting.
- Bindings regenerated with `just ios-gen`, never hand-edited.
