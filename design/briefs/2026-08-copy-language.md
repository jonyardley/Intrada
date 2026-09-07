# Voice — how Intrada speaks

*2026-08-07, v2 — supersedes the earlier glossary-only version of this file.
Decided with Jon: voice splits by surface. The first copy pass fixed
vocabulary but kept the stance — the app kept narrating its own data model in
nicer words. The fix is not better sentences; it is fewer.*

## The three surface classes

### 1. In-session — the silent tool
*Drill loop, run-throughs, feel moments, off-piste, unmonitored play —
anywhere hands belong on the keys.*

- **Prose budget: ≤ 8 words beyond labels and buttons.** Reading is friction;
  the measurement budget already believes this about taps.
- No captions explaining mechanics. What is and isn't being recorded is
  carried by the interface: the altitude chip, the presence or absence of
  instrumentation (B2's note is right: "absence of instrumentation is itself
  the consent signal"). Genuinely needed detail goes behind an ⓘ.
- Buttons and chips are the vocabulary: "Held / Broke down", "Got it / Not
  yet", "Fought it / Getting there / It sang". These are the register — keep
  making words like these.

### 2. Set-up and composition — the plain peer
*The steer sheet, resolution questions, the composed-session view, altitude
choice.*

- **One short sentence per card, maximum.** Declarative, concrete, no
  metaphors, no stacked reassurances.
- Explain a thing once, at the decision point, then never again. Repeat
  visits get labels only (A2r already does this: "all known").
- Questions are fine when they are the actual decision: "What counts as a
  clean pass?" stays.

### 3. Reflective and narrative — warmth allowed
*Session summary, the reflection moment, the morning proposal (C3), the
weekly thread.*

- The user's own words do the emotional work, quoted in serif. The app's
  words stay brief and concrete around them.
- This is the only class where the app may have a personality, and it is
  the LLM-narration home the spec already defines. Warmth here, nowhere else.

## Universal rules

- **Never explain the data model inline.** If a screen seems to need a
  paragraph about what is or isn't recorded, the design is wrong, not the
  copy. (The deleted three-bullet consent list on A5 is the type specimen.)
- **No philosophy headlines.** "Some things can't be counted" — the player
  already knows; it's their craft. Cut, don't soften.
- **Buttons name the action, not the mechanism.** "Keep it as a drill",
  never "write the gate".
- **Engine vocabulary never appears on screen** — gate, verdict, evidence,
  mastery, prerequisite, node, steer, prescribed, judgement track, countable,
  cold test (as a noun). Screen translations: target / the buttons themselves
  / history / progress / "you added this" / "today's plan" / "by ear" /
  "from cold" (as lived experience). Precedent: core says `variant`, screen
  says **Steps**.
- "Counts" only in plain English ("it all still counts"), never in the model
  sense ("counts at full weight").
- British English, musician's words. Frame annotations under the phones are
  design documentation and may use spec vocabulary freely.

## Worked examples — the frames, redone under this voice

| Frame | Class | Copy becomes |
|---|---|---|
| A5 journal exit | set-up | Item name · kind **Journal** · "Time and notes, kept with the piece." · button **Add**. The three-bullet consent list is deleted (ⓘ if anywhere). No headline. |
| A4 new-drill form | set-up | Keep "What counts as a clean pass?" and the read-back chips ("Done when · 3 clean", "Helps with · optional"). Delete the low-band/cold-test footnote — the library states it, the form doesn't lecture. |
| A6 composed session | set-up | "Built by you". Delete "Every block gates and counts — same as a prescribed day." — the identical scaffold to a planned day *shows* it. Shape advice stays one line: "Warm-up first, the tune at the end — that's the shape I'd suggest." |
| A7 block boundary | in-session | Dots + "2 of 3". Delete "gate holds till it's cold-tested" and "Full weight — same as a prescribed block". "Adds to · Left hand" may stay — 4 words. |
| B0 altitude choice | set-up | Card titles + one line each: "A proper run — section by section, one tap each." / "Time logged. Say something if you find something." / "Minutes only. No questions." |
| B1 gated run | in-session | "The bridge, from memory" · "From cold" · "Did it hold?" · **Held / Broke down**. Delete "first attempt of the day counts". |
| B2x keep-as-drill | set-up | "Keep this as a drill?" · "You'll set the target; it's tracked like your other drills." · **Keep it / Just the note**. |
| B3 unmonitored | in-session | "23 min" · "Just you and the piano." Nothing else — the second sentence ("Minutes are kept; nothing else is") moves to the B0 card where the choice is made. |
| C1 feel moment | in-session | "How did it feel?" · the three chips · **Skip**. No caption. The absent score UI says there is no score. |
| C3 morning proposal | reflective | As mocked — quote back, one concrete offer, "Add it to today / Not today". Row badge "your steer" → "you added this". |

## On landing

When a journey wins and reaches the repo: this graduates to
`docs/design-principles.md`'s decisions log (T13 candidate — voice splits by
surface; the engine's vocabulary never appears on screen; in-session prose is
budgeted like taps), and the design system gains a Voice section beside the
tokens so every future frame is written against it.
