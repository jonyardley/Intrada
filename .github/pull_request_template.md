## What this fixes

<!-- The situation a musician would notice. No file paths, no symbol names and
     no code in this block. -->

## Where this could bite

<!-- Residual risk in the merged code, and what is deliberately not covered.
     Present tense, about what ships: never the history of the branch, and never
     a wrong turn already corrected. Never spell out an exploitable gap in auth,
     tokens or user data on a public repo: say a gap exists and route the detail
     to Jon. -->

## What it looks like

<!-- Screen changes only. Run `just pr-visuals` and paste its output here: a
     before and after image for every snapshot reference this branch changed,
     pinned to a commit so the pictures still resolve after the branch is
     gone. Delete this section on a PR that touches no screen. -->

## What I checked

<!-- Evidence, not reassurance. "Gates green" is one line, because it is true of
     every PR worth showing. What earns space is the check that could have
     failed. -->

Coverage: <!-- Tier 2+: what the new tests cover, or the expected patch-coverage gaps and why. Tier 1: n/a. -->

## What changed where

<!-- One line per file. Identifiers welcome here. -->

## Checklist

- [ ] Roadmap item or issue: #___ (or explicitly agreed with Jon)
- [ ] `just check` passes (fmt + clippy + tests, mirrors CI's flags)
- [ ] `ios/` changes: `just ios-fmt-check` and `just ios-test-full` pass (the merge gate; `just ios-test` is the fast inner-loop tier); snapshots re-recorded and `just ios-snapshots-optimize` run if UI changed
- [ ] New UI uses `Intrada*` tokens (colour, spacing, radius, type), no raw literals
- [ ] Persistence or new-entity changes: offline-first PR checklist in `.claude/rules/offline-first.md` applied (`updated_at` / `deleted_at`, client-minted ulid, `local_first` branches tested both ways)
- [ ] CLAUDE.md updated (if architecture, components or patterns changed)
- [ ] Roadmap updated (if a feature is now complete or scope changed)
- [ ] Deferred items opened as tracked issues and listed in the self-review comment
