## What this fixes

<!-- The situation the affected person would notice. For a screen change that
     is the musician; for tooling or docs it is Jon or an agent, so say what
     they hit rather than that no musician is affected. No file paths, no
     symbol names and no code in this block; a `just` recipe name may appear
     once, when the recipe is the outcome. A phase letter, decision number or
     internal name carries the document that resolves it, or is said plainly
     instead. -->

## Where this could bite

<!-- Residual risk in the merged code, and what is deliberately not covered.
     Present tense, about what ships: never the history of the branch, and never
     a wrong turn already corrected. One paragraph per risk, each ending in the
     issue that tracks it or the words "deliberate, not tracked". A risk an
     earlier PR of the same feature already stated gets its issue number, not a
     restatement. Never spell out an exploitable gap in auth, tokens or user
     data on a public repo: say a gap exists and route the detail to Jon. -->

## What it looks like

<!-- Screen changes only. After pushing the branch, run `just pr-visuals` and
     paste its output here: a before and after image for every snapshot
     reference this branch changed, pinned to the pushed commit so the
     pictures still resolve after the branch is gone. Run it before the push
     and the after-images point at a commit GitHub has never seen. Delete this
     section on a PR that touches no screen. -->

## What I checked

<!-- Evidence, not reassurance. "Gates green" is one line with the counts,
     because it is true of every PR worth showing. What earns space is the
     check that could have failed and what it showed. Not here: the reviewer's
     findings, the defects fixed on the branch, or why a check was worth
     running. Those live in the self-review comment. -->

Coverage: <!-- Tier 2+: the expected patch-coverage gaps and why. What the new tests cover belongs above. Tier 1: n/a. -->

## What changed where

<!-- One line per file. Identifiers welcome here. -->

## Checklist

<!-- Delete a line that does not apply rather than annotating it. A line left
     unticked is a line still owed. -->

- [ ] Roadmap item or issue: #___ (or explicitly agreed with Jon)
- [ ] `just check` passes (fmt + clippy + tests, mirrors CI's flags)
- [ ] `ios/` changes: `just ios-fmt-check` and `just ios-test-full` pass (the merge gate; `just ios-test` is the fast inner-loop tier); snapshots re-recorded and `just ios-snapshots-optimize` run if UI changed
- [ ] New UI uses `Intrada*` tokens (colour, spacing, radius, type), no raw literals
- [ ] Persistence or new-entity changes: offline-first PR checklist in `.claude/rules/offline-first.md` applied (`updated_at` / `deleted_at`, client-minted ulid, `local_first` branches tested both ways)
- [ ] CLAUDE.md updated (if architecture, components or patterns changed)
- [ ] Roadmap updated (if a feature is now complete or scope changed)
- [ ] Deferred items opened as tracked issues and listed in the self-review comment
