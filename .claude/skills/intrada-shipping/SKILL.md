---
name: intrada-shipping
description: Rules for shipping PRs and issues in intrada. Read this when writing PR bodies, issue descriptions, running pre-push gates, checking Codecov, and opening deferred-item issues. Covers the gate funnel (checks and self-review), coverage expectations, and the PR/issue body template that serves both merge decisions and change understanding.
---

## Pre-push gate and review funnel

**Open/update any non-trivial PR through a single pre-push gate that runs the checks and the self-review together** — do not `gh pr create`/`git push` feature work directly with review as a separate, skippable step. Whatever funnel the current harness provides (Claude Code: the `ship` skill; OMP or others: an equivalent task/command chaining checks and review), route through it so review cannot be skipped in a fast build-push cadence (which is exactly how it gets skipped when left to "remember to review").

Use a code-review agent for the self-review, apply blockers and important
findings inline, and defer the rest as tracked issues per the Deferred issues
section below.

- **Tier 1 trivia** (typos, dep bumps, single-line config) may skip the review step but still run the gates.
- **Small Tier 2** — one file, no bridge / DB / auth / migration surface — may use a lighter single-pass review in place of a full agent. Anything on the domain-sensitivity list, or spanning files, takes the full review agent.

**Run the review before the push, not after.** The gate is: local gates, then the reviewer over the local diff, then triage and fix, then push and open the PR with the summary posted at creation. A PR that exists is a PR that has been reviewed. Reviewing after opening is what put four defects on main in #1550, where the PR sat open, green and mergeable for the fourteen minutes its reviewer was still thinking. The draft rule below is the safety net for when this ordering slips, not a substitute for it.

**The lead posts the review comment, and the reviewer never waits.** Brief the
agent to report its findings and yield straight away: it must not run
`gh pr comment` itself, and it must never be told to hold for a PR number. The
lead then posts the summary verbatim at PR creation, saying which agent produced
it and citing its `agent://<id>` artefact, so the comment still evidences a real
review rather than the lead's word for one. Briefing the agent to post its own
comment while the review runs before the push is a guaranteed deadlock, since no
PR exists yet to comment on: it happened twice on 2026-09-07, parking one
reviewer for 35 minutes and letting a second burn its 45 minute runtime limit and
get cancelled, on a three file diff each time. The lead waiting on a reviewer
that is waiting on the lead produces no work at all.

**Non-trivial PRs open as drafts.** `gh pr create --draft`, then `gh pr ready <n>` only once the self-review comment is posted, its blockers are fixed inline and the deferred issues exist. An open PR reads as ready to merge to the person merging it, and the difference between "reviewed and green" and "green while a reviewer is still running" lives only in the prose nobody should have to read carefully. #1550 merged during the fourteen minutes its reviewer was still thinking, taking a defect to main that the review then found. CI has no draft filter, so this costs nothing in signal.

## Work a simulator cannot verify

Anything whose behaviour lives outside the simulator (camera, haptics, gestures, background audio, Live Activities, anything hardware-bound) carries the `needs-device` label, and its **What I checked** section names exactly what is unverified and what a person has to do by hand. Green CI on those PRs proves nothing else broke; it says nothing about the change itself. The label is what makes that true at the moment of merging, rather than in the third section of a body nobody rereads.

## Codecov gate (Tier 2+)

Check Codecov after CI finishes. Compare the patch-coverage comment against the **Coverage** line in the PR description. If there are unexpected gaps, push tests or explain in a PR comment before calling the PR ready.

## Deferred issues protocol

Open a tracked issue for every deferred / out-of-scope item, labelled (`horizon:now|next|later`, kind: `ux` / `architecture` / `bug` / `accessibility` / `ios` / `pillar:*`). PR descriptions are not tracking — they get auto-collapsed after merge. Open the issues *before* posting the self-review comment: "will open a follow-up if it bites" is not acceptable. Every self-review comment must end with `Deferred items tracked: #N, #M` or `none — all flagged items addressed inline`. Silent omission is the failure mode.

## Writing PR bodies and issues

Both are read cold, months later, by someone deciding **whether to merge** and working out **what changed**, in the same read. Serve both, in this order.

### PR body structure

1. **What this fixes** — the situation a musician would notice. No file paths, no symbol names and no code in this block.
2. **Where this could bite** — residual risk in the merged code, and what is deliberately not covered. Present tense, about what ships: never the history of the branch, and never a wrong turn already corrected. When a review found something, name the fault class (which line is load-bearing), not the fumble. **Never spell out an exploitable gap** in auth, tokens or user data on a public repo: say a gap exists and route the detail to Jon.
3. **What I checked** — evidence, not reassurance. "Gates green" is one line, because it is true of every PR worth showing; what earns space is the check that could have failed.
4. **What changed where** — one line per file. Identifiers welcome.

### Issue body structure

What a person would notice, then why it matters, then what to do about it, then the technical reproduction last.

### Glossary and plain language

Any term not in the glossary ([`docs/reference.md`](../docs/reference.md)) is said plainly or added to it. That binds invented shorthand ("seam", "applier") as well as unglossed house terms. No tick marks, symbols or emoji in either.
