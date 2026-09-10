---
name: intrada-shipping
description: How a PR or issue ships in intrada: the pre-push gate and self-review order, draft until reviewed, Codecov expectations, the deferred-issue protocol, and the PR and issue body templates. Read before opening or updating any PR or writing an issue.
---

## The pre-push gate

**Every non-trivial PR goes through `/ship`**, which runs the gates and the
self-review together, in this order: local gates through the `test-runner`
agent, then the `reviewer` agent over the local diff, then triage and fix, then
push and open the PR with the review summary posted at creation. Review as a
separate step after the push is how it gets skipped: #1550 put four defects on
main while its reviewer was still thinking.

- **Tier 1 trivia** (typos, dep bumps, single-line config) may skip the review
  but never the gates.
- **Small Tier 2**, one file with no bridge, DB, auth or migration surface, may
  take a lighter single-pass review. Anything on the domain-sensitivity list,
  or spanning files, takes the full agent.

**The reviewer never waits, and the lead posts the comment.** Brief it to
report and yield: no `gh pr comment`, no holding for a PR number, since no PR
exists yet (2026-09-07: one review parked 35 minutes, one cancelled at its 45
minute limit, both on three-file diffs). The lead posts the summary verbatim at
PR creation, saying which agent produced it. While the review runs the lead
writes the PR body, opens the deferred issues and re-reads the diff; it does
not sit in a wait.

**Non-trivial PRs open as drafts.** `gh pr create --draft`, then `gh pr ready`
only once the self-review comment is posted, its blockers are fixed and the
deferred issues exist. CI has no draft filter, so this costs nothing.

## Verifying a change on the simulator

A UI or interaction change is driven on the simulator before it ships, not
described: `just ios-run` launches the app and the runtime tools tap, type and
screenshot it. A snapshot proves a settled frame renders, not that a tap
reveals anything or that a rejected write puts the old value back. Name in
**What I checked** what you drove and what you saw.

`needs-device` is for behaviour that cannot exist on a simulator: camera,
haptics, gestures a synthetic touch cannot reproduce, background audio, Live
Activities. Those PRs carry the label and their **What I checked** names exactly
what a person has to do by hand. Reaching for it because driving the app looked
like effort is the failure this rule exists to stop.

A screen change ships with its before and after image, not prose describing
one. After pushing the branch, `just pr-visuals` reads the references it
changed and prints the before/after markdown to paste under **What it looks
like** (#1631); the images are raw.githubusercontent.com URLs pinned to the
pushed commit, so run it after the push or they point at a commit GitHub has
never seen.

## Codecov (Tier 2+)

After CI, compare the patch-coverage comment with the **Coverage** line in the
PR description. Unexpected gaps get tests or a PR comment before the PR is
marked ready.

## Deferred issues

Every deferred or out-of-scope item becomes a tracked issue, labelled
(`horizon:now|next|later` plus a kind: `ux`, `architecture`, `bug`,
`accessibility`, `ios`, `pillar:*`), opened before the self-review comment is
posted. PR descriptions are not tracking. The comment ends with
`Deferred items tracked: #N, #M` or `none, all flagged items addressed inline`.

## PR bodies and issues

Both are read cold, months later, by someone deciding whether to merge and
working out what changed, or deciding what to build from the body alone. The
templates are `.github/pull_request_template.md` and
`.github/ISSUE_TEMPLATE/issue.md`; the headings there are the headings, not a
suggestion.

1. **What this fixes**: the situation the affected person would notice. For a
   screen change that is the musician; for tooling or docs it is Jon or an
   agent, and the body says what they hit rather than that no musician is
   affected. No paths, symbols or code; a `just` recipe name once, when the
   recipe is the outcome.
2. **Where this could bite**: residual risk in what ships, present tense, one
   paragraph per risk, each ending in its tracking issue or "deliberate, not
   tracked". A risk an earlier PR of the same feature stated gets its issue
   number, not a restatement. Never the branch's history. Name the fault class,
   not the fumble. Never spell out an exploitable gap in auth, tokens or user
   data on a public repo; say one exists and route the detail to Jon.
3. **What it looks like**: screen changes only, the `just pr-visuals` output.
   Deleted on a PR that touches no screen.
4. **What I checked**: evidence, not reassurance. "Gates green" is one line
   with counts; the check that could have failed earns the space. The
   reviewer's findings, the defects fixed on the branch and why a check was
   worth running belong in the self-review comment, not here.
5. **What changed where**: one line per file. Identifiers welcome.

A Tier 1 or Tier 2 body runs under 400 words before the checklist. Tier 3 and
domain-sensitive work may run longer, and every paragraph past that is a
distinct shipped risk or a check that could have failed. The three longest
bodies of 2026-09 (#1612, #1628, #1601) each carried over 100 words of branch
history in **What I checked**, which is the failure this rule exists to stop.
Checklist lines that do not apply are deleted, not annotated.

Issues: what you would notice, why it matters, what to do, then where it lives.
Measurements, logs and reproduction steps go last even when they are the reason
the issue exists.

Any term not in the glossary (`docs/reference.md`) is said plainly or added to
it. A phase letter, decision number or internal name ("Phase R", "T22", "the
lane") carries the document it resolves in, the first time it appears in a
body. **Tier** means ceremony level; the test gates are "the fast tier" and
"the full tier".

No tick marks, symbols or emoji in either, with one exemption: the attribution
footer the harness requires a session to append.
