---
description: Run the pre-push gates and the self-review before opening or updating a PR. The mechanics live in the intrada-shipping skill; this fixes the order.
---

Prepare the current branch to ship. Read `.claude/skills/intrada-shipping/SKILL.md` first: it is the source for every step below.

1. **Gates**, through the `test-runner` agent: `just check`, plus `just ios-fmt-check` and `just ios-test-full` when files under `ios/` changed. Stop at the first failure and report its actual output.
2. **Self-review**, before the push: the `reviewer` agent over the local diff. Fix blockers inline. Tier 1 trivia may skip this step but never the gates.
3. **Deferred items**: open an issue for each before posting the review comment.
4. **Open the PR** as a draft with the body template from the skill, post the review summary citing the agent, then mark it ready.
5. **Watch CI** to a conclusion in the same turn, and read the PR's mergeability, not just the job list.

$ARGUMENTS
