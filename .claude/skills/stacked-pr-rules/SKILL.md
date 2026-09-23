---
name: stacked-pr-rules
description: Use this skill whenever you split work across multiple PRs, or create, slice, reorder, or review a stack of PRs. Landing-safety rules for what makes each PR in a stack safe to merge on its own, independently of the PRs above it.
---

# Stacked PRs: landing safety

Use this skill whenever you split work across multiple PRs, or slice, reorder, or review an existing stack.

Every PR in a stack must be safe to land on its own — independently mergeable into `master` and leaving the product coherent even if the PRs above it never land. A reviewer or the merge queue can land the bottom of a stack and stop there, so "the next PR fixes it" is not a plan.

- **No broken intermediate state.** Each PR must compile, pass tests, and not crash at runtime on its own. A PR that calls into code only introduced by a later PR isn't independently mergeable — pull that dependency down into the earlier PR, or keep the two together.
- **No partially-visible feature.** Don't let an early slice reveal a half-built flow that would confuse users or break the system. Keep new user-facing surface dark until the feature is whole: gate it behind a site config or experiment, or leave its entry point unwired.
- **Flip it on last.** Order the stack so plumbing and gated-off code land first, and the single PR that makes the feature reachable — the config flip, the route or nav entry, the menu item — sits at the top. That's the one PR that must not merge until everything under it has.
- **Too coupled to slice is a valid answer.** If no split satisfies the rules above, keep the changes in one PR rather than shipping a broken middle.

## Reviewer navigation

Every PR description in a multi-PR result must include the same complete, linked `## Change set` table near the top. The table must:

- state the overall outcome
- link every PR in the change set and summarize its purpose
- show each PR's dependencies, using `—` for independent roots
- mark the PR whose description is being viewed
- identify the activation PR when one exists

The overall outcome, row order, links, purposes, dependencies, and activation must be identical across descriptions; only the current-PR marker changes. Each description must contain exactly one change-set navigation section. When authorized to update a description, migrate an existing stack section rather than appending a duplicate, and preserve unrelated human-authored content.

Do not link only the immediate parent or child. Keep the table synchronized across every PR when the set is created, reordered, split, replaced, or reduced.

When reviewing, read each PR against `master` rather than against the stack's final state: the question is whether this PR is safe alone, not whether the whole feature is correct. A PR whose tests only pass with a sibling PR checked out has already failed the first rule.
