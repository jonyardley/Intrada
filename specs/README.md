# specs/ what is live and what is not

The 2026-07 practice-coach pivot was reversed on 2026-08-13 (#1344): the coach
was removed and the session builder restored. Most specs here are therefore
records of shipped behaviour rather than current plans, and carry a banner
saying so. **This index is the fast answer to "can I implement from this
document?"** Where a spec's own banner and this table disagree, this table wins,
because a spec's header is written once and this table is reviewed.

Every top-level `.md` in this folder appears in exactly one section below. A
spec that does not appear here has not been classified, which is a gap to fix
rather than a licence to implement. Files inside a spec's own subfolder
(`<spec>/design/`, and `reflection-loop/spec.md`) travel with their parent and
are not listed separately.

Companion documents outside this folder:
[`docs/roadmap.md`](../docs/roadmap.md) (direction and phase order) and
`just status` (what is in flight, read from GitHub).

## Live, the current design

Accurate about how the app works or is being built now.

| Spec | Scope |
|---|---|
| [`session-builder-revert.md`](session-builder-revert.md) | **The 2026-08 revert.** Restores the session builder and removes the coach machinery (#1344). The decision that set the current product shape |
| [`native-ios.md`](native-ios.md) | The SwiftUI shell on the Crux core, the only shell. Its offline-first decisions are now enforced through `.claude/rules/offline-first.md`, which is where the invariants live; the paid-sync framing survives only here |
| [`ios-testflight-cicd.md`](ios-testflight-cicd.md) | Signing, match, the release lane (`.github/workflows/release-testflight.yml`) |
| [`mcp-server.md`](mcp-server.md) | The API's MCP surface. `crates/intrada-api/src/mcp/` cites this spec and self-identifies as its Phase 3 |
| [`key-modality.md`](key-modality.md) | Tonic plus major/minor instead of a free-text key (`Modality` in `domain/item.rs`) |
| [`library-sort.md`](library-sort.md) | Sorting the library list (`LibrarySort` in `domain/types.rs`) |
| [`exercise-relations.md`](exercise-relations.md) | The single "Used in" list replacing the related-to breadcrumb (`UsedInCard.swift`) |
| [`piece-related-exercises.md`](piece-related-exercises.md) | Writing your own exercise as the first action when adding exercises to a piece (`LibraryDetailScreen.swift`) |
| [`practice-instruments.md`](practice-instruments.md) | The Focus Player's timer, rep counter and honest click (`click_sounding` in `domain/session.rs`) |
| [`up-next-card.md`](up-next-card.md) | The "Up next" suggestion on the Practice tab (`compute_up_next` in `suggestion.rs`) |
| [`getting-cold-signal.md`](getting-cold-signal.md) | Weighting the "not practised in a while" signal by how well learned a piece is (`staleness.rs`) |

## Planned, designed and not finished

| Spec | Scope |
|---|---|
| [`piece-from-photo.md`](piece-from-photo.md) | Adding a piece from a photograph of the page. Phases A, B and C shipped (#1443, #1455, #1476); Phase D unstarted (#1355, #1387) |
| [`one-pass-create.md`](one-pass-create.md) | Adding a piece with its chord chart and exercises in one save. Core landed 2026-09-07 (#1390, PR #1591) and `ItemEvent::AddPieceInFull` has no caller in `ios/Intrada` yet: this is the screens half of a two-PR split, still owed |
| [`picker-core-sort.md`](picker-core-sort.md) | The linked-item picker sheet's sort and search calling into the core instead of a Swift copy. Core landed on main (`sort_and_filter_candidates` in `app.rs`, `sort_and_filter_picker_candidates` in `intrada-ffi`, #1653, #1662); the screens half wiring `LinkedItemPickerSheet` to it and deleting the Swift copies is #1664, open |
| [`account-settings-and-deletion.md`](account-settings-and-deletion.md) | Settings and GDPR account deletion. `delete_account` and `AccountPreferences` exist in core and the API, but no native Settings screen does, and the spec's entry points ("mobile app via Tauri", "web header") are both dead shells. The premise needs rewriting before the UI is built |

## Shipped record, verify against the code before extending

Builder-era specs whose surfaces returned with the restored session builder.
Treat them as history of how the behaviour came to be, not as an implementation
contract.

| Spec | Scope |
|---|---|
| [`chart-to-scaffold.md`](chart-to-scaffold.md) | Chord-chart parsing and scaffold derivation (`domain/chart.rs`). Phase C shipped in PR #1111. The twelve-key ladder originally scoped inside it is still open as #1107, and that issue records that the steps mechanism it needs has since shipped, so the old #1083 blocker is gone |
| [`exercise-variants.md`](exercise-variants.md) | Exercise steps and the per-step ladder (`domain/variant.rs`) |
| [`session-block-grouping.md`](session-block-grouping.md) | Grouping and reordering blocks in the builder (`group_id`, `UngroupBlock`). Shipped via #1022, which the spec itself does not cite |
| [`piece-linked-exercises.md`](piece-linked-exercises.md) · [`piece-linked-exercises-design-brief.md`](piece-linked-exercises-design-brief.md) | The original piece-linked exercises (#1015). Its "Linked exercises" copy has since been renamed twice; read `exercise-relations.md` and `piece-related-exercises.md` for current behaviour |
| [`related-exercises-redesign.md`](related-exercises-redesign.md) | Related-exercises stocktake. Its "already shipped" inventory is stale: the exercise detail's "Related to" breadcrumb it lists was replaced by the "Used in" list. The Focus Player still shows one (`FocusPlayerScreen.swift`), which `exercise-relations.md` keeps deliberately |
| [`reflection-loop/`](reflection-loop/) | The reflection loop's core model |
| [`track-exercises-per-piece/`](track-exercises-per-piece/) | Per-piece exercise tracking |
| [`native-player.md`](native-player.md) · [`native-ios-player.md`](native-ios-player.md) | The Focus Player, as two sequential phases (#932 spine, #948 persistence) |
| [`priority-items.md`](priority-items.md) | Priority items replacing Goals in the Plan layer. Landed across #739 and #769, with #981 as its slice 2 |

## Historical, do not implement from these

Kept as a design record. Every one of these targets a shell or a crate that no
longer exists, or a direction that was reversed, so the code they describe
cannot be found and should not be recreated from them.

| Spec | Why |
|---|---|
| [`intrada-practice-coach-design.md`](intrada-practice-coach-design.md) | The retired coach design, built through Phase 2b and removed 2026-08-13 (#1344) |
| [`intrada-coach-engine.md`](intrada-coach-engine.md) | The retired coach engine, same removal. Recover code from commit 071b85b. None of `CoachState`, `MasteryStore` or `JudgementStore` exist |
| [`design-system.md`](design-system.md) | **The Leptos web shell's dark glassmorphism system**, per its own first line. `crates/intrada-web` was deleted in #1133. The live system is `design/intrada-design-system.dc.html` with `Theme.swift` canonical, both outside `specs/` |
| [`design-refresh-2026.md`](design-refresh-2026.md) | A refresh of that same web theme, written before native iOS existed. None of `AccentRow`, `StatCard` or `DifficultyDots` exist anywhere in the tree |
| [`onboarding-welcome.md`](onboarding-welcome.md) | A first-run carousel for the deleted web shell; the surface did not return |
| [`background-audio-plugin.md`](background-audio-plugin.md) | Written as a Tauri plugin under `crates/intrada-mobile`, which no longer exists. The reference `BackgroundAudioPlugin.swift` was deleted in PR #1752 (#1745); recover it from that PR's diff on GitHub, since the branch commit does not survive the squash merge. Useful as reference for a native port, not implementable as written |
| [`live-activity-plugin.md`](live-activity-plugin.md) | Same: an ActivityKit design as a Tauri plugin in a deleted crate. Its reference Swift was deleted in the same PR; same recovery route. A native lock-screen spec does not exist yet |

[`_archive/`](_archive/) holds the numbered SpecKit-era folders and retired
single-file specs (`seo-prerender.md`), and is excluded from the knowledge
graph. Do not run `/speckit-*` commands.
